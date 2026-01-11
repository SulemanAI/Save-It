/// Platform Badge Widget
/// 
/// A badge showing the detected platform with icon and gradient background.

import 'package:flutter/material.dart';
import '../core/constants.dart';

class PlatformBadge extends StatelessWidget {
  final SocialPlatform platform;
  final bool showLabel;
  final double size;

  const PlatformBadge({
    super.key,
    required this.platform,
    this.showLabel = true,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 14 : 8,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        gradient: platform.gradient,
        borderRadius: BorderRadius.circular(showLabel ? 30 : 12),
        boxShadow: [
          BoxShadow(
            color: platform.primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            platform.icon,
            color: Colors.white,
            size: size * 0.5,
          ),
          if (showLabel) ...[
            const SizedBox(width: 8),
            Text(
              platform.displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Media type indicator chip
class MediaTypeChip extends StatelessWidget {
  final MediaType mediaType;
  final int? count;

  const MediaTypeChip({
    super.key,
    required this.mediaType,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            mediaType.icon,
            color: AppColors.textPrimary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            count != null && count! > 1
                ? '${mediaType.displayName} ($count)'
                : mediaType.displayName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Info row showing detected content details
class ContentInfoRow extends StatelessWidget {
  final SocialPlatform platform;
  final MediaType mediaType;
  final int mediaCount;
  final String? username;

  const ContentInfoRow({
    super.key,
    required this.platform,
    required this.mediaType,
    this.mediaCount = 1,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PlatformBadge(platform: platform, size: 36),
              const Spacer(),
              MediaTypeChip(
                mediaType: mediaType,
                count: mediaCount > 1 ? mediaCount : null,
              ),
            ],
          ),
          if (username != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '@$username',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
