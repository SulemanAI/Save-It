/// X (Twitter) Service
///
/// Handles media extraction from X (formerly Twitter) tweets.
///
/// LIMITATIONS:
/// - Only works with public tweets
/// - Protected/private accounts cannot be accessed
/// - Some media may be age-gated or region-locked
/// - Rate limiting may occur with frequent requests
///
/// APPROACH:
/// We use the syndication API and publish endpoint, along with
/// meta tag parsing for comprehensive extraction.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../../core/constants.dart';
import '../../models/media_info.dart';
import '../../utils/url_parser.dart';
import 'base_platform_service.dart';

class TwitterService extends BasePlatformService {
  @override
  SocialPlatform get platform => SocialPlatform.twitter;

  @override
  Future<MediaInfo> extractMedia(ParsedUrl parsedUrl) async {
    if (!canHandle(parsedUrl)) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Invalid X (Twitter) URL',
      );
    }

    try {
      // Try multiple extraction methods
      MediaInfo? result;

      // Method 1: Try syndication API (most reliable)
      result = await _extractFromSyndication(parsedUrl);
      if (result.isSuccess) return result;

      // Method 2: Try the API v2 approach
      result = await _extractFromApi(parsedUrl);
      if (result.isSuccess) return result;

      // Method 3: Try publish endpoint
      result = await _extractFromPublish(parsedUrl);
      if (result.isSuccess) return result;

      // Method 4: Try direct page scraping
      result = await _extractFromPage(parsedUrl);
      if (result.isSuccess) return result;

      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Could not extract media. The tweet may be private, deleted, or X has blocked the request.',
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Failed to fetch content: ${e.toString()}',
      );
    }
  }

  /// Extract from Twitter syndication API
  Future<MediaInfo> _extractFromSyndication(ParsedUrl parsedUrl) async {
    try {
      if (parsedUrl.postId == null) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'Could not extract tweet ID',
        );
      }

      // Use syndication API with tweet ID
      final syndicationUrl = 'https://cdn.syndication.twimg.com/tweet-result?id=${parsedUrl.postId}&lang=en&token=a';

      final response = await http.get(
        Uri.parse(syndicationUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Origin': 'https://platform.twitter.com',
          'Referer': 'https://platform.twitter.com/',
        },
      ).timeout(AppConstants.httpTimeout);

      if (response.statusCode != 200) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'Failed to fetch syndication data (${response.statusCode})',
        );
      }

      final data = json.decode(response.body);
      final List<MediaItem> mediaItems = [];
      String? username;
      String? caption;

      // Extract user info
      final user = data['user'];
      if (user != null) {
        username = user['screen_name'];
      }

      // Extract text/caption
      caption = data['text'];

      // Check for video
      final video = data['video'];
      if (video != null) {
        final variants = video['variants'] as List?;
        if (variants != null && variants.isNotEmpty) {
          // Filter for mp4 and sort by bitrate
          final mp4Variants = variants
              .where((v) => v['type'] == 'video/mp4' || (v['src'] as String?)?.contains('.mp4') == true)
              .toList();

          if (mp4Variants.isNotEmpty) {
            mp4Variants.sort((a, b) {
              final bitrateA = a['bitrate'] ?? 0;
              final bitrateB = b['bitrate'] ?? 0;
              return (bitrateB as int).compareTo(bitrateA as int);
            });

            final bestVariant = mp4Variants.first;
            final videoUrl = bestVariant['src'] ?? bestVariant['url'];
            if (videoUrl != null) {
              mediaItems.add(MediaItem(
                url: videoUrl,
                type: MediaType.video,
                quality: _getQualityLabel(bestVariant['bitrate']),
              ));
            }
          }
        }

        // Also add video thumbnail as image option
        final poster = video['poster'];
        if (poster != null) {
          mediaItems.add(MediaItem(
            url: _getHighQualityImageUrl(poster),
            type: MediaType.image,
          ));
        }
      }

      // Check for photos
      final photos = data['photos'] as List?;
      if (photos != null) {
        for (final photo in photos) {
          final url = photo['url'];
          if (url != null) {
            mediaItems.add(MediaItem(
              url: _getHighQualityImageUrl(url),
              type: MediaType.image,
            ));
          }
        }
      }

      // Check for mediaDetails (another format)
      final mediaDetails = data['mediaDetails'] as List?;
      if (mediaDetails != null) {
        for (final media in mediaDetails) {
          final type = media['type'];

          if (type == 'video' || type == 'animated_gif') {
            final videoInfo = media['video_info'];
            if (videoInfo != null) {
              final variants = videoInfo['variants'] as List?;
              if (variants != null) {
                final mp4Variants = variants
                    .where((v) => v['content_type'] == 'video/mp4')
                    .toList();

                if (mp4Variants.isNotEmpty) {
                  mp4Variants.sort((a, b) {
                    final bitrateA = a['bitrate'] ?? 0;
                    final bitrateB = b['bitrate'] ?? 0;
                    return (bitrateB as int).compareTo(bitrateA as int);
                  });

                  final bestVariant = mp4Variants.first;
                  final videoUrl = bestVariant['url'];
                  if (videoUrl != null && !mediaItems.any((m) => m.url == videoUrl)) {
                    mediaItems.add(MediaItem(
                      url: videoUrl,
                      type: MediaType.video,
                      quality: _getQualityLabel(bestVariant['bitrate']),
                    ));
                  }
                }
              }
            }
          } else if (type == 'photo') {
            final url = media['media_url_https'] ?? media['media_url'];
            if (url != null) {
              final highQualityUrl = _getHighQualityImageUrl(url);
              if (!mediaItems.any((m) => m.url == highQualityUrl)) {
                mediaItems.add(MediaItem(
                  url: highQualityUrl,
                  type: MediaType.image,
                ));
              }
            }
          }
        }
      }

      if (mediaItems.isEmpty) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'No media found in syndication data',
        );
      }

      return MediaInfo(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        mediaItems: _removeDuplicates(mediaItems),
        postId: parsedUrl.postId,
        username: username,
        caption: caption,
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Syndication extraction failed: ${e.toString()}',
      );
    }
  }

  /// Extract using API approach
  Future<MediaInfo> _extractFromApi(ParsedUrl parsedUrl) async {
    try {
      if (parsedUrl.postId == null) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'Could not extract tweet ID',
        );
      }

      // Try the guest token approach
      final activateResponse = await http.post(
        Uri.parse('https://api.twitter.com/1.1/guest/activate.json'),
        headers: {
          'Authorization': 'Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs=1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA',
        },
      ).timeout(AppConstants.httpTimeout);

      if (activateResponse.statusCode == 200) {
        final guestData = json.decode(activateResponse.body);
        final guestToken = guestData['guest_token'];

        if (guestToken != null) {
          final tweetResponse = await http.get(
            Uri.parse('https://api.twitter.com/1.1/statuses/show.json?id=${parsedUrl.postId}&tweet_mode=extended'),
            headers: {
              'Authorization': 'Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs=1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA',
              'x-guest-token': guestToken,
            },
          ).timeout(AppConstants.httpTimeout);

          if (tweetResponse.statusCode == 200) {
            final tweetData = json.decode(tweetResponse.body);
            final List<MediaItem> mediaItems = [];

            final extendedEntities = tweetData['extended_entities'];
            if (extendedEntities != null) {
              final media = extendedEntities['media'] as List?;
              if (media != null) {
                for (final item in media) {
                  final type = item['type'];
                  if (type == 'video' || type == 'animated_gif') {
                    final videoInfo = item['video_info'];
                    final variants = videoInfo?['variants'] as List?;
                    if (variants != null) {
                      final mp4Variants = variants
                          .where((v) => v['content_type'] == 'video/mp4')
                          .toList();

                      if (mp4Variants.isNotEmpty) {
                        mp4Variants.sort((a, b) {
                          final bitrateA = a['bitrate'] ?? 0;
                          final bitrateB = b['bitrate'] ?? 0;
                          return (bitrateB as int).compareTo(bitrateA as int);
                        });

                        mediaItems.add(MediaItem(
                          url: mp4Variants.first['url'],
                          type: MediaType.video,
                        ));
                      }
                    }
                  } else if (type == 'photo') {
                    final url = item['media_url_https'];
                    if (url != null) {
                      mediaItems.add(MediaItem(
                        url: _getHighQualityImageUrl(url),
                        type: MediaType.image,
                      ));
                    }
                  }
                }
              }
            }

            if (mediaItems.isNotEmpty) {
              return MediaInfo(
                platform: platform,
                originalUrl: parsedUrl.normalizedUrl,
                mediaItems: _removeDuplicates(mediaItems),
                postId: parsedUrl.postId,
                username: tweetData['user']?['screen_name'],
                caption: tweetData['full_text'] ?? tweetData['text'],
              );
            }
          }
        }
      }

      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'API extraction failed',
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'API error: ${e.toString()}',
      );
    }
  }

  /// Extract from publish.twitter.com endpoint
  Future<MediaInfo> _extractFromPublish(ParsedUrl parsedUrl) async {
    try {
      final publishUrl =
          'https://publish.twitter.com/oembed?url=${Uri.encodeComponent(parsedUrl.normalizedUrl)}';

      final response = await http.get(
        Uri.parse(publishUrl),
        headers: defaultHeaders,
      ).timeout(AppConstants.httpTimeout);

      if (response.statusCode != 200) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'Failed to fetch publish data',
        );
      }

      final data = json.decode(response.body);
      final List<MediaItem> mediaItems = [];
      String? username;

      // Get author
      username = data['author_name'];

      // Parse the HTML content to find media
      final html = data['html'];
      if (html != null) {
        final document = html_parser.parse(html);

        // Look for images in the embedded HTML
        final images = document.querySelectorAll('img');
        for (final img in images) {
          final src = img.attributes['src'];
          if (src != null && src.contains('pbs.twimg.com/media')) {
            mediaItems.add(MediaItem(
              url: _getHighQualityImageUrl(src),
              type: MediaType.image,
            ));
          }
        }
      }

      if (mediaItems.isEmpty) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'No media found in publish data',
        );
      }

      return MediaInfo(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        mediaItems: _removeDuplicates(mediaItems),
        postId: parsedUrl.postId,
        username: username,
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Publish extraction failed',
      );
    }
  }

  /// Extract from direct page scraping
  Future<MediaInfo> _extractFromPage(ParsedUrl parsedUrl) async {
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

      // Check og:image
      final ogImage = document.querySelector('meta[property="og:image"]');
      if (ogImage != null) {
        final content = ogImage.attributes['content'];
        if (content != null && content.isNotEmpty) {
          mediaItems.add(MediaItem(
            url: _getHighQualityImageUrl(content),
            type: MediaType.image,
          ));
        }
      }

      // Look for video URLs in page source
      final videoUrlMatches = RegExp(r'"(https?://video\.twimg\.com/[^"]+\.mp4[^"]*)"')
          .allMatches(body);
      for (final match in videoUrlMatches) {
        var videoUrl = match.group(1)!.replaceAll(r'\/', '/');
        if (!mediaItems.any((m) => m.url == videoUrl)) {
          mediaItems.add(MediaItem(
            url: videoUrl,
            type: MediaType.video,
          ));
        }
      }

      if (mediaItems.isEmpty) {
        return MediaInfo.error(
          platform: platform,
          originalUrl: parsedUrl.normalizedUrl,
          errorMessage: 'No media found on page',
        );
      }

      return MediaInfo(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        mediaItems: _removeDuplicates(mediaItems),
        postId: parsedUrl.postId,
      );
    } catch (e) {
      return MediaInfo.error(
        platform: platform,
        originalUrl: parsedUrl.normalizedUrl,
        errorMessage: 'Page extraction failed',
      );
    }
  }

  /// Get highest quality image URL
  String _getHighQualityImageUrl(String url) {
    // Twitter image URLs can have size modifiers
    var cleanUrl = url
        .replaceAll(RegExp(r'[:?]small'), '')
        .replaceAll(RegExp(r'[:?]medium'), '')
        .replaceAll(RegExp(r'[:?]large'), '')
        .replaceAll(RegExp(r'[:?]thumb'), '')
        .replaceAll('&name=small', '')
        .replaceAll('&name=medium', '')
        .replaceAll('&name=large', '')
        .replaceAll('&name=thumb', '')
        .replaceAll('?name=small', '?name=orig')
        .replaceAll('?name=medium', '?name=orig');

    // If it doesn't have :orig or name=orig, add it
    if (!cleanUrl.contains(':orig') && !cleanUrl.contains('name=orig')) {
      if (cleanUrl.contains('?')) {
        if (!cleanUrl.contains('name=')) {
          cleanUrl = '$cleanUrl&name=orig';
        }
      } else {
        cleanUrl = '$cleanUrl?name=orig';
      }
    }

    return cleanUrl;
  }

  /// Get quality label from bitrate
  String? _getQualityLabel(dynamic bitrate) {
    if (bitrate == null) return null;
    final rate = bitrate is int ? bitrate : int.tryParse(bitrate.toString()) ?? 0;

    if (rate >= 2000000) return '1080p';
    if (rate >= 1000000) return '720p';
    if (rate >= 500000) return '480p';
    if (rate >= 200000) return '360p';
    return null;
  }

  /// Remove duplicate media items
  List<MediaItem> _removeDuplicates(List<MediaItem> items) {
    final seen = <String>{};
    return items.where((item) {
      // Normalize URL for comparison
      final normalized = item.url
          .split('?')
          .first
          .replaceAll(RegExp(r':orig$'), '');
      if (seen.contains(normalized)) return false;
      seen.add(normalized);
      return true;
    }).toList();
  }
}
