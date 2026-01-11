/// Facebook Service
///
/// Handles media extraction from Facebook videos, posts, and reels.
///
/// LIMITATIONS:
/// - Only works with public content
/// - Some videos are protected and cannot be downloaded
/// - Stories require a valid unexpired URL
/// - Private groups/profiles cannot be accessed
/// - Facebook frequently changes their structure
///
/// APPROACH:
/// We parse the page HTML to find video sources and use
/// meta tags for fallback. No authentication is used.
library;

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../../core/constants.dart';
import '../../models/media_info.dart';
import '../../utils/url_parser.dart';
import 'base_platform_service.dart';

class FacebookService extends BasePlatformService {
  @override
  SocialPlatform get platform => SocialPlatform.facebook;

  @override
  Future<MediaInfo> extractMedia(ParsedUrl parsedUrl) async {
    if (!canHandle(parsedUrl)) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Invalid Facebook URL',
      );
    }

    try {
      // Try multiple extraction methods
      MediaInfo? result;

      // Method 1: Try mobile site (usually has more accessible data)
      result = await _extractFromMobile(parsedUrl);
      if (result.isSuccess) return result;

      // Method 2: Try desktop site with different patterns
      result = await _extractFromDesktop(parsedUrl);
      if (result.isSuccess) return result;

      // Method 3: Try mbasic (basic mobile)
      result = await _extractFromMbasic(parsedUrl);
      if (result.isSuccess) return result;

      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Could not extract media. The content may be private, deleted, or region-locked.',
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Failed to fetch content: ${e.toString()}',
      );
    }
  }

  /// Extract from mobile site
  Future<MediaInfo> _extractFromMobile(ParsedUrl parsedUrl) async {
    try {
      // Convert to mobile URL
      var mobileUrl = parsedUrl.normalizedUrl
          .replaceAll('www.facebook.com', 'm.facebook.com')
          .replaceAll('web.facebook.com', 'm.facebook.com');

      // For fb.watch links, we need to follow redirect
      if (parsedUrl.normalizedUrl.contains('fb.watch')) {
        try {
          final redirectResponse = await http.get(
            Uri.parse(parsedUrl.normalizedUrl),
            headers: defaultHeaders,
          ).timeout(AppConstants.httpTimeout);

          // Try to find the actual URL in meta refresh or body
          if (redirectResponse.statusCode == 200) {
            final body = redirectResponse.body;
            // Look for the redirect URL
            final redirectMatch = RegExp(r'content="0;url=([^"]+)"').firstMatch(body);
            if (redirectMatch != null) {
              mobileUrl = Uri.decodeFull(redirectMatch.group(1)!)
                  .replaceAll('www.facebook.com', 'm.facebook.com');
            }
          }
        } catch (_) {
          // Continue with original URL
        }
      }

      final response = await http.get(
        Uri.parse(mobileUrl),
        headers: {
          ...defaultHeaders,
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
        },
      ).timeout(AppConstants.httpTimeout);

      if (response.statusCode != 200) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'Failed to load mobile page',
        );
      }

      final body = response.body;
      final List<MediaItem> mediaItems = [];

      // Pattern 1: Look for playable_url patterns (HD first, then SD)
      final hdPatterns = [
        RegExp(r'playable_url_quality_hd["\s:]+([^"]+)'),
        RegExp(r'"hd_src"\s*:\s*"([^"]+)"'),
        RegExp(r'"hd_src_no_ratelimit"\s*:\s*"([^"]+)"'),
        RegExp(r'browser_native_hd_url["\s:]+([^"]+)'),
      ];

      for (final pattern in hdPatterns) {
        final match = pattern.firstMatch(body);
        if (match != null) {
          var videoUrl = _cleanFacebookUrl(match.group(1)!);
          if (_isValidVideoUrl(videoUrl)) {
            mediaItems.add(MediaItem(
              url: videoUrl,
              type: MediaType.video,
              quality: 'HD',
            ));
            break;
          }
        }
      }

      // If no HD, try SD
      if (mediaItems.isEmpty) {
        final sdPatterns = [
          RegExp(r'playable_url["\s:]+([^"]+)'),
          RegExp(r'"sd_src"\s*:\s*"([^"]+)"'),
          RegExp(r'"sd_src_no_ratelimit"\s*:\s*"([^"]+)"'),
          RegExp(r'browser_native_sd_url["\s:]+([^"]+)'),
        ];

        for (final pattern in sdPatterns) {
          final match = pattern.firstMatch(body);
          if (match != null) {
            var videoUrl = _cleanFacebookUrl(match.group(1)!);
            if (_isValidVideoUrl(videoUrl)) {
              mediaItems.add(MediaItem(
                url: videoUrl,
                type: MediaType.video,
                quality: 'SD',
              ));
              break;
            }
          }
        }
      }

      // Try generic video URL pattern
      if (mediaItems.isEmpty) {
        // Look for video URLs in various formats
        final videoPatterns = [
          RegExp(r'"(https?://video[^"]*?\.mp4[^"]*?)"'),
          RegExp(r'"(https?://[^"]*?fbcdn[^"]*?\.mp4[^"]*?)"'),
          RegExp(r'"(https?://[^"]*?video[^"]*?fbcdn[^"]*?)"'),
        ];

        for (final pattern in videoPatterns) {
          final matches = pattern.allMatches(body);
          for (final match in matches) {
            var videoUrl = _cleanFacebookUrl(match.group(1)!);
            if (_isValidVideoUrl(videoUrl) && !mediaItems.any((m) => m.url == videoUrl)) {
              mediaItems.add(MediaItem(
                url: videoUrl,
                type: MediaType.video,
              ));
              if (mediaItems.length >= 2) break;
            }
          }
          if (mediaItems.isNotEmpty) break;
        }
      }

      // Also try to find images
      final document = html_parser.parse(body);

      // Check meta tags
      final ogImage = document.querySelector('meta[property="og:image"]');
      if (ogImage != null) {
        final content = ogImage.attributes['content'];
        if (content != null && content.isNotEmpty && !content.contains('placeholder')) {
          mediaItems.add(MediaItem(
            url: content,
            type: MediaType.image,
          ));
        }
      }

      if (mediaItems.isEmpty) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'No media found on mobile page',
        );
      }

      return MediaInfo(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        mediaItems: _removeDuplicates(mediaItems),
        postId: parsedUrl.postId,
        isStory: parsedUrl.urlType == UrlType.story,
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Mobile extraction failed: ${e.toString()}',
      );
    }
  }

  /// Extract from desktop site
  Future<MediaInfo> _extractFromDesktop(ParsedUrl parsedUrl) async {
    try {
      final response = await http.get(
        Uri.parse(parsedUrl.normalizedUrl),
        headers: {
          ...defaultHeaders,
          'User-Agent': AppConstants.desktopUserAgent,
        },
      ).timeout(AppConstants.httpTimeout);

      if (response.statusCode != 200) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'Failed to load page',
        );
      }

      final body = response.body;
      final List<MediaItem> mediaItems = [];

      // Parse HTML
      final document = html_parser.parse(body);

      // Check og:video meta tag
      final ogVideo = document.querySelector('meta[property="og:video"]');
      if (ogVideo != null) {
        final content = ogVideo.attributes['content'];
        if (content != null && content.isNotEmpty) {
          mediaItems.add(MediaItem(
            url: content,
            type: MediaType.video,
          ));
        }
      }

      // Check og:video:url
      final ogVideoUrl = document.querySelector('meta[property="og:video:url"]');
      if (ogVideoUrl != null) {
        final content = ogVideoUrl.attributes['content'];
        if (content != null && content.isNotEmpty && !mediaItems.any((m) => m.url == content)) {
          mediaItems.add(MediaItem(
            url: content,
            type: MediaType.video,
          ));
        }
      }

      // Check og:video:secure_url
      final ogVideoSecure = document.querySelector('meta[property="og:video:secure_url"]');
      if (ogVideoSecure != null) {
        final content = ogVideoSecure.attributes['content'];
        if (content != null && content.isNotEmpty && !mediaItems.any((m) => m.url == content)) {
          mediaItems.add(MediaItem(
            url: content,
            type: MediaType.video,
          ));
        }
      }

      // Check og:image
      final ogImage = document.querySelector('meta[property="og:image"]');
      if (ogImage != null) {
        final content = ogImage.attributes['content'];
        if (content != null && content.isNotEmpty) {
          mediaItems.add(MediaItem(
            url: content,
            type: MediaType.image,
          ));
        }
      }

      // Try to find video in script data
      final videoPatterns = [
        RegExp(r'playable_url(?:_quality_hd)?["\s:]+([^"]+)'),
        RegExp(r'"video_url"\s*:\s*"([^"]+)"'),
      ];

      for (final pattern in videoPatterns) {
        final match = pattern.firstMatch(body);
        if (match != null) {
          var videoUrl = _cleanFacebookUrl(match.group(1)!);
          if (_isValidVideoUrl(videoUrl) && !mediaItems.any((m) => m.url == videoUrl)) {
            mediaItems.add(MediaItem(
              url: videoUrl,
              type: MediaType.video,
            ));
          }
        }
      }

      if (mediaItems.isEmpty) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'No media found on desktop page',
        );
      }

      return MediaInfo(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        mediaItems: _removeDuplicates(mediaItems),
        postId: parsedUrl.postId,
        isStory: parsedUrl.urlType == UrlType.story,
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Desktop extraction failed',
      );
    }
  }

  /// Try mbasic Facebook (very basic HTML version)
  Future<MediaInfo> _extractFromMbasic(ParsedUrl parsedUrl) async {
    try {
      // Convert to mbasic URL
      final mbasicUrl = parsedUrl.normalizedUrl
          .replaceAll('www.facebook.com', 'mbasic.facebook.com')
          .replaceAll('m.facebook.com', 'mbasic.facebook.com')
          .replaceAll('web.facebook.com', 'mbasic.facebook.com');

      final response = await http.get(
        Uri.parse(mbasicUrl),
        headers: defaultHeaders,
      ).timeout(AppConstants.httpTimeout);

      if (response.statusCode != 200) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'Failed to load mbasic page',
        );
      }

      final body = response.body;
      final List<MediaItem> mediaItems = [];
      final document = html_parser.parse(body);

      // Look for video links
      final videoLinks = document.querySelectorAll('a[href*="video"]');
      for (final link in videoLinks) {
        final href = link.attributes['href'];
        if (href != null && (href.contains('.mp4') || href.contains('video_redirect'))) {
          String videoUrl = href.startsWith('http') ? href : 'https://mbasic.facebook.com$href';
          mediaItems.add(MediaItem(
            url: videoUrl,
            type: MediaType.video,
          ));
        }
      }

      // Look for images
      final images = document.querySelectorAll('img');
      for (final img in images) {
        final src = img.attributes['src'];
        if (src != null && (src.contains('scontent') || src.contains('fbcdn')) && !src.contains('emoji')) {
          mediaItems.add(MediaItem(
            url: src,
            type: MediaType.image,
          ));
        }
      }

      if (mediaItems.isEmpty) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'No media found on mbasic page',
        );
      }

      return MediaInfo(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        mediaItems: _removeDuplicates(mediaItems),
        postId: parsedUrl.postId,
        isStory: parsedUrl.urlType == UrlType.story,
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Mbasic extraction failed',
      );
    }
  }

  /// Clean and decode Facebook URL
  String _cleanFacebookUrl(String url) {
    return url
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\\u0026', '&')
        .replaceAll(r'\\/', '/')
        .replaceAll(r'\u003c', '<')
        .replaceAll(r'\u003e', '>')
        .replaceAll(r'\\', '');
  }

  /// Check if URL looks like a valid video URL
  bool _isValidVideoUrl(String url) {
    return url.isNotEmpty &&
        (url.contains('.mp4') || url.contains('video')) &&
        url.startsWith('http') &&
        !url.contains('placeholder') &&
        !url.contains('null');
  }

  /// Remove duplicate media items
  List<MediaItem> _removeDuplicates(List<MediaItem> items) {
    final seen = <String>{};
    return items.where((item) {
      final normalized = item.url.split('?').first;
      if (seen.contains(normalized)) return false;
      seen.add(normalized);
      return true;
    }).toList();
  }
}
