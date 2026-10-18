import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../ui/components/custom_toast.dart';

void showXgActionLoadingDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const Center(
      child: CircularProgressIndicator(color: AppColors.appleBlue),
    ),
  );
}

void hideXgActionLoadingDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}

void showXgSuccessSnackBar(
  BuildContext context, {
  required String message,
  bool floating = true,
  bool rounded = true,
}) {
  CustomToast.success(context, message: message);
}

void showXgErrorSnackBar(
  BuildContext context, {
  required String message,
  bool floating = true,
  bool rounded = true,
}) {
  CustomToast.error(context, message: message);
}
