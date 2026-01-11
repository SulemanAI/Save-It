/// Media information model
///
/// This model represents the extracted media information
/// from a social media URL including direct download links.
library;

import '../core/constants.dart';

/// Represents a single media item that can be downloaded
class MediaItem {
  final String url;
  final MediaType type;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final String? quality;

  const MediaItem({
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.fileName,
    this.fileSize,
    this.quality,
  });

  /// Generate a default filename based on type and timestamp
  String get defaultFileName {
    if (fileName != null && fileName!.isNotEmpty) return fileName!;
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _getExtension();
    return 'saveit_${timestamp}$extension';
  }

  String _getExtension() {
    switch (type) {
      case MediaType.video:
      case MediaType.reel:
      case MediaType.story:
        return '.mp4';
      case MediaType.image:
        return '.jpg';
      default:
        // Try to extract from URL
        final uri = Uri.tryParse(url);
        if (uri != null) {
          final path = uri.path.toLowerCase();
          if (path.endsWith('.mp4')) return '.mp4';
          if (path.endsWith('.mov')) return '.mov';
          if (path.endsWith('.webm')) return '.webm';
          if (path.endsWith('.png')) return '.png';
          if (path.endsWith('.webp')) return '.webp';
          if (path.endsWith('.gif')) return '.gif';
        }
        return '.jpg';
    }
  }

  @override
  String toString() {
    return 'MediaItem(url: $url, type: ${type.displayName}, fileName: $defaultFileName)';
  }
}

/// Complete media information extracted from a post
class MediaInfo {
  final SocialPlatform platform;
  final String originalUrl;
  final List<MediaItem> mediaItems;
  final String? postId;
  final String? username;
  final String? caption;
  final String? timestamp;
  final bool isStory;
  final String? errorMessage;

  const MediaInfo({
    required this.platform,
    required this.originalUrl,
    required this.mediaItems,
    this.postId,
    this.username,
    this.caption,
    this.timestamp,
    this.isStory = false,
    this.errorMessage,
  });

  /// Check if extraction was successful
  bool get isSuccess => mediaItems.isNotEmpty && errorMessage == null;

  /// Get the primary media type
  MediaType get primaryMediaType {
    if (mediaItems.isEmpty) return MediaType.unknown;
    if (mediaItems.length > 1) return MediaType.carousel;
    return mediaItems.first.type;
  }

  /// Get total number of media items
  int get mediaCount => mediaItems.length;

  /// Factory for creating an error result
  factory MediaInfo.error({
    required SocialPlatform platform,
    required String originalUrl,
    required String errorMessage,
  }) {
    return MediaInfo(
      platform: platform,
      originalUrl: originalUrl,
      mediaItems: const [],
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() {
    return 'MediaInfo(platform: ${platform.displayName}, mediaCount: $mediaCount, isSuccess: $isSuccess)';
  }
}

/// Download progress information
class DownloadProgress {
  final String fileName;
  final int bytesReceived;
  final int totalBytes;
  final DownloadStatus status;
  final String? errorMessage;

  const DownloadProgress({
    required this.fileName,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.idle,
    this.errorMessage,
  });

  /// Get progress percentage (0.0 to 1.0)
  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (bytesReceived / totalBytes).clamp(0.0, 1.0);
  }

  /// Get formatted progress string
  String get progressText {
    if (totalBytes <= 0) return '0%';
    return '${(progress * 100).toStringAsFixed(0)}%';
  }

  /// Get formatted size string
  String get sizeText {
    if (totalBytes <= 0) return 'Calculating...';
    return '${_formatBytes(bytesReceived)} / ${_formatBytes(totalBytes)}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Create a copy with updated values
  DownloadProgress copyWith({
    String? fileName,
    int? bytesReceived,
    int? totalBytes,
    DownloadStatus? status,
    String? errorMessage,
  }) {
    return DownloadProgress(
      fileName: fileName ?? this.fileName,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'DownloadProgress(fileName: $fileName, progress: $progressText, status: ${status.name})';
  }
}
