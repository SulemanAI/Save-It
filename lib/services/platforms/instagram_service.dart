/// Instagram Service
///
/// Handles media extraction from Instagram posts, reels, and stories.
///
/// LIMITATIONS:
/// - Only works with public content
/// - Stories require a valid story URL (may expire quickly)
/// - Private profiles cannot be accessed
/// - Rate limiting may occur with frequent requests
///
/// APPROACH:
/// We use multiple extraction methods with fallbacks to maximize success.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../../core/constants.dart';
import '../../models/media_info.dart';
import '../../utils/url_parser.dart';
import 'base_platform_service.dart';

class InstagramService extends BasePlatformService {
  @override
  SocialPlatform get platform => SocialPlatform.instagram;

  @override
  Future<MediaInfo> extractMedia(ParsedUrl parsedUrl) async {
    if (!canHandle(parsedUrl)) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Invalid Instagram URL',
      );
    }

    try {
      // Try multiple extraction methods
      MediaInfo? result;

      // Method 1: Try the GraphQL API approach
      result = await _extractFromGraphQL(parsedUrl);
      if (result.isSuccess) return result;

      // Method 2: Try embed page (most reliable for public content)
      result = await _extractFromEmbed(parsedUrl);
      if (result.isSuccess) return result;

      // Method 3: Try direct page scraping with og tags
      result = await _extractFromOgTags(parsedUrl);
      if (result.isSuccess) return result;

      // Method 4: Try mobile page
      result = await _extractFromMobilePage(parsedUrl);
      if (result.isSuccess) return result;

      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Could not extract media. The content may be private, deleted, or Instagram has blocked the request.',
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Failed to fetch content: ${e.toString()}',
      );
    }
  }

  /// Extract using Instagram's GraphQL endpoint
  Future<MediaInfo> _extractFromGraphQL(ParsedUrl parsedUrl) async {
    try {
      // Get the shortcode from the URL
      final shortcode = parsedUrl.postId;
      if (shortcode == null || shortcode.isEmpty) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'Could not extract post ID',
        );
      }

      // Try to fetch the post page and extract __additionalDataLoaded or similar
      final response = await http.get(
        Uri.parse('${parsedUrl.normalizedUrl}?__a=1&__d=dis'),
        headers: {
          ...defaultHeaders,
          'X-IG-App-ID': '936619743392459',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ).timeout(AppConstants.httpTimeout);

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          final items = jsonData['items'] as List?;
          if (items != null && items.isNotEmpty) {
            final item = items.first;
            final List<MediaItem> mediaItems = [];

            // Check for video
            final videoVersions = item['video_versions'] as List?;
            if (videoVersions != null && videoVersions.isNotEmpty) {
              final bestVideo = videoVersions.first;
              mediaItems.add(MediaItem(
                url: bestVideo['url'],
                type: parsedUrl.urlType == UrlType.reel ? MediaType.reel : MediaType.video,
              ));
            }

            // Check for image
            final imageVersions = item['image_versions2']?['candidates'] as List?;
            if (imageVersions != null && imageVersions.isNotEmpty) {
              final bestImage = imageVersions.first;
              mediaItems.add(MediaItem(
                url: bestImage['url'],
                type: MediaType.image,
              ));
            }

            // Check for carousel
            final carouselMedia = item['carousel_media'] as List?;
            if (carouselMedia != null) {
              for (final media in carouselMedia) {
                final videoVersions = media['video_versions'] as List?;
                if (videoVersions != null && videoVersions.isNotEmpty) {
                  mediaItems.add(MediaItem(
                    url: videoVersions.first['url'],
                    type: MediaType.video,
                  ));
                } else {
                  final imageVersions = media['image_versions2']?['candidates'] as List?;
                  if (imageVersions != null && imageVersions.isNotEmpty) {
                    mediaItems.add(MediaItem(
                      url: imageVersions.first['url'],
                      type: MediaType.image,
                    ));
                  }
                }
              }
            }

            if (mediaItems.isNotEmpty) {
              return MediaInfo(
                platform: platform,
                originalUrl: parsedUrl.normalizedUrl,
                mediaItems: mediaItems,
                postId: shortcode,
                username: item['user']?['username'],
                caption: item['caption']?['text'],
              );
            }
          }
        } catch (_) {
          // JSON parsing failed, try other methods
        }
      }

      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'GraphQL extraction failed',
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'GraphQL error: ${e.toString()}',
      );
    }
  }

  /// Extract media from Instagram embed page
  Future<MediaInfo> _extractFromEmbed(ParsedUrl parsedUrl) async {
    try {
      // Build embed URL
      final embedUrl = '${parsedUrl.normalizedUrl}embed/captioned/';

      final response = await http.get(
        Uri.parse(embedUrl),
        headers: defaultHeaders,
      ).timeout(AppConstants.httpTimeout);

      if (response.statusCode != 200) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'Failed to load embed page (${response.statusCode})',
        );
      }

      final body = response.body;
      final List<MediaItem> mediaItems = [];
      String? username;
      String? caption;

      // Parse HTML
      final document = html_parser.parse(body);

      // Try to find video source
      final videoElements = document.querySelectorAll('video');
      for (final video in videoElements) {
        final src = video.attributes['src'];
        if (src != null && src.isNotEmpty) {
          mediaItems.add(MediaItem(
            url: src,
            type: parsedUrl.urlType == UrlType.reel ? MediaType.reel : MediaType.video,
          ));
        }

        // Also check source elements
        final sources = video.querySelectorAll('source');
        for (final source in sources) {
          final srcUrl = source.attributes['src'];
          if (srcUrl != null && srcUrl.isNotEmpty && !mediaItems.any((m) => m.url == srcUrl)) {
            mediaItems.add(MediaItem(
              url: srcUrl,
              type: parsedUrl.urlType == UrlType.reel ? MediaType.reel : MediaType.video,
            ));
          }
        }
      }

      // Try to find image source - look for high quality images
      final imgElements = document.querySelectorAll('img');
      for (final img in imgElements) {
        final src = img.attributes['src'];
        final className = img.attributes['class'] ?? '';
        
        // Look for the main content image
        if (src != null && src.isNotEmpty && 
            (className.contains('EmbeddedMedia') || src.contains('instagram') || src.contains('cdninstagram'))) {
          if (!src.contains('profile') && !src.contains('avatar') && !src.contains('s150x150')) {
            mediaItems.add(MediaItem(
              url: src,
              type: MediaType.image,
            ));
          }
        }
      }

      // Try to extract from embedded script data
      final scripts = document.querySelectorAll('script');
      for (final script in scripts) {
        final content = script.text;
        
        // Look for video_url in script
        final videoUrlMatch = RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(content);
        if (videoUrlMatch != null) {
          var videoUrl = videoUrlMatch.group(1)!;
          videoUrl = _unescapeUrl(videoUrl);
          if (!mediaItems.any((m) => m.url == videoUrl)) {
            mediaItems.add(MediaItem(
              url: videoUrl,
              type: MediaType.video,
            ));
          }
        }

        // Look for display_url in script
        final displayUrlMatch = RegExp(r'"display_url"\s*:\s*"([^"]+)"').firstMatch(content);
        if (displayUrlMatch != null) {
          var imageUrl = displayUrlMatch.group(1)!;
          imageUrl = _unescapeUrl(imageUrl);
          if (!mediaItems.any((m) => m.url == imageUrl)) {
            mediaItems.add(MediaItem(
              url: imageUrl,
              type: MediaType.image,
            ));
          }
        }
      }

      // Extract username from page
      final usernameElement = document.querySelector('.UsernameText');
      username = usernameElement?.text;

      // Extract caption
      final captionElement = document.querySelector('.Caption');
      caption = captionElement?.text;

      if (mediaItems.isEmpty) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'No media found in embed page',
        );
      }

      // Remove duplicates
      final uniqueItems = _removeDuplicates(mediaItems);

      return MediaInfo(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        mediaItems: uniqueItems,
        postId: parsedUrl.postId,
        username: username,
        caption: caption,
        isStory: parsedUrl.urlType == UrlType.story,
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Embed extraction failed: ${e.toString()}',
      );
    }
  }

  /// Extract from OG meta tags
  Future<MediaInfo> _extractFromOgTags(ParsedUrl parsedUrl) async {
    try {
      final response = await http.get(
        Uri.parse(parsedUrl.normalizedUrl),
        headers: defaultHeaders,
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

      // Try og:image
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

      // Also search in page content for media URLs
      final videoUrlMatch = RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(body);
      if (videoUrlMatch != null) {
        var videoUrl = videoUrlMatch.group(1)!;
        videoUrl = _unescapeUrl(videoUrl);
        if (!mediaItems.any((m) => m.url == videoUrl)) {
          mediaItems.add(MediaItem(
            url: videoUrl,
            type: MediaType.video,
          ));
        }
      }

      final displayUrlMatch = RegExp(r'"display_url"\s*:\s*"([^"]+)"').firstMatch(body);
      if (displayUrlMatch != null) {
        var imageUrl = displayUrlMatch.group(1)!;
        imageUrl = _unescapeUrl(imageUrl);
        if (!mediaItems.any((m) => m.url == imageUrl)) {
          mediaItems.add(MediaItem(
            url: imageUrl,
            type: MediaType.image,
          ));
        }
      }

      if (mediaItems.isEmpty) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'No media found in page',
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
        errorMessage: 'OG tag extraction failed',
      );
    }
  }

  /// Try mobile page (sometimes has different data)
  Future<MediaInfo> _extractFromMobilePage(ParsedUrl parsedUrl) async {
    try {
      final mobileHeaders = Map<String, String>.from(defaultHeaders);
      mobileHeaders['User-Agent'] = 'Instagram 275.0.0.27.98 Android (33/13; 420dpi; 1080x2400; samsung; SM-G991B; exynos2100; exynos2100)';

      final response = await http.get(
        Uri.parse(parsedUrl.normalizedUrl),
        headers: mobileHeaders,
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

      // Look for video_versions in response
      final videoVersionsMatch = RegExp(r'"video_versions"\s*:\s*\[([^\]]+)\]').firstMatch(body);
      if (videoVersionsMatch != null) {
        final versionsStr = videoVersionsMatch.group(1)!;
        final urlMatches = RegExp(r'"url"\s*:\s*"([^"]+)"').allMatches(versionsStr);
        for (final match in urlMatches) {
          var url = match.group(1)!;
          url = _unescapeUrl(url);
          mediaItems.add(MediaItem(
            url: url,
            type: MediaType.video,
          ));
          break; // Just take the first (usually highest quality)
        }
      }

      // Look for image_versions2
      final imageVersionsMatch = RegExp(r'"image_versions2"\s*:\s*\{[^}]*"candidates"\s*:\s*\[([^\]]+)\]').firstMatch(body);
      if (imageVersionsMatch != null) {
        final candidatesStr = imageVersionsMatch.group(1)!;
        final urlMatches = RegExp(r'"url"\s*:\s*"([^"]+)"').allMatches(candidatesStr);
        for (final match in urlMatches) {
          var url = match.group(1)!;
          url = _unescapeUrl(url);
          mediaItems.add(MediaItem(
            url: url,
            type: MediaType.image,
          ));
          break; // Just take the first (usually highest quality)
        }
      }

      if (mediaItems.isEmpty) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'No media found in mobile page',
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
        errorMessage: 'Mobile extraction failed',
      );
    }
  }

  /// Unescape URL encoded strings
  String _unescapeUrl(String url) {
    return url
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\\u0026', '&')
        .replaceAll(r'\\/', '/')
        .replaceAll(r'\u003C', '<')
        .replaceAll(r'\u003E', '>')
        .replaceAll(r'\\', '');
  }

  /// Remove duplicate media items
  List<MediaItem> _removeDuplicates(List<MediaItem> items) {
    final seen = <String>{};
    return items.where((item) {
      final normalized = item.url.split('?').first; // Ignore query params for comparison
      if (seen.contains(normalized)) return false;
      seen.add(normalized);
      return true;
    }).toList();
  }
}
