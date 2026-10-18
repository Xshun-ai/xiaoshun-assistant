import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../ui/components/app_info_row.dart';

class DebugSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const DebugSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class DebugInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const DebugInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppInfoRow(
      label: label,
      value: value,
      labelWidth: 110,
      dense: true,
      multiline: true,
      valueAlign: TextAlign.left,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
      valueStyle: const TextStyle(
        fontSize: 14,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class DebugPreviewField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final Key? fieldKey;
  final int minLines;
  final int maxLines;

  const DebugPreviewField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.fieldKey,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: fieldKey,
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DebugActionTile extends StatelessWidget {
  final Key? tileKey;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData icon;

  const DebugActionTile({
    super.key,
    this.tileKey,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = Icons.chevron_right_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: tileKey,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: const TextStyle(height: 1.4)),
      ),
      trailing: Icon(icon, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }
}

class DebugBusyIndicator extends StatelessWidget {
  const DebugBusyIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 10),
            Text('处理中...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
