/// Backend API Service
///
/// Connects to our backend server for reliable media extraction.
library;

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/media_info.dart';
import '../utils/url_parser.dart';

/// Service that connects to the backend for media extraction
class BackendApiService {
  // Change this to your deployed backend URL for production
  // For local testing, use your computer's IP address (not localhost)
  
  // Your local network IP - update this if your IP changes
  static String baseUrl = 'http://192.168.100.217:3000';
  
  // For physical device testing, set this to your computer's local IP
  // static String baseUrl = 'http://YOUR_COMPUTER_IP:3000';
  
  /// Check if the backend is available
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Extract media from a URL using the backend
  static Future<MediaInfo> extractMedia(String url) async {
    final parsedUrl = UrlParser.parse(url);
    
    if (!parsedUrl.isValid) {
      return MediaInfo.error(
        platform: parsedUrl.platform,
        originalUrl: url,
        errorMessage: parsedUrl.errorMessage ?? 'Invalid URL',
      );
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/extract'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'url': url}),
      ).timeout(const Duration(seconds: 20));
      
      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        final List<MediaItem> mediaItems = [];
        
        final mediaList = data['media'] as List? ?? [];
        for (final item in mediaList) {
          final itemUrl = item['url'] as String?;
          final itemType = item['type'] as String?;
          
          if (itemUrl != null) {
            mediaItems.add(MediaItem(
              url: itemUrl,
              type: _parseMediaType(itemType),
              quality: item['quality'] as String?,
            ));
          }
        }
        
        if (mediaItems.isNotEmpty) {
          return MediaInfo(
            platform: parsedUrl.platform,
            originalUrl: url,
            mediaItems: mediaItems,
            postId: parsedUrl.postId,
            username: data['username'] as String?,
            caption: data['caption'] as String?,
          );
        } else {
          return MediaInfo.error(
            platform: parsedUrl.platform,
            originalUrl: url,
            errorMessage: 'No media items found',
          );
        }
      } else {
        return MediaInfo.error(
          platform: parsedUrl.platform,
          originalUrl: url,
          errorMessage: data['error'] ?? 'Extraction failed',
        );
      }
    } on TimeoutException {
      return MediaInfo.error(
        platform: parsedUrl.platform,
        originalUrl: url,
        errorMessage: 'Backend server timed out. Make sure the server is running.',
      );
    } catch (e) {
      return MediaInfo.error(
        platform: parsedUrl.platform,
        originalUrl: url,
        errorMessage: 'Cannot connect to server. Is the backend running?',
      );
    }
  }
  
  static MediaType _parseMediaType(String? type) {
    switch (type) {
      case 'video':
        return MediaType.video;
      case 'image':
        return MediaType.image;
      default:
        return MediaType.unknown;
    }
  }
  
  /// Set the backend URL (for configuring different environments)
  static void setBaseUrl(String url) {
    baseUrl = url;
  }
}
