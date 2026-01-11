/// Download Button Widget
/// 
/// A premium animated download button with progress indicator
/// and state transitions.

import 'package:flutter/material.dart';
import '../core/constants.dart';

class DownloadButton extends StatefulWidget {
  final DownloadStatus status;
  final double progress;
  final VoidCallback? onPressed;
  final String? customLabel;

  const DownloadButton({
    super.key,
    required this.status,
    this.progress = 0.0,
    this.onPressed,
    this.customLabel,
  });

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.status.isLoading;
    final isCompleted = widget.status == DownloadStatus.completed;
    final isFailed = widget.status == DownloadStatus.failed;
    final isIdle = widget.status == DownloadStatus.idle;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isIdle ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Stack(
          children: [
            // Background progress bar (when downloading)
            if (isLoading && widget.status == DownloadStatus.downloading)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LinearProgressIndicator(
                    value: widget.progress,
                    backgroundColor: AppColors.darkCard,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            
            // Main button
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : widget.onPressed,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _getButtonGradient(),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _getButtonColor().withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildButtonContent(isLoading, isCompleted, isFailed),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getButtonGradient() {
    if (widget.status == DownloadStatus.completed) {
      return const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (widget.status == DownloadStatus.failed) {
      return const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (widget.status.isLoading) {
      return LinearGradient(
        colors: [
          AppColors.accent.withValues(alpha: 0.8),
          AppColors.accentAlt.withValues(alpha: 0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [AppColors.accent, AppColors.accentAlt],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _getButtonColor() {
    if (widget.status == DownloadStatus.completed) {
      return AppColors.success;
    }
    if (widget.status == DownloadStatus.failed) {
      return AppColors.error;
    }
    return AppColors.accent;
  }

  Widget _buildButtonContent(bool isLoading, bool isCompleted, bool isFailed) {
    if (isLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              value: widget.status == DownloadStatus.downloading && widget.progress > 0
                  ? widget.progress
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.status == DownloadStatus.downloading && widget.progress > 0
                ? '${(widget.progress * 100).toStringAsFixed(0)}%'
                : widget.status.message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    IconData icon;
    String label;

    if (isCompleted) {
      icon = Icons.check_circle_rounded;
      label = widget.customLabel ?? 'Downloaded!';
    } else if (isFailed) {
      icon = Icons.refresh_rounded;
      label = widget.customLabel ?? 'Try Again';
    } else {
      icon = Icons.download_rounded;
      label = widget.customLabel ?? 'Download';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Smaller download button for media items in a list
class CompactDownloadButton extends StatelessWidget {
  final DownloadStatus status;
  final double progress;
  final VoidCallback? onPressed;
  final String? label;

  const CompactDownloadButton({
    super.key,
    required this.status,
    this.progress = 0.0,
    this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = status.isLoading;
    final isCompleted = status == DownloadStatus.completed;

    return SizedBox(
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCompleted
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [AppColors.accent, AppColors.accentAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        value: status == DownloadStatus.downloading && progress > 0
                            ? progress
                            : null,
                      ),
                    )
                  else
                    Icon(
                      isCompleted ? Icons.check_rounded : Icons.download_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  if (label != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
