/// URL Parser Utility
/// 
/// This utility handles URL validation, platform detection,
/// and URL normalization for social media links.
/// 
/// ASSUMPTION: We only support public content URLs.
/// Private content or login-protected posts cannot be accessed.

import '../core/constants.dart';

/// Result of URL parsing
class ParsedUrl {
  final SocialPlatform platform;
  final String normalizedUrl;
  final String? postId;
  final UrlType urlType;
  final bool isValid;
  final String? errorMessage;

  const ParsedUrl({
    required this.platform,
    required this.normalizedUrl,
    this.postId,
    this.urlType = UrlType.unknown,
    this.isValid = true,
    this.errorMessage,
  });

  factory ParsedUrl.invalid(String message) {
    return ParsedUrl(
      platform: SocialPlatform.unknown,
      normalizedUrl: '',
      isValid: false,
      errorMessage: message,
    );
  }
}

/// Types of URLs we can handle
enum UrlType {
  post,
  reel,
  story,
  igtv,
  profile,
  video,
  photo,
  tweet,
  unknown,
}

/// Main URL parser class
class UrlParser {
  // Instagram URL patterns
  static final RegExp _instagramPostRegex = RegExp(
    r'(https?://)?(www\.)?instagram\.com/(p|reel|reels)/([A-Za-z0-9_-]+)',
    caseSensitive: false,
  );
  
  static final RegExp _instagramStoryRegex = RegExp(
    r'(https?://)?(www\.)?instagram\.com/stories/([A-Za-z0-9_\.]+)/(\d+)',
    caseSensitive: false,
  );
  
  static final RegExp _instagramProfileRegex = RegExp(
    r'(https?://)?(www\.)?instagram\.com/([A-Za-z0-9_\.]+)/?$',
    caseSensitive: false,
  );

  // Facebook URL patterns
  static final RegExp _facebookVideoRegex = RegExp(
    r'(https?://)?(www\.|m\.|web\.)?facebook\.com/(watch/?\?v=|.*?/videos/|reel/)(\d+)',
    caseSensitive: false,
  );
  
  static final RegExp _facebookPostRegex = RegExp(
    r'(https?://)?(www\.|m\.)?facebook\.com/.+?/(posts|photos|photo)/([A-Za-z0-9_.-]+)',
    caseSensitive: false,
  );
  
  static final RegExp _facebookStoryRegex = RegExp(
    r'(https?://)?(www\.|m\.)?facebook\.com/stories/(\d+)',
    caseSensitive: false,
  );
  
  static final RegExp _fbWatchRegex = RegExp(
    r'(https?://)?fb\.watch/([A-Za-z0-9_-]+)',
    caseSensitive: false,
  );

  // X (Twitter) URL patterns
  static final RegExp _twitterStatusRegex = RegExp(
    r'(https?://)?(www\.)?(twitter\.com|x\.com)/([A-Za-z0-9_]+)/status/(\d+)',
    caseSensitive: false,
  );
  
  static final RegExp _twitterVideoRegex = RegExp(
    r'(https?://)?(www\.)?(twitter\.com|x\.com)/i/status/(\d+)',
    caseSensitive: false,
  );

  /// Parse a URL and detect the platform
  static ParsedUrl parse(String input) {
    // Clean and normalize input
    final url = _cleanUrl(input);
    
    if (url.isEmpty) {
      return ParsedUrl.invalid('Please enter a valid URL');
    }

    // Try to detect platform
    if (_isInstagramUrl(url)) {
      return _parseInstagramUrl(url);
    } else if (_isFacebookUrl(url)) {
      return _parseFacebookUrl(url);
    } else if (_isTwitterUrl(url)) {
      return _parseTwitterUrl(url);
    }

    return ParsedUrl.invalid(
      'Unsupported platform. Please use Instagram, Facebook, or X (Twitter) URLs.',
    );
  }

  /// Clean and normalize URL input
  static String _cleanUrl(String input) {
    var url = input.trim();
    
    // Remove common leading/trailing characters
    url = url.replaceAll(RegExp(r'^["' "'" r'\s]+|["' "'" r'\s]+$'), '');
    
    // Ensure https prefix
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    // Remove tracking parameters for privacy
    url = _removeTrackingParams(url);
    
    return url;
  }

  /// Remove common tracking parameters
  static String _removeTrackingParams(String url) {
    try {
      final uri = Uri.parse(url);
      final cleanParams = Map<String, dynamic>.from(uri.queryParameters);
      
      // Remove common tracking parameters
      const trackingParams = [
        'utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term',
        'fbclid', 'igshid', 'ref', 's', 't',
      ];
      
      for (final param in trackingParams) {
        cleanParams.remove(param);
      }
      
      if (cleanParams.isEmpty) {
        return uri.replace(query: null).toString();
      }
      
      return uri.replace(queryParameters: cleanParams.cast<String, dynamic>()).toString();
    } catch (e) {
      return url;
    }
  }

  /// Check if URL is from Instagram
  static bool _isInstagramUrl(String url) {
    return url.contains('instagram.com') || url.contains('instagr.am');
  }

  /// Check if URL is from Facebook
  static bool _isFacebookUrl(String url) {
    return url.contains('facebook.com') || 
           url.contains('fb.com') || 
           url.contains('fb.watch');
  }

