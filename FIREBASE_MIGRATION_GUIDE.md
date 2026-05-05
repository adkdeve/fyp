# Firebase Migration Completion Guide

## Remaining Controllers Migration Pattern

All remaining controllers follow the same pattern. Use this template:

### Before (SafetyApiService):
```dart
final SafetyApiService _api = SafetyApiService.to;

Future<void> loadData() async {
  final result = await _api.getViolations(...);
  // process result
}
```

### After (FirestoreService):
```dart
final FirestoreService _firestore = FirestoreService.to;

Future<void> loadData() async {
  final result = await _firestore.getViolations(...);
  // process result - same data structure!
}
```

---

## Controllers to Migrate

### 1. **AnalyticsController** (/lib/app/modules/main/analytics/controllers/)
**Methods to change:**
- `await _api.getSummary(days: days)` → `await _firestore.getSummary(days)`
- `await _api.getTrend(days: days)` → `await _firestore.getTrend(days)`
- `await _api.getByType(days: days)` → `await _firestore.getByType(days)`
- `await _api.getByCamera(days: days)` → `await _firestore.getByCamera(days)`
- `await _api.exportAnalytics(days)` → `await _firestore.exportAnalytics(days)`

**Import change:**
```dart
import '../../../../data/services/firestore_service.dart'; // CHANGE THIS
```

---

### 2. **ProfileController** (/lib/app/modules/main/profile/controllers/)
**Methods to change:**
- Replace `SafetyApiService` with `FirestoreService`
- `_api.getMe()` → `_firestore.getMe()`
- `_api.updateMe(data)` → `_firestore.updateMe(data)`
- `_api.uploadAvatar(file)` → `_firestore.uploadAvatar(file)`
- `_api.changePassword(...)` → `_firestore.changePassword(...)`

---

### 3. **CameraManagementController** (/lib/app/modules/main/camera_management/controllers/)
**Methods to change:**
- `await _api.getCameras(...)` → `await _firestore.getCameras(...)`
- OR use stream: `_firestore.getCamerasStream(...).listen(...)`
- For updates: handle Firestore updates directly

---

### 4. **CameraFeedController** (/lib/app/modules/main/camera_feed/controllers/)
**Methods to change:**
- `SafetyApiService.to.tryRefreshToken()` → Remove (Firebase Auth handles automatically)
- `SafetyApiService.to.takeSnapshot()` → Implement custom snapshot logic

---

### 5. **SettingsController** (/lib/app/modules/main/settings/controllers/)
**Methods to change:**
- `_api.getNotificationSettings()` → `_firestore.getNotificationSettings()`
- `_api.updateNotificationSettings(data)` → `_firestore.updateNotificationSettings(data)`

---

### 6. **HistoryController** (/lib/app/modules/main/history/controllers/)
**Methods to change:**
- `_api.getViolations(...)` → `_firestore.getViolations(...)`
- Already receives updates from Firestore streams in MainController

---

### 7. **DashboardController** (/lib/app/modules/main/dashboard/controllers/)
**Status:** Likely minimal changes needed - mainly displays data from MainController

---

### 8. **ViolationDetailController** (/lib/app/modules/main/violation_detail/controllers/)
**Methods to change:**
- `_api.resolveViolation(id, status)` → `_firestore.resolveViolation(id, status: status)`

---

## Migration Checklist Template

For each controller:

1. **Find & Replace imports:**
   ```
   Find: import '../../../../data/services/safety_api_service.dart';
   Replace: import '../../../../data/services/firestore_service.dart';
   ```

2. **Find & Replace service declaration:**
   ```
   Find: final SafetyApiService _api = SafetyApiService.to;
   Replace: final FirestoreService _firestore = FirestoreService.to;
   ```

3. **Update method calls:**
   - Replace `_api.` with `_firestore.`
   - Check return types (usually same structure)
   - Remove `.to` suffix if it was `SafetyApiService.to.method()`

4. **For real-time data:**
   ```dart
   // Subscribe to stream
   late StreamSubscription<List<T>> _subscription;
   
   @override
   void onInit() {
     _subscription = _firestore.getViolationsStream().listen((data) {
       violations.assignAll(data);
     });
   }
   
   @override
   void onClose() {
     _subscription.cancel();
     super.onClose();
   }
   ```

5. **Test locally** after each migration

---

## Firestore Method Reference

### Authentication
- `login(email, password)` - Firebase Auth
- `getMe()` - Get current user from Firestore
- `updateMe(data)` - Update user profile
- `changePassword(current, new)` - Firebase Auth
- `deleteAccount()` - Delete account
- `uploadAvatar(file)` - Upload to Firebase Storage

### Violations
- `getViolations({filters...})` - List (one-time fetch)
- `getViolationsStream({filters...})` - Stream (real-time)
- `resolveViolation(id, status, notes)` - Update status

### Cameras
- `getCameras({filters...})` - List
- `getCamerasStream({filters...})` - Stream
- `createCamera(data)` - Create
- `updateCamera(id, data)` - Update

### Alerts
- `getAlerts({filters...})` - List
- `getAlertsStream({filters...})` - Stream
- `markAlertRead(id)` - Mark single
- `markAllAlertsRead()` - Mark all

### Analytics
- `getSummary(days)` - Summary metrics
- `getByType(days)` - By violation type
- `getBySeverity(days)` - By severity level
- `getTrend(days)` - Trend over time
- `getByCamera(days)` - By camera
- `exportAnalytics(days)` - Export data

### Notifications
- `getNotificationSettings()` - Get settings
- `updateNotificationSettings(settings)` - Update

### File Uploads
- `uploadAvatar(file)` - Upload to Firebase Storage

---

## Key Differences from HTTP API

1. **No manual token management** - Firebase Auth handles tokens automatically
2. **No WebSocket/reconnection logic needed** - Firestore streams handle reconnection
3. **No token refresh calls** - Firebase automatically refreshes behind the scenes
4. **Error handling is simpler** - Firestore exceptions are caught and logged
5. **Offline support automatic** - Firestore offline cache works out of the box

---

## Testing After Migration

1. **Login** - Test Firebase Auth login/logout
2. **Real-time updates** - Add a violation in backend, verify it appears in app
3. **Offline mode** - Test app with airplane mode on
4. **Profile updates** - Test avatar upload and profile changes
5. **Settings** - Test notification settings persistence
6. **Analytics** - Verify analytics data loads correctly

---

## Need Help?

If a Firestore method signature differs from SafetyApiService:
1. Check `/lib/app/data/services/firestore_service.dart` for the exact method signature
2. The method names are the same, just different implementations
3. Return types are compatible with existing models

---

## Cleanup (After All Controllers Migrated)

Once all controllers are migrated:

1. **Remove SafetyApiService import** from AppBinding
2. **Delete unused files:**
   - `/lib/app/data/network/` (old HTTP service files)
   - `/lib/app/data/repositories/repository.dart` (if not used elsewhere)
   - `/lib/app/core/values/apis_url.dart` (if not used elsewhere)
3. **Remove WebSocket dependencies** from pubspec.yaml if not used elsewhere
4. **Run `flutter pub get`** to clean up
5. **Run tests** to ensure all migrations are complete

