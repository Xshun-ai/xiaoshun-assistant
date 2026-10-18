import 'dart:convert';

import '../models/portal_announcement.dart';

Map<String, dynamic>? parseScheduleCache(String raw) {
  try {
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return null;
  }
}

List<PortalAnnouncement>? parsePortalAnnouncementsCache(String raw) {
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => PortalAnnouncement.fromJson(e)).take(4).toList();
  } catch (_) {
    return null;
  }
}
