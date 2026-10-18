import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/portal_announcement.dart';
import 'campus_access_service.dart';
import 'home_data_cache_codec.dart';
import 'portal_announcement_service.dart';
import 'session_store.dart';
import 'token_refresh_service.dart';

class HomeDataPortalLoader {
  final SessionStore store;
  final PortalAnnouncementService portalService;
  final TokenRefreshService tokenRefresh;
  final bool Function(Object error) shouldRetryWithTokenRefresh;

  const HomeDataPortalLoader({
    required this.store,
    required this.portalService,
    required this.tokenRefresh,
    required this.shouldRetryWithTokenRefresh,
  });

  Future<List<PortalAnnouncement>?> loadPortalAnnouncementsCached() async {
    final jsonStr = await store.getPortalAnnouncements();
    if (jsonStr == null || jsonStr.isEmpty) {
      debugPrint('[公告] 无本地缓存数据');
      return null;
    }

    final parsed = parsePortalAnnouncementsCache(jsonStr);
    if (parsed != null) {
      debugPrint('[公告] 成功读取本地缓存: ${parsed.length} 条');
      return parsed;
    } else {
      debugPrint('[公告] 缓存加载失败');
      return null;
    }
  }

  Future<List<PortalAnnouncement>> loadPortalAnnouncementsFresh() async {
    try {
      return await _loadPortalAnnouncementsFromNetworkInternal();
    } catch (e) {
      final cached = await loadPortalAnnouncementsCached();
      if (cached != null &&
          CampusAccessService.isCampusNetworkUnavailableError(e)) {
        return cached;
      }
      if (CampusAccessService.isCampusNetworkUnavailableError(e)) {
        throw CampusServiceUnavailableException('融合门户公告', cause: e);
      }
      rethrow;
    }
  }

  Future<List<PortalAnnouncement>>
  _loadPortalAnnouncementsFromNetworkInternal() async {
    try {
      debugPrint('[公告] 开始网络请求...');
      await portalService.init();
      final announcements = await portalService.fetchAnnouncements();

      if (announcements.isNotEmpty) {
        final top4 = announcements.take(4).toList();
        final jsonStr = jsonEncode(top4.map((e) => e.toJson()).toList());
        await store.savePortalAnnouncements(jsonStr);
        debugPrint('[公告] 网络数据获取成功并写入缓存: ${top4.length} 条');
      }

      return announcements.take(4).toList();
    } catch (e) {
      debugPrint('[公告] 网络请求失败: $e');
      rethrow;
    }
  }
}
