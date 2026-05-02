import 'package:flutter_test/flutter_test.dart';
import 'package:construction_safety/app/data/models/camera_model.dart';
import 'package:construction_safety/app/data/models/user_model.dart';

void main() {
  test('camera model handles supervisor-safe payloads', () {
    final model = CameraModel.fromJson({
      'id': 2,
      'name': 'Note 10',
      'rtsp_url': null,
      'enabled': true,
      'status': 'online',
      'fps_target': 5,
      'site': {'name': 'Main Site', 'address': 'Gate A'},
    });

    expect(model.id, 2);
    expect(model.rtspUrl, '');
    expect(model.zone, 'Gate A');
    expect(model.enabled, isTrue);
  });

  test('user model parses site and low alert preferences', () {
    final model = UserModel.fromJson({
      'id': 7,
      'full_name': 'Safety Lead',
      'email': 'lead@example.com',
      'site_id': 3,
      'notify_critical_alerts': true,
      'notify_medium_alerts': false,
      'notify_low_alerts': true,
    });

    expect(model.siteId, 3);
    expect(model.notifyMediumAlerts, isFalse);
    expect(model.notifyLowAlerts, isTrue);
  });
}
