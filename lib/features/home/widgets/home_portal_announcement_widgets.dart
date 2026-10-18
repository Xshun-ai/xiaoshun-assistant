import 'package:flutter/material.dart';

import '../../../models/portal_announcement.dart';
import '../../../ui/states/skeleton_loading.dart';
import 'portal_announcement_item.dart';

class HomePortalAnnouncementsSkeletonList extends StatelessWidget {
  const HomePortalAnnouncementsSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        AnnouncementSkeletonItem(),
        SizedBox(height: 12),
        AnnouncementSkeletonItem(),
        SizedBox(height: 12),
        AnnouncementSkeletonItem(),
      ],
    );
  }
}

class HomePortalAnnouncementsListContent extends StatelessWidget {
  final List<PortalAnnouncement> announcements;
  final ValueChanged<PortalAnnouncement> onTap;

  const HomePortalAnnouncementsListContent({
    super.key,
    required this.announcements,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(announcements.length, (index) {
        final announcement = announcements[index];
        final isLast = index == announcements.length - 1;
        return Column(
          children: [
            PortalAnnouncementItem(
              announcement: announcement,
              onTap: () => onTap(announcement),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ],
        );
      }),
    );
  }
}
