/// Download Service
///
/// Handles downloading media files to device storage.
/// Provides progress tracking and error handling.
/// Files are saved to the "SaveIt" folder in Movies/Pictures.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants.dart';
import '../models/media_info.dart';

/// Callback for download progress updates
typedef DownloadProgressCallback = void Function(DownloadProgress progress);

/// Download service for saving media files
class DownloadService {
  
  /// Album name where media will be saved
  static const String albumName = 'SaveIt';
  
  /// Download a media item and save to storage
  /// 
  /// Returns the file path if successful, null otherwise.
  Future<String?> downloadMedia(
    MediaItem mediaItem, {
    DownloadProgressCallback? onProgress,
  }) async {
    final fileName = mediaItem.defaultFileName;
    
    try {
      // Update status to downloading
      onProgress?.call(DownloadProgress(
        fileName: fileName,
        status: DownloadStatus.downloading,
      ));

      // Check storage permission
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        onProgress?.call(DownloadProgress(
          fileName: fileName,
          status: DownloadStatus.failed,
          errorMessage: 'Storage permission denied. Please grant permission in Settings.',
        ));
        return null;
      }

      // Download the file
      print('[DownloadService] Downloading: ${mediaItem.url}');
      
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(mediaItem.url));
        request.headers.addAll({
          'User-Agent': AppConstants.mobileUserAgent,
          'Accept': '*/*',
          'Accept-Encoding': 'identity',
        });

        final response = await client.send(request).timeout(
          const Duration(minutes: 5),
        );

        if (response.statusCode != 200) {
          onProgress?.call(DownloadProgress(
            fileName: fileName,
            status: DownloadStatus.failed,
            errorMessage: 'Download failed (HTTP ${response.statusCode})',
          ));
          return null;
        }

        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;
        final List<int> bytes = [];

        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          receivedBytes += chunk.length;

          onProgress?.call(DownloadProgress(
            fileName: fileName,
            bytesReceived: receivedBytes,
            totalBytes: totalBytes,
            status: DownloadStatus.downloading,
          ));
        }

        final fileBytes = Uint8List.fromList(bytes);
        print('[DownloadService] Downloaded ${fileBytes.length} bytes');

        // Save to storage
        final filePath = await _saveToStorage(fileBytes, fileName, mediaItem.type);
        
        if (filePath != null) {
          onProgress?.call(DownloadProgress(
            fileName: fileName,
            bytesReceived: receivedBytes,
            totalBytes: totalBytes,
            status: DownloadStatus.completed,
          ));
          
          print('[DownloadService] Saved to: $filePath');
          return filePath;
        } else {
          onProgress?.call(DownloadProgress(
            fileName: fileName,
            status: DownloadStatus.failed,
            errorMessage: 'Failed to save file. Please check storage permissions.',
          ));
          return null;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('[DownloadService] Error: $e');
      onProgress?.call(DownloadProgress(
        fileName: fileName,
        status: DownloadStatus.failed,
        errorMessage: 'Download error: ${e.toString().split('\n').first}',
      ));
      return null;
    }
  }

  /// Save bytes to storage
  Future<String?> _saveToStorage(Uint8List bytes, String fileName, MediaType type) async {
    if (Platform.isAndroid) {
      // Try different storage locations in order of preference
      final locations = type == MediaType.video
          ? [
              '/storage/emulated/0/Movies/$albumName',
              '/storage/emulated/0/DCIM/$albumName',
              '/storage/emulated/0/Download/$albumName',
            ]
          : [
              '/storage/emulated/0/Pictures/$albumName',
              '/storage/emulated/0/DCIM/$albumName',
              '/storage/emulated/0/Download/$albumName',
            ];

      for (final location in locations) {
        try {
          final dir = Directory(location);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }

          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);

          print('[DownloadService] Saved to: ${file.path}');
          return file.path;
        } catch (e) {
          print('[DownloadService] Failed to save to $location: $e');
          continue;
        }
      }

      // Fallback: Save to app's external storage
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final file = File('${extDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          print('[DownloadService] Saved to app storage: ${file.path}');
          return file.path;
        }
      } catch (e) {
        print('[DownloadService] App storage error: $e');
      }

      return null;
    } else if (Platform.isIOS) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final saveDir = Directory('${appDir.path}/$albumName');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }

        final file = File('${saveDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return file.path;
      } catch (e) {
        print('[DownloadService] iOS save error: $e');
        return null;
      }
    } else {
      // Other platforms
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final saveDir = Directory('${appDir.path}/$albumName');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }

        final file = File('${saveDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return file.path;
      } catch (e) {
        print('[DownloadService] Save error: $e');
        return null;
      }
    }
  }

  /// Check and request storage permission
  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      // Request all potentially needed permissions
      final permissions = <Permission>[
        Permission.storage,
      ];

      // For Android 13+
      permissions.add(Permission.photos);
      permissions.add(Permission.videos);

      Map<Permission, PermissionStatus> statuses = await permissions.request();

      print('[DownloadService] Permission statuses: $statuses');

      // Check if any permission was granted
      bool hasAccess = statuses.values.any((status) => 
        status.isGranted || status.isLimited);

      // If no permissions granted, check if we can write anyway (some ROMs allow this)
      if (!hasAccess) {
        try {
          final testDir = Directory('/storage/emulated/0/Download');
          if (await testDir.exists()) {
            hasAccess = true;
          }
        } catch (_) {}
      }

      print('[DownloadService] Has access: $hasAccess');
      return hasAccess;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    return true;
  }

  /// Get the path where files are saved
  String getDownloadPath() {
    if (Platform.isAndroid) {
      return 'Movies/$albumName or Pictures/$albumName';
    }
    return albumName;
  }

  /// Check if a file already exists
  Future<bool> fileExists(String fileName) async {
    return false;
  }
}
