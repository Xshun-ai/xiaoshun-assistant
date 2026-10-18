import 'package:flutter/material.dart';

import '../../../models/portal_announcement.dart';

/// 融合门户公告列表项组件 - 显示单条公告的摘要信息
class PortalAnnouncementItem extends StatelessWidget {
  final PortalAnnouncement announcement;
  final VoidCallback onTap;

  const PortalAnnouncementItem({
    super.key,
    required this.announcement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              announcement.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
                height: 1.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          announcement.publishDate.split(' ')[0],
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          announcement.department,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
