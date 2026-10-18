import 'package:flutter/material.dart';

/// 统一错误重试态组件。
class RetryErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String? helperText;
  final String buttonText;
  final VoidCallback onRetry;
  final IconData icon;
  final Color? iconColor;

  const RetryErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = '获取失败',
    this.helperText,
    this.buttonText = '重试',
    this.icon = Icons.cloud_off_rounded,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: iconColor ?? Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            if (helperText != null && helperText!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                helperText!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
