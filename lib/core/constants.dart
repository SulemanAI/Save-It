/// Core constants for the SaveIt application
///
/// This file contains all app-wide constants including
/// platform identifiers, colors, and configuration values.
library;

import 'package:flutter/material.dart';

/// Supported social media platforms
enum SocialPlatform {
  instagram,
  facebook,
  twitter, // X (formerly Twitter)
  unknown,
}

/// Extension to provide display names and icons for platforms
extension SocialPlatformExtension on SocialPlatform {
  String get displayName {
    switch (this) {
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.twitter:
        return 'X (Twitter)';
      case SocialPlatform.unknown:
        return 'Unknown';
    }
  }

  IconData get icon {
    switch (this) {
      case SocialPlatform.instagram:
        return Icons.camera_alt_rounded;
      case SocialPlatform.facebook:
        return Icons.facebook_rounded;
      case SocialPlatform.twitter:
        return Icons.alternate_email_rounded;
      case SocialPlatform.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color get primaryColor {
    switch (this) {
      case SocialPlatform.instagram:
        return const Color(0xFFE4405F); // Instagram pink/gradient start
      case SocialPlatform.facebook:
        return const Color(0xFF1877F2); // Facebook blue
      case SocialPlatform.twitter:
        return const Color(0xFF000000); // X black
      case SocialPlatform.unknown:
        return const Color(0xFF6B7280); // Neutral gray
    }
  }

  LinearGradient get gradient {
    switch (this) {
      case SocialPlatform.instagram:
        return const LinearGradient(
          colors: [
            Color(0xFFFEDA77), // Yellow
            Color(0xFFF58529), // Orange
            Color(0xFFDD2A7B), // Pink
            Color(0xFF8134AF), // Purple
            Color(0xFF515BD4), // Blue
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        );
      case SocialPlatform.facebook:
        return const LinearGradient(
          colors: [
            Color(0xFF0866FF),
            Color(0xFF1877F2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SocialPlatform.twitter:
        return const LinearGradient(
          colors: [
            Color(0xFF14171A),
            Color(0xFF000000),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SocialPlatform.unknown:
        return const LinearGradient(
          colors: [
            Color(0xFF6B7280),
            Color(0xFF4B5563),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}

/// Media types that can be downloaded
enum MediaType {
  video,
  image,
  story,
  reel,
  carousel,
  unknown,
}

extension MediaTypeExtension on MediaType {
  String get displayName {
    switch (this) {
      case MediaType.video:
        return 'Video';
      case MediaType.image:
        return 'Image';
      case MediaType.story:
        return 'Story';
      case MediaType.reel:
        return 'Reel';
      case MediaType.carousel:
        return 'Carousel';
      case MediaType.unknown:
        return 'Media';
    }
  }

  IconData get icon {
    switch (this) {
      case MediaType.video:
        return Icons.videocam_rounded;
      case MediaType.image:
        return Icons.image_rounded;
      case MediaType.story:
        return Icons.auto_stories_rounded;
      case MediaType.reel:
        return Icons.movie_rounded;
      case MediaType.carousel:
        return Icons.view_carousel_rounded;
      case MediaType.unknown:
        return Icons.attachment_rounded;
    }
  }
}

/// App theme colors
class AppColors {
  // Primary gradient colors
  static const Color primaryStart = Color(0xFF667EEA);
  static const Color primaryEnd = Color(0xFF764BA2);
  
  // Dark theme colors
  static const Color darkBg = Color(0xFF0F0F23);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16213E);
  static const Color darkCardAlt = Color(0xFF1F2937);
  
  // Accent colors
  static const Color accent = Color(0xFF00D9FF);
  static const Color accentAlt = Color(0xFF7C3AED);
  
  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB4B4C4);
  static const Color textMuted = Color(0xFF6B7280);
  
  // Glassmorphism
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryStart, primaryEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkBg, darkSurface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00D9FF), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// App-wide constants
class AppConstants {
  // App info
  static const String appName = 'Save It';
  static const String appTagline = 'Download & Save Your Favorite Content';
  
  // Ad Unit IDs (Test IDs for development)
  // IMPORTANT: Replace with production IDs before release
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String nativeAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  
  // HTTP settings - reduced timeout for faster failure on blocked requests
  static const Duration httpTimeout = Duration(seconds: 10);
  static const Duration shortTimeout = Duration(seconds: 5);
  static const int maxRetries = 2;
  
  // User agents for different platforms
  static const String mobileUserAgent = 
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1';
  static const String desktopUserAgent = 
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  
  // Download settings
  static const String downloadFolder = 'SaveIt';
  static const int maxConcurrentDownloads = 3;
}

/// Download status states
enum DownloadStatus {
  idle,
  detecting,
  fetching,
  downloading,
  completed,
  failed,
}

extension DownloadStatusExtension on DownloadStatus {
  String get message {
    switch (this) {
      case DownloadStatus.idle:
        return 'Ready to download';
      case DownloadStatus.detecting:
        return 'Detecting platform...';
      case DownloadStatus.fetching:
        return 'Fetching media info...';
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.completed:
        return 'Download complete!';
      case DownloadStatus.failed:
        return 'Download failed';
    }
  }

  bool get isLoading {
    return this == DownloadStatus.detecting ||
        this == DownloadStatus.fetching ||
        this == DownloadStatus.downloading;
  }
}
