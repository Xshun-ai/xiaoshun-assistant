import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../models/xg_activity.dart';
import 'xg_role_option.dart';

Future<String?> showXgActivityApplyDialog({
  required BuildContext context,
  required XgActivity activity,
  String initialRole = '0',
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _XgActivityApplyDialog(
        activity: activity,
        initialRole: initialRole,
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      return Transform.scale(
        scale: Curves.easeOutBack.transform(animation.value),
        child: child,
      );
    },
  );
}

class _XgActivityApplyDialog extends StatefulWidget {
  final XgActivity activity;
  final String initialRole;

  const _XgActivityApplyDialog({
    required this.activity,
    required this.initialRole,
  });

  @override
  State<_XgActivityApplyDialog> createState() => _XgActivityApplyDialogState();
}

class _XgActivityApplyDialogState extends State<_XgActivityApplyDialog> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_ind_rounded,
                    color: AppColors.appleBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '确认报名',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.activity.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.activity.timeDescription,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '选择报名身份',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            XgRoleOption(
              title: '参与者',
              subtitle: '作为普通参与人员加入',
              value: '0',
              groupValue: _selectedRole,
              icon: Icons.person_rounded,
              onChanged: _updateRole,
            ),
            const SizedBox(height: 10),
            XgRoleOption(
              title: '组织者',
              subtitle: '负责活动组织与协调',
              value: '1',
              groupValue: _selectedRole,
              icon: Icons.manage_accounts_rounded,
              onChanged: _updateRole,
            ),
            const SizedBox(height: 10),
            XgRoleOption(
              title: '观众',
              subtitle: '旁听或观看活动',
              value: '4',
              groupValue: _selectedRole,
              icon: Icons.groups_rounded,
              onChanged: _updateRole,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedRole),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppColors.appleBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('确定报名'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateRole(String value) {
    setState(() {
      _selectedRole = value;
    });
  }
}
