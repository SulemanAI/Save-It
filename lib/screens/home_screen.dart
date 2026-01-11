/// Home Screen
///
/// Main screen of the SaveIt app where users paste URLs and download media.
/// Features a modern dark theme with glassmorphism effects.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../core/constants.dart';
import '../models/media_info.dart';
import '../services/media_service.dart';
import '../services/download_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/url_input.dart';
import '../widgets/download_button.dart';
import '../widgets/platform_badge.dart';
import '../widgets/native_ad_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final MediaService _mediaService = MediaService();
  final DownloadService _downloadService = DownloadService();
  
  MediaInfo? _mediaInfo;
  DownloadProgress _downloadProgress = const DownloadProgress(fileName: '');
  String? _errorMessage;
  String? _downloadedFilePath;
  
  late AnimationController _backgroundAnimController;
  late Animation<Color?> _bgColorAnimation1;
  late Animation<Color?> _bgColorAnimation2;

  @override
  void initState() {
    super.initState();
    _initBackgroundAnimation();
    _checkClipboard();
  }

  void _initBackgroundAnimation() {
    _backgroundAnimController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _bgColorAnimation1 = ColorTween(
      begin: const Color(0xFF1a1a2e),
      end: const Color(0xFF16213e),
    ).animate(CurvedAnimation(
      parent: _backgroundAnimController,
      curve: Curves.easeInOut,
    ));

    _bgColorAnimation2 = ColorTween(
      begin: const Color(0xFF0f0f23),
      end: const Color(0xFF1a1a3e),
    ).animate(CurvedAnimation(
      parent: _backgroundAnimController,
      curve: Curves.easeInOut,
    ));

    _backgroundAnimController.repeat(reverse: true);
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && _mediaService.isUrlSupported(data!.text!)) {
        // Show a subtle dialog to ask if user wants to use the URL
        if (mounted) {
          _showClipboardDialog(data.text!);
        }
      }
    } catch (_) {}
  }

  void _showClipboardDialog(String url) {
    final platform = _mediaService.detectPlatform(url);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: platform.primaryColor.withValues(alpha: 0.5),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: platform.gradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                platform.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Link Detected',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found a ${platform.displayName} link in your clipboard:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                url.length > 60 ? '${url.substring(0, 60)}...' : url,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Dismiss',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _urlController.text = url;
              _handleUrlSubmit(url);
            },
            child: Text(
              'Download',
              style: TextStyle(color: platform.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _backgroundAnimController.dispose();
    super.dispose();
  }

  void _handleUrlChange(String url) {
    if (_errorMessage != null || _mediaInfo != null) {
      setState(() {
        _errorMessage = null;
        _mediaInfo = null;
        _downloadedFilePath = null;
        _downloadProgress = const DownloadProgress(fileName: '');
      });
    }
  }

  Future<void> _handleUrlSubmit(String url) async {
    if (url.isEmpty) return;

    setState(() {
      _errorMessage = null;
      _mediaInfo = null;
      _downloadedFilePath = null;
      _downloadProgress = DownloadProgress(
        fileName: '',
        status: DownloadStatus.detecting,
      );
    });

    try {
      // Update to fetching state
      setState(() {
        _downloadProgress = _downloadProgress.copyWith(
          status: DownloadStatus.fetching,
        );
      });

      // Extract media info
      final mediaInfo = await _mediaService.extractMedia(url);

      if (!mediaInfo.isSuccess) {
        setState(() {
          _errorMessage = mediaInfo.errorMessage ?? 'Could not extract media';
          _downloadProgress = _downloadProgress.copyWith(
            status: DownloadStatus.failed,
          );
        });
        _showError(_errorMessage!);
        return;
      }

      setState(() {
        _mediaInfo = mediaInfo;
      });

      // Auto-start download for the first media item
      if (mediaInfo.mediaItems.isNotEmpty) {
        await _downloadMedia(mediaInfo.mediaItems.first);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _downloadProgress = _downloadProgress.copyWith(
          status: DownloadStatus.failed,
        );
      });
      _showError('An error occurred. Please try again.');
    }
  }

  Future<void> _downloadMedia(MediaItem mediaItem) async {
    setState(() {
      _downloadProgress = DownloadProgress(
        fileName: mediaItem.defaultFileName,
        status: DownloadStatus.downloading,
      );
    });

    final filePath = await _downloadService.downloadMedia(
      mediaItem,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
    );

    if (filePath != null) {
      setState(() {
        _downloadedFilePath = filePath;
        _downloadProgress = _downloadProgress.copyWith(
          status: DownloadStatus.completed,
        );
      });
      _showSuccess('Download complete!');
    } else {
      _showError(_downloadProgress.errorMessage ?? 'Download failed');
    }
  }

  void _showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppColors.error,
      textColor: Colors.white,
    );
  }

  void _showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppColors.success,
      textColor: Colors.white,
    );
  }

  void _clearAll() {
    setState(() {
      _urlController.clear();
      _mediaInfo = null;
      _errorMessage = null;
      _downloadedFilePath = null;
      _downloadProgress = const DownloadProgress(fileName: '');
    });
  }

  Future<void> _shareFile() async {
    if (_downloadedFilePath != null) {
      await Share.shareXFiles([XFile(_downloadedFilePath!)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: AnimatedBuilder(
        animation: _backgroundAnimController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _bgColorAnimation1.value ?? AppColors.darkBg,
                  _bgColorAnimation2.value ?? AppColors.darkSurface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: statusBarHeight > 0 ? 10 : 20),
                
                // Header
                _buildHeader(),
                
                const SizedBox(height: 30),
                
                // URL Input
                _buildUrlInputSection(),
                
                const SizedBox(height: 24),
                
                // Content info (when media is detected)
                if (_mediaInfo != null) _buildMediaInfo(),
                
                // Download button
                if (_urlController.text.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  DownloadButton(
                    status: _downloadProgress.status,
                    progress: _downloadProgress.progress,
                    onPressed: () {
                      if (_downloadProgress.status == DownloadStatus.completed) {
                        _clearAll();
                      } else if (_downloadProgress.status == DownloadStatus.failed) {
                        _handleUrlSubmit(_urlController.text);
                      } else if (_mediaInfo != null && _mediaInfo!.mediaItems.isNotEmpty) {
                        _downloadMedia(_mediaInfo!.mediaItems.first);
                      } else {
                        _handleUrlSubmit(_urlController.text);
                      }
                    },
                    customLabel: _downloadProgress.status == DownloadStatus.completed
                        ? 'Download Another'
                        : null,
                  ),
                ],
                
                // Action buttons after download
                if (_downloadedFilePath != null) ...[
                  const SizedBox(height: 16),
                  _buildPostDownloadActions(),
                ],
                
                const SizedBox(height: 32),
                
                // Native Ad
                const NativeAdWidget(
                  height: 280,
                  margin: EdgeInsets.only(bottom: 24),
                ),
                
                // Instructions
                _buildInstructions(),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // App logo
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8134AF).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/logo/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // App title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Download Media Instantly',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Platform icons
        _buildPlatformIcons(),
      ],
    );
  }

  Widget _buildPlatformIcons() {
    return Row(
      children: [
        _platformMiniIcon(SocialPlatform.instagram),
        const SizedBox(width: 8),
        _platformMiniIcon(SocialPlatform.facebook),
        const SizedBox(width: 8),
        _platformMiniIcon(SocialPlatform.twitter),
      ],
    );
  }

  Widget _platformMiniIcon(SocialPlatform platform) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: platform.gradient,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: platform.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        platform.icon,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildUrlInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paste URL',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        UrlInput(
          controller: _urlController,
          onChanged: _handleUrlChange,
          onSubmitted: _handleUrlSubmit,
          enabled: !_downloadProgress.status.isLoading,
          errorText: _errorMessage,
        ),
      ],
    );
  }

  Widget _buildMediaInfo() {
    final info = _mediaInfo!;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: ContentInfoRow(
        platform: info.platform,
        mediaType: info.primaryMediaType,
        mediaCount: info.mediaCount,
        username: info.username,
      ),
    );
  }

  Widget _buildPostDownloadActions() {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            onTap: _shareFile,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.share_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Share',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            onTap: () async {
              final path = await _downloadService.getDownloadPath();
              if (path != null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Saved to: $path'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.darkCard,
                    ),
                  );
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Location',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.warning,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'How to Use',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _instructionStep(1, 'Copy the URL from Instagram, Facebook, or X'),
          _instructionStep(2, 'Paste the link in the field above'),
          _instructionStep(3, 'Tap Download and wait for completion'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Only public content can be downloaded. Private posts are not accessible.',
                    style: TextStyle(
                      color: AppColors.warning.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
