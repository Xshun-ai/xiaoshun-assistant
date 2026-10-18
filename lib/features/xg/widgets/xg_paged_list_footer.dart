import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';

class XgPagedListFooter extends StatelessWidget {
  final String? message;
  final String? errorText;
  final VoidCallback? onRetry;
  final bool isLoading;
  final double spacerHeight;
  final EdgeInsetsGeometry padding;

  const XgPagedListFooter.loading({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 20),
    this.spacerHeight = 20,
  }) : message = null,
       errorText = null,
       onRetry = null,
       isLoading = true;

  const XgPagedListFooter.message({
    super.key,
    required this.message,
    this.padding = const EdgeInsets.symmetric(vertical: 20),
    this.spacerHeight = 20,
  }) : errorText = null,
       onRetry = null,
       isLoading = false;

  const XgPagedListFooter.error({
    super.key,
    required this.errorText,
    required this.onRetry,
    this.padding = const EdgeInsets.symmetric(vertical: 20),
    this.spacerHeight = 20,
  }) : message = null,
       isLoading = false;

  const XgPagedListFooter.spacer({
    super.key,
    this.spacerHeight = 20,
    this.padding = EdgeInsets.zero,
  }) : message = null,
       errorText = null,
       onRetry = null,
       isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: padding,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.appleBlue,
            ),
          ),
        ),
      );
    }

    if (errorText != null) {
      return Padding(
        padding: padding,
        child: Center(
          child: Column(
            children: [
              Text(
                errorText!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
              TextButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    if (message != null) {
      return Padding(
        padding: padding,
        child: Center(
          child: Text(
            message!,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SizedBox(height: spacerHeight);
  }
}