  /// Check if URL is from X/Twitter
  static bool _isTwitterUrl(String url) {
    return url.contains('twitter.com') || url.contains('x.com');
  }

  /// Parse Instagram URL
  static ParsedUrl _parseInstagramUrl(String url) {
    // Check for stories
    final storyMatch = _instagramStoryRegex.firstMatch(url);
    if (storyMatch != null) {
      final username = storyMatch.group(3);
      final storyId = storyMatch.group(4);
      return ParsedUrl(
        platform: SocialPlatform.instagram,
        normalizedUrl: 'https://www.instagram.com/stories/$username/$storyId/',
        postId: storyId,
        urlType: UrlType.story,
      );
    }

    // Check for posts/reels
    final postMatch = _instagramPostRegex.firstMatch(url);
    if (postMatch != null) {
      final type = postMatch.group(3)?.toLowerCase();
      final postId = postMatch.group(4);
      final urlType = (type == 'reel' || type == 'reels') 
          ? UrlType.reel 
          : UrlType.post;
      
      return ParsedUrl(
        platform: SocialPlatform.instagram,
        normalizedUrl: 'https://www.instagram.com/${type == 'reels' ? 'reel' : type}/$postId/',
        postId: postId,
        urlType: urlType,
      );
    }

    // Check for profile (not supported for download)
    final profileMatch = _instagramProfileRegex.firstMatch(url);
    if (profileMatch != null) {
      return ParsedUrl.invalid(
        'Profile URLs are not supported. Please share a specific post, reel, or story.',
      );
    }

    return ParsedUrl.invalid(
      'Invalid Instagram URL. Please use a post, reel, or story link.',
    );
  }

  /// Parse Facebook URL
  static ParsedUrl _parseFacebookUrl(String url) {
    // Check for fb.watch short links
    final fbWatchMatch = _fbWatchRegex.firstMatch(url);
    if (fbWatchMatch != null) {
      return ParsedUrl(
        platform: SocialPlatform.facebook,
        normalizedUrl: url,
        postId: fbWatchMatch.group(2),
        urlType: UrlType.video,
      );
    }

    // Check for stories
    final storyMatch = _facebookStoryRegex.firstMatch(url);
    if (storyMatch != null) {
      return ParsedUrl(
        platform: SocialPlatform.facebook,
        normalizedUrl: url,
        postId: storyMatch.group(3),
        urlType: UrlType.story,
      );
    }

    // Check for videos
    final videoMatch = _facebookVideoRegex.firstMatch(url);
    if (videoMatch != null) {
      return ParsedUrl(
        platform: SocialPlatform.facebook,
        normalizedUrl: url,
        postId: videoMatch.group(4),
        urlType: UrlType.video,
      );
    }

    // Check for posts/photos
    final postMatch = _facebookPostRegex.firstMatch(url);
    if (postMatch != null) {
      final type = postMatch.group(3);
      return ParsedUrl(
        platform: SocialPlatform.facebook,
        normalizedUrl: url,
        postId: postMatch.group(4),
        urlType: type == 'photos' || type == 'photo' ? UrlType.photo : UrlType.post,
      );
    }

    // Generic Facebook URL - try to process anyway
    if (url.contains('facebook.com')) {
      return ParsedUrl(
        platform: SocialPlatform.facebook,
        normalizedUrl: url,
        urlType: UrlType.unknown,
      );
    }

    return ParsedUrl.invalid(
      'Invalid Facebook URL. Please use a video, post, or story link.',
    );
  }

  /// Parse Twitter/X URL
  static ParsedUrl _parseTwitterUrl(String url) {
    // Check for status/tweet
    final statusMatch = _twitterStatusRegex.firstMatch(url);
    if (statusMatch != null) {
      final username = statusMatch.group(4);
      final tweetId = statusMatch.group(5);
      
      // Normalize to x.com
      return ParsedUrl(
        platform: SocialPlatform.twitter,
        normalizedUrl: 'https://x.com/$username/status/$tweetId',
        postId: tweetId,
        urlType: UrlType.tweet,
      );
    }

    // Check for video-only URL
    final videoMatch = _twitterVideoRegex.firstMatch(url);
    if (videoMatch != null) {
      final tweetId = videoMatch.group(4);
      return ParsedUrl(
        platform: SocialPlatform.twitter,
        normalizedUrl: 'https://x.com/i/status/$tweetId',
        postId: tweetId,
        urlType: UrlType.video,
      );
    }

    return ParsedUrl.invalid(
      'Invalid X (Twitter) URL. Please use a tweet or status link.',
    );
  }

  /// Validate if a string looks like a URL
  static bool isValidUrl(String input) {
    try {
      final cleaned = _cleanUrl(input);
      final uri = Uri.parse(cleaned);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// Quick platform detection without full parsing
  static SocialPlatform detectPlatform(String input) {
    final url = input.toLowerCase();
    
    if (url.contains('instagram.com') || url.contains('instagr.am')) {
      return SocialPlatform.instagram;
    } else if (url.contains('facebook.com') || 
               url.contains('fb.com') || 
               url.contains('fb.watch')) {
      return SocialPlatform.facebook;
    } else if (url.contains('twitter.com') || url.contains('x.com')) {
      return SocialPlatform.twitter;
    }
    
    return SocialPlatform.unknown;
  }
}
