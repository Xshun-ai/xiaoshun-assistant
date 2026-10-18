import 'package:campus_assistant/constants/api_urls.dart';
import 'package:campus_assistant/services/campus_access_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CampusAccessService.isCampusServiceUrl', () {
    test('accepts school hosts', () {
      expect(
        CampusAccessService.isCampusServiceUrl('${ApiUrls.ssoBaseUrl}/api/x'),
        isTrue,
      );
      expect(
        CampusAccessService.isCampusServiceUrl('${ApiUrls.jwWebUrl}/jsxsd/x'),
        isTrue,
      );
      expect(
        CampusAccessService.isCampusServiceUrl('${ApiUrls.xgBaseUrl}/xsfw/x'),
        isTrue,
      );
      expect(
        CampusAccessService.isCampusServiceUrl('${ApiUrls.eipBaseUrl}/EIP/x'),
        isTrue,
      );
    });

    test('rejects external, relative and empty urls', () {
      expect(
        CampusAccessService.isCampusServiceUrl('https://example.com/x'),
        isFalse,
      );
      expect(CampusAccessService.isCampusServiceUrl('/api/x'), isFalse);
      expect(CampusAccessService.isCampusServiceUrl(''), isFalse);
    });
  });

  group('user-facing error messages', () {
    test('strips Exception prefixes', () {
      expect(
        CampusAccessService.extractReadableMessage(Exception('请求失败')),
        '请求失败',
      );
    });

    test('maps campus service unavailable errors', () {
      expect(
        CampusAccessService.toUserFacingErrorMessage(
          const CampusServiceUnavailableException('智慧学工'),
        ),
        '校园网服务暂不可用，请稍后重试',
      );
    });

    test('keeps readable business messages', () {
      expect(
        CampusAccessService.toUserFacingErrorMessage(Exception('活动已满员')),
        '活动已满员',
      );
    });
  });
}
