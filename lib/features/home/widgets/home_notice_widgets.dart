import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';

class HomeNoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool dense;

  const HomeNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.paddingDefault,
        vertical: dense ? 18 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        border: Border.all(color: color.withValues(alpha: dense ? 0.22 : 0.16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: dense ? 12 : 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: dense ? 44 : 42,
            height: dense ? 44 : 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: dense ? 0.14 : 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusDefault),
            ),
            child: Icon(icon, color: color, size: dense ? 22 : 21),
          ),
          const SizedBox(width: AppSizes.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSizes.paddingSmall),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color.withValues(alpha: 0.85),
              size: 14,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        child: card,
      ),
    );
  }
}
