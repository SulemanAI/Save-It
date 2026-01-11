/// Base Platform Service
/// 
/// Abstract class defining the interface for platform-specific
/// media extraction services. Each platform (Instagram, Facebook, X)
/// implements this interface.

import '../../core/constants.dart';
import '../../models/media_info.dart';
import '../../utils/url_parser.dart';

/// Abstract base class for platform services
abstract class BasePlatformService {
  /// The platform this service handles
  SocialPlatform get platform;

  /// Extract media information from a parsed URL
  /// 
  /// IMPORTANT: This method attempts to extract direct media URLs
  /// from public content only. Login-protected content will fail.
  /// 
  /// Returns [MediaInfo] with extracted media items or error message.
  Future<MediaInfo> extractMedia(ParsedUrl parsedUrl);

  /// Check if this service can handle the given URL
  bool canHandle(ParsedUrl parsedUrl) {
    return parsedUrl.platform == platform && parsedUrl.isValid;
  }

  /// Generate default headers for HTTP requests
  Map<String, String> get defaultHeaders => {
    'User-Agent': AppConstants.mobileUserAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Cache-Control': 'max-age=0',
  };
}
