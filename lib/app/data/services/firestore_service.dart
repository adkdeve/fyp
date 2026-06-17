import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'dart:io';
import '../models/violation_model.dart';
import '../models/camera_model.dart';
import '../models/user_model.dart';

class FirestoreService extends GetxService {
  static const String _tag = 'FirestoreService';

  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;
  late final FirebaseStorage _storage;
  final Logger _logger = Logger();
  bool _initialized = false;

  /// GetX singleton accessor
  static FirestoreService get to => Get.find<FirestoreService>();

  /// Initialize Firestore service
  @override
  Future<FirestoreService> onInit() async {
    try {
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      _storage = FirebaseStorage.instance;

      await _firestore.enableNetwork();
      _initialized = true;
      _logger.i('[$_tag] Firestore initialized successfully');
    } catch (e) {
      _logger.w('[$_tag] Firebase initialization error: $e');
      _initialized = false;
    }
    return this;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ─ ERROR HANDLING
  // ──────────────────────────────────────────────────────────────────────────

  dynamic _handle(dynamic response) {
    if (response is FirebaseException) {
      _logger.e('[$_tag] Firebase error: ${response.code} - ${response.message}');
      return {'error': response.message ?? 'Firebase error', 'code': response.code};
    }
    if (response is Exception) {
      _logger.e('[$_tag] Exception: $response');
      return {'error': response.toString()};
    }
    return response;
  }

  // Safe violation parsing wrapper
  ViolationModel? _parseViolationSafely(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      return ViolationModel.fromJson(data);
    } catch (e) {
      _logger.e('[$_tag] Error parsing violation ${doc.id}: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ─ AUTHENTICATION
  // ──────────────────────────────────────────────────────────────────────────

  static List<String>? _parseStringList(dynamic value) {
    if (value is! List) return null;
    return value.where((item) => item != null).map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      // Lookup officer by login ID or email
      var snapshot = await _firestore.collection('officers').where('loginId', isEqualTo: identifier).limit(1).get();
      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore.collection('officers').where('email', isEqualTo: identifier).limit(1).get();
      }

      if (snapshot.docs.isEmpty) {
        return {'error': 'Invalid login ID or password'};
      }

      final userDoc = snapshot.docs.first;
      final userData = userDoc.data();
      final storedPassword = userData['password'] as String?;

      // Verify password
      if (storedPassword == null || storedPassword != password) {
        return {'error': 'Invalid login ID or password'};
      }

      // Verify officer account state and assignments
      final status = (userData['status'] ?? '').toString().toLowerCase();
      final siteIds = _parseStringList(userData['siteIds'] ?? userData['site_ids']);
      if (status != 'active') {
        return {'error': 'Your account has been deactivated. Contact your admin.'};
      }
      if (siteIds == null || siteIds.isEmpty) {
        return {'error': 'You are not assigned to any site. Contact your admin.'};
      }

      final uid = userDoc.id;
      final token = _generateToken(uid);

      final userResponse = {...userData, 'id': uid};
      userResponse.remove('password');
      userResponse['siteIds'] = siteIds;

      return {'user': userResponse, 'uid': uid, 'token': token};
    } catch (e) {
      return _handle(e);
    }
  }

  String _generateToken(String uid) {
    return 'token_${uid}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<Map<String, dynamic>> getOfficerMe(String uid) async {
    try {
      final doc = await _firestore.collection('officers').doc(uid).get();
      if (!doc.exists) {
        return {'error': 'Officer document not found'};
      }
      final userData = doc.data() ?? {};
      userData['id'] = doc.id;
      userData.remove('password'); // Security ke liye password remove kiya
      return userData;
    } catch (e) {
      return _handle(e);
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String firstName, String lastName) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user == null) {
        return {'error': 'User is null after registration'};
      }

      // Create user document in Firestore
      final userData = {
        'id': user.uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'createdAt': FieldValue.serverTimestamp(),
        'notifyCriticalAlerts': true,
        'notifyMediumAlerts': true,
        'notifyLowAlerts': false,
      };

      await _firestore.collection('users').doc(user.uid).set(userData);

      return {'user': userData, 'uid': user.uid};
    } on FirebaseAuthException catch (e) {
      return _handle({'error': e.message ?? 'Registration failed', 'code': e.code});
    } catch (e) {
      return _handle(e);
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'error': 'Not authenticated'};
      }

      final doc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!doc.exists) {
        return {'error': 'User document not found'};
      }

      final userData = doc.data() ?? {};
      userData['id'] = currentUser.uid;
      return UserModel.fromJson(userData).toJson();
    } catch (e) {
      return _handle(e);
    }
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'error': 'Not authenticated'};
      }

      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(currentUser.uid).update(data);

      return {'success': true};
    } catch (e) {
      return _handle(e);
    }
  }

  Future<void> updateOfficerProfile(String officerId, Map<String, dynamic> data) async {
    try {
      // 'officers' collection ke andar targeted officer ka data update karein
      await _firestore.collection('officers').doc(officerId).update(data);
    } catch (e) {
      print("Firestore Update Error: $e");
      throw 'Failed to update profile in database';
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        _logger.w('[$_tag] No current user');
        return false;
      }

      // Re-authenticate with current password
      final credential = EmailAuthProvider.credential(email: currentUser.email!, password: currentPassword);
      await currentUser.reauthenticateWithCredential(credential);

      // Update password
      await currentUser.updatePassword(newPassword);
      return true;
    } catch (e) {
      _logger.e('[$_tag] Change password error: $e');
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      // Delete user document
      await _firestore.collection('users').doc(currentUser.uid).delete();

      // Delete user account
      await currentUser.delete();
      return true;
    } catch (e) {
      _logger.e('[$_tag] Delete account error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ─ CAMERAS
  // ──────────────────────────────────────────────────────────────────────────

  List<List<T>> _chunkList<T>(List<T> items, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize > items.length) ? items.length : i + chunkSize;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

  List<dynamic> _normalizeFirestoreQueryIds(List<String> ids) {
    final normalized = <dynamic>{};
    for (final id in ids) {
      normalized.add(id);
      final parsedInt = int.tryParse(id);
      if (parsedInt != null) normalized.add(parsedInt);
    }
    return normalized.toList();
  }

  Future<List<CameraModel>> getCameras({
    bool? enabledOnly = false,
    bool? enabled,
    String? status,
    String? q,
    List<String>? siteIds,
  }) async {
    try {
      if (siteIds != null && siteIds.isEmpty) {
        return [];
      }
      if (siteIds != null && siteIds.isNotEmpty && siteIds.length > 10) {
        final chunks = _chunkList<String>(siteIds, 10);
        final allResults = await Future.wait(
          chunks.map((chunk) async {
            var query = _firestore.collection('cameras') as Query;
            final siteIdValues = _normalizeFirestoreQueryIds(chunk);
            query = query.where('site_id', whereIn: siteIdValues);
            if (enabled != null) {
              query = query.where('enabled', isEqualTo: enabled);
            }
            if (status != null) {
              query = query.where('status', isEqualTo: status);
            }
            final snapshot = await query.get();
            return snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return CameraModel.fromJson(data);
            }).toList();
          }),
        );
        return allResults.expand((list) => list).toList();
      }

      var query = _firestore.collection('cameras') as Query;

      if (siteIds != null && siteIds.isNotEmpty) {
        query = query.where('site_id', whereIn: _normalizeFirestoreQueryIds(siteIds));
      }
      if (enabled != null) {
        query = query.where('enabled', isEqualTo: enabled);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Include the Firestore document ID
        return CameraModel.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.e('[$_tag] Get cameras error: $e');
      return [];
    }
  }

  Stream<List<CameraModel>> getCamerasStream({bool? enabled, String? status, List<String>? siteIds}) {
    var query = _firestore.collection('cameras') as Query;

    if (siteIds != null && siteIds.isNotEmpty && siteIds.length <= 10) {
      query = query.where('site_id', whereIn: _normalizeFirestoreQueryIds(siteIds));
    }
    if (enabled != null) {
      query = query.where('enabled', isEqualTo: enabled);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (siteIds != null && siteIds.isNotEmpty && siteIds.length > 10) {
                  final rawSiteId = data['site_id'];
                  if (rawSiteId == null || !siteIds.contains(rawSiteId.toString())) {
                    return null;
                  }
                }
                data['id'] = doc.id; // Include the Firestore document ID
                return CameraModel.fromJson(data);
              })
              .whereType<CameraModel>()
              .toList();
        })
        .handleError((e) {
          _logger.e('[$_tag] Get cameras stream error: $e');
          return <CameraModel>[];
        });
  }

  Future<List<String>> getCameraIdsBySiteIds(List<String>? siteIds, {bool enabledOnly = true}) async {
    if (siteIds == null || siteIds.isEmpty) return [];
    final cameras = await getCameras(enabled: enabledOnly ? true : null, siteIds: siteIds);
    return cameras.map((camera) => camera.id?.toString() ?? '').where((id) => id.isNotEmpty).toList();
  }

  Future<CameraModel?> createCamera(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _firestore.collection('cameras').add(data);
      final doc = await ref.get();
      return CameraModel.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      _logger.e('[$_tag] Create camera error: $e');
      return null;
    }
  }

  Future<bool> updateCamera(String id, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('cameras').doc(id).update(data);
      return true;
    } catch (e) {
      _logger.e('[$_tag] Update camera error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ─ VIOLATIONS
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<ViolationModel>> getViolations({
    String? q,
    String? status,
    String? severity,
    String? type,
    String? cameraId,
    List<String>? cameraIds,
    bool enabledOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      if (cameraIds != null && cameraIds.isNotEmpty && cameraIds.length > 10) {
        final chunks = _chunkList<String>(cameraIds, 10);
        final allResults = await Future.wait(
          chunks.map((chunk) async {
            var query = _firestore.collection('violations') as Query;
            final cameraIdValues = _normalizeFirestoreQueryIds(chunk);
            query = query.where('camera_id', whereIn: cameraIdValues);
            if (severity != null) {
              query = query.where('severity', isEqualTo: severity);
            }
            if (status != null) {
              query = query.where('status', isEqualTo: status);
            }
            if (type != null) {
              query = query.where('type', isEqualTo: type);
            }
            query = query.orderBy('detected_at', descending: true).limit(limit);
            final snapshot = await query.get();
            final violations = <ViolationModel>[];
            for (final doc in snapshot.docs) {
              final violation = _parseViolationSafely(doc);
              if (violation != null) {
                violations.add(violation);
              }
            }
            return violations;
          }),
        );
        final merged = allResults.expand((list) => list).toList();
        merged.sort((a, b) => b.time.compareTo(a.time));
        return merged.take(limit).toList();
      }

      var query = _firestore.collection('violations') as Query;

      if (cameraId != null) {
        query = query.where('camera_id', isEqualTo: cameraId);
      }
      if (cameraIds != null && cameraIds.isNotEmpty) {
        query = query.where('camera_id', whereIn: _normalizeFirestoreQueryIds(cameraIds));
      }
      if (severity != null) {
        query = query.where('severity', isEqualTo: severity);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      query = query.orderBy('detected_at', descending: true).limit(limit);

      final snapshot = await query.get();
      final violations = <ViolationModel>[];

      for (final doc in snapshot.docs) {
        final violation = _parseViolationSafely(doc);
        if (violation != null) {
          violations.add(violation);
        }
      }

      return violations;
    } catch (e) {
      _logger.e('[$_tag] Get violations error: $e');
      return [];
    }
  }

  Stream<List<ViolationModel>> getViolationsStream({
    String? cameraId,
    List<String>? cameraIds,
    String? severity,
    String? status,
    String? type,
    int limit = 50,
  }) {
    var query = _firestore.collection('violations') as Query;

    if (cameraId != null) {
      query = query.where('camera_id', isEqualTo: cameraId);
    }
    if (cameraIds != null && cameraIds.isNotEmpty && cameraIds.length <= 10) {
      query = query.where('camera_id', whereIn: _normalizeFirestoreQueryIds(cameraIds));
    }
    if (severity != null) {
      query = query.where('severity', isEqualTo: severity);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    query = query.orderBy('detected_at', descending: true).limit(limit);

    return query
        .snapshots()
        .map((snapshot) {
          final violations = <ViolationModel>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              if (cameraIds != null && cameraIds.isNotEmpty && cameraIds.length > 10) {
                final rawCameraId = data['camera_id'];
                if (rawCameraId == null || !cameraIds.contains(rawCameraId.toString())) {
                  continue;
                }
              }
              final violation = ViolationModel.fromJson(data);
              violations.add(violation);
            } catch (e) {
              _logger.e('[$_tag] Error parsing violation in stream: $e');
              // Skip this violation instead of crashing the stream
            }
          }
          return violations;
        })
        .handleError((e) {
          _logger.e('[$_tag] Get violations stream error: $e');
          return <ViolationModel>[];
        });
  }

  Future<bool> resolveViolation(String id, {required String status, String? notes}) async {
    try {
      final data = {'status': status, 'updatedAt': FieldValue.serverTimestamp()};
      if (notes != null) {
        data['notes'] = notes;
      }
      await _firestore.collection('violations').doc(id).update(data);
      return true;
    } catch (e) {
      _logger.e('[$_tag] Resolve violation error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ─ ALERTS
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAlerts({bool? unreadOnly, String? severity, int limit = 50}) async {
    try {
      var query = _firestore.collection('alerts') as Query;

      if (unreadOnly == true) {
        query = query.where('unread', isEqualTo: true);
      }
      if (severity != null) {
        query = query.where('severity', isEqualTo: severity);
      }

      query = query.orderBy('created_at', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      _logger.e('[$_tag] Get alerts error: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getAlertsStream({bool? unreadOnly, String? severity, int limit = 50}) {
    var query = _firestore.collection('alerts') as Query;

    if (unreadOnly == true) {
      query = query.where('unread', isEqualTo: true);
    }
    if (severity != null) {
      query = query.where('severity', isEqualTo: severity);
    }

    query = query.orderBy('created_at', descending: true).limit(limit);

    return query
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        })
        .handleError((e) {
          _logger.e('[$_tag] Get alerts stream error: $e');
          return <Map<String, dynamic>>[];
        });
  }

  Future<bool> markAlertRead(String id) async {
    try {
      await _firestore.collection('alerts').doc(id).update({'unread': false});
      return true;
    } catch (e) {
      _logger.e('[$_tag] Mark alert read error: $e');
      return false;
    }
  }

  Future<bool> markAllAlertsRead() async {
    try {
      final snapshot = await _firestore.collection('alerts').where('unread', isEqualTo: true).get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({'unread': false});
      }
      return true;
    } catch (e) {
      _logger.e('[$_tag] Mark all alerts read error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ─ ANALYTICS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSummary(int days) async {
    try {
      final doc = await _firestore.collection('analytics').doc('summary').get();
      return doc.data() ?? {'violations': 0, 'alerts': 0, 'cameras': 0};
    } catch (e) {
      _logger.e('[$_tag] Get summary error: $e');
      return {'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getByType(int days) async {
    try {
      final snapshot = await _firestore.collection('analytics').doc('by_type').collection('data').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _logger.e('[$_tag] Get by type error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBySeverity(int days) async {
    try {
      final snapshot = await _firestore.collection('analytics').doc('by_severity').collection('data').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _logger.e('[$_tag] Get by severity error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTrend(int days) async {
    try {
      final snapshot = await _firestore.collection('analytics').doc('trend').collection('data').orderBy('date').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _logger.e('[$_tag] Get trend error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getByCamera(int days) async {
    try {
      final snapshot = await _firestore.collection('analytics').doc('by_camera').collection('data').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _logger.e('[$_tag] Get by camera error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ─ NOTIFICATION SETTINGS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'error': 'Not authenticated'};
      }

      final doc = await _firestore.collection('notification_settings').doc(currentUser.uid).get();

      return doc.data() ?? {'notifyCriticalAlerts': true, 'notifyMediumAlerts': true, 'notifyLowAlerts': false};
    } catch (e) {
      _logger.e('[$_tag] Get notification settings error: $e');
      return {'error': e.toString()};
    }
  }

  Future<bool> updateNotificationSettings(Map<String, dynamic> settings) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      await _firestore.collection('notification_settings').doc(currentUser.uid).set(settings, SetOptions(merge: true));
      return true;
    } catch (e) {
      _logger.e('[$_tag] Update notification settings error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ─ FILE UPLOADS (Firebase Storage)
  // ──────────────────────────────────────────────────────────────────────────

  Future<String?> uploadAvatar(File file) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return null;
      }

      final ref = _storage.ref().child('avatars/${currentUser.uid}');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update user document with avatar URL
      await _firestore.collection('users').doc(currentUser.uid).update({
        'image': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      _logger.e('[$_tag] Upload avatar error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ─ UTILITY
  // ──────────────────────────────────────────────────────────────────────────

  Future<bool> exportViolations(Map<String, dynamic> filters) async {
    try {
      // Export violations as CSV or JSON
      var query = _firestore.collection('violations') as Query;

      if (filters['cameraId'] != null) {
        query = query.where('camera_id', isEqualTo: filters['cameraId']);
      }

      final snapshot = await query.get();
      _logger.i('[$_tag] Exported ${snapshot.docs.length} violations');
      return true;
    } catch (e) {
      _logger.e('[$_tag] Export violations error: $e');
      return false;
    }
  }

  Future<bool> exportAnalytics(int days) async {
    try {
      final snapshot = await _firestore.collection('analytics').doc('summary').get();
      _logger.i('[$_tag] Exported analytics');
      return true;
    } catch (e) {
      _logger.e('[$_tag] Export analytics error: $e');
      return false;
    }
  }
}
