class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? loginId;
  final String? role;
  final String? country;
  final List<String>? industries;
  final String? status;
  final String? dob;
  final String? gender;
  final String? phoneNumber;
  final String? image;
  final String? company;
  final String? location;
  final int? siteId;
  final bool notifyCriticalAlerts;
  final bool notifyMediumAlerts;
  final bool notifyLowAlerts;
  final List<String>? siteIds;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.loginId,
    this.role,
    this.country,
    this.industries,
    this.status,
    this.dob,
    this.gender,
    this.phoneNumber,
    this.image,
    this.company,
    this.location,
    this.siteId,
    this.siteIds,
    this.notifyCriticalAlerts = true,
    this.notifyMediumAlerts = true,
    this.notifyLowAlerts = true,
  });

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value is! List) return null;
    return value.where((item) => item != null).map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    if (value is num) return value != 0;
    return defaultValue;
  }

  /// Full name convenience getter
  String get name => '$firstName $lastName'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawName = _parseString(json['full_name'] ?? json['name'] ?? json['name']);
    final parts = rawName?.split(' ') ?? <String>[];
    final first = _parseString(json['first_name'] ?? json['firstName']) ?? (parts.isNotEmpty ? parts.first : '');
    final last =
        _parseString(json['last_name'] ?? json['lastName']) ?? (parts.length > 1 ? parts.sublist(1).join(' ') : '');
    final rawSiteId = json['site_id'] ?? json['siteId'];

    return UserModel(
      id: _parseString(json['id']) ?? '',
      firstName: first,
      lastName: last,
      email: _parseString(json['email']) ?? '',
      loginId: _parseString(json['loginId'] ?? json['login_id']),
      role: _parseString(json['role']),
      country: _parseString(json['country']),
      industries: _parseStringList(json['industries']),
      status: _parseString(json['status']),
      dob: _parseString(json['dob']),
      gender: _parseString(json['gender']),
      phoneNumber: _parseString(json['phone_number'] ?? json['phone']),
      image: _parseString(json['avatar_url'] ?? json['image']),
      company: _parseString(json['company']),
      location: _parseString(json['location']),
      siteId: rawSiteId is int ? rawSiteId : int.tryParse('$rawSiteId'),
      siteIds: _parseStringList(json['siteIds'] ?? json['site_ids']),
      notifyCriticalAlerts: _parseBool(json['notify_critical_alerts'], defaultValue: true),
      notifyMediumAlerts: _parseBool(json['notify_medium_alerts'], defaultValue: true),
      notifyLowAlerts: _parseBool(json['notify_low_alerts'], defaultValue: true),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'full_name': name,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'loginId': loginId,
    'login_id': loginId,
    'role': role,
    'country': country,
    'industries': industries,
    'status': status,
    'dob': dob,
    'gender': gender,
    'phone_number': phoneNumber,
    'phone': phoneNumber,
    'image': image,
    'avatar_url': image,
    'company': company,
    'location': location,
    'site_id': siteId,
    'siteIds': siteIds,
    'site_ids': siteIds,
    'notify_critical_alerts': notifyCriticalAlerts,
    'notify_medium_alerts': notifyMediumAlerts,
    'notify_low_alerts': notifyLowAlerts,
  };
}
