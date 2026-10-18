import 'package:campus_assistant/features/campus_map/campus_map_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('campus map asset loads without bundled marker data', (
    tester,
  ) async {
    final service = CampusMapService();
    service.clearCache();
    await service.init();

    expect(await service.getCategories(), isNotEmpty);
    expect(await service.getAllMarkers(), isEmpty);
  });
}
