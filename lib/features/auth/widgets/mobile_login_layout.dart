import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';

/// 参考 Web 版视觉稿重构的移动端登录布局。
class MobileLoginLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController captchaController;
  final bool isObscure;
  final bool loading;
  final String? captchaImageBase64;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onRefreshCaptcha;
  final VoidCallback onLogin;

  const MobileLoginLayout({
    super.key,
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.captchaController,
    required this.isObscure,
    required this.loading,
    this.captchaImageBase64,
    required this.onToggleObscure,
    required this.onRefreshCaptcha,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final minHeight = mediaQuery.size.height - mediaQuery.padding.vertical;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceSoft, AppColors.lightBlueBackground],
        ),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight - 32),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusHuge + 4,
                      ),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 28),
                        _buildForm(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Image.asset(
          'assets/images/icon_android.png',
          width: 88,
          height: 88,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 18),
        Text(
          '校园助手',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '非官方客户端',
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(context, '学生学号'),
          _buildTextField(
            controller: usernameController,
            hintText: '请输入您的学号',
            prefixIcon: Icons.person_outline_rounded,
            validatorText: '请输入学号',
          ),
          const SizedBox(height: 18),
          _buildLabel(context, '登录密码'),
          _buildTextField(
            controller: passwordController,
            hintText: '请输入您的密码',
            prefixIcon: Icons.lock_outline_rounded,
            validatorText: '请输入密码',
            obscureText: isObscure,
            suffixIcon: IconButton(
              icon: Icon(
                isObscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textHint,
              ),
              onPressed: onToggleObscure,
            ),
          ),
          if (captchaImageBase64 != null) ...[
            const SizedBox(height: 18),
            _buildLabel(context, '图形验证码'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: captchaController,
                    hintText: '不区分大小写',
                    prefixIcon: Icons.verified_user_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: onRefreshCaptcha,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                  child: Container(
                    width: 122,
                    height: 54,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                      border: Border.all(color: AppColors.borderGray),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusLarge - 1,
                        ),
                        child: Image.memory(
                          _decodeBase64Image(captchaImageBase64!),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: loading ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white70,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '安全登录',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    String? validatorText,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validatorText == null
          ? null
          : (value) => (value == null || value.isEmpty) ? validatorText : null,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.textHint),
        prefixIcon: Icon(prefixIcon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
      ),
    );
  }

  Uint8List _decodeBase64Image(String base64Str) {
    final segments = base64Str.split(',');
    final payload = segments.length > 1 ? segments[1] : segments[0];
    return base64.decode(payload);
  }
}
