/// Media Service
///
/// Main service that coordinates media extraction.
/// Uses the backend server for reliable extraction.
library;

import 'dart:async';

import '../core/constants.dart';
import '../models/media_info.dart';
import '../utils/url_parser.dart';
import 'backend_api.dart';

/// Main media extraction service
class MediaService {
  bool _backendAvailable = false;
  bool _checkedBackend = false;
  
  /// Parse a URL and detect the platform
  ParsedUrl parseUrl(String url) {
    return UrlParser.parse(url);
  }

  /// Check if backend is available
  Future<bool> _checkBackend() async {
    if (_checkedBackend) return _backendAvailable;
    
    _backendAvailable = await BackendApiService.healthCheck();
    _checkedBackend = true;
    
    print('[MediaService] Backend available: $_backendAvailable');
    return _backendAvailable;
  }

  /// Extract media from a URL
  /// 
  /// Uses the backend server for extraction.
  /// Returns an error if backend is not available.
  Future<MediaInfo> extractMedia(String url) async {
    // First, parse the URL
    final parsedUrl = parseUrl(url);
    
    if (!parsedUrl.isValid) {
      return MediaInfo.error(
        platform: parsedUrl.platform,
        originalUrl: url,
        errorMessage: parsedUrl.errorMessage ?? 'Invalid URL',
      );
    }

    try {
      // Check if backend is available
      final backendUp = await _checkBackend();
      
      if (backendUp) {
        // Use backend for extraction
        print('[MediaService] Using backend for extraction');
        final result = await BackendApiService.extractMedia(url);
        
        if (result.isSuccess) {
          return result;
        }
        
        // Return the error with details
        return MediaInfo.error(
          platform: parsedUrl.platform,
          originalUrl: url,
          errorMessage: result.errorMessage ?? 'Extraction failed. The content may be private or unavailable.',
        );
      } else {
        return MediaInfo.error(
          platform: parsedUrl.platform,
          originalUrl: url,
          errorMessage: 'Backend server not available. Please make sure the server is running.',
        );
      }
    } catch (e) {
      return MediaInfo.error(
        platform: parsedUrl.platform,
        originalUrl: url,
        errorMessage: 'Failed to extract media: ${e.toString()}',
      );
    }
  }

  /// Quick platform detection without full parsing
  SocialPlatform detectPlatform(String url) {
    return UrlParser.detectPlatform(url);
  }

  /// Validate if a URL is supported
  bool isUrlSupported(String url) {
    final platform = detectPlatform(url);
    return platform != SocialPlatform.unknown;
  }

  /// Get platform display information
  PlatformInfo? getPlatformInfo(String url) {
    final parsedUrl = parseUrl(url);
    if (!parsedUrl.isValid) return null;

    return PlatformInfo(
      platform: parsedUrl.platform,
      urlType: parsedUrl.urlType,
      postId: parsedUrl.postId,
    );
  }
  
  /// Set backend URL for different environments
  void setBackendUrl(String url) {
    BackendApiService.setBaseUrl(url);
    _checkedBackend = false; // Re-check on next request
  }
  
  /// Force re-check backend availability
  void refreshBackendStatus() {
    _checkedBackend = false;
  }
}

/// Platform information container
class PlatformInfo {
  final SocialPlatform platform;
  final UrlType urlType;
  final String? postId;

  const PlatformInfo({
    required this.platform,
    required this.urlType,
    this.postId,
  });

  String get contentTypeLabel {
    switch (urlType) {
      case UrlType.post:
        return 'Post';
      case UrlType.reel:
        return 'Reel';
      case UrlType.story:
        return 'Story';
      case UrlType.igtv:
        return 'IGTV';
      case UrlType.video:
        return 'Video';
      case UrlType.photo:
        return 'Photo';
      case UrlType.tweet:
        return 'Tweet';
      case UrlType.profile:
        return 'Profile';
      case UrlType.unknown:
        return 'Content';
    }
  }
}
