class UserModel {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? role;
  final String? country;
  final List<String>? industries;
  final int? status;
  final String? dob;
  final String? gender;
  final String? phoneNumber;
  final String? image;
  final String? company;
  final String? location;
  final bool notifyCriticalAlerts;
  final bool notifyMediumAlerts;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
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
    this.notifyCriticalAlerts = true,
    this.notifyMediumAlerts = true,
  });

  /// Full name convenience getter
  String get name => '$firstName $lastName'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Our backend sends 'name' as a single field; split it for compat.
    final rawName = (json['full_name'] ?? json['name']) as String? ?? '';
    final parts = rawName.split(' ');
    final first =
        json['first_name'] as String? ?? (parts.isNotEmpty ? parts.first : '');
    final last =
        json['last_name'] as String? ??
        (parts.length > 1 ? parts.sublist(1).join(' ') : '');

    return UserModel(
      id: (json['id'] as int?) ?? 0,
      firstName: first,
      lastName: last,
      email: json['email'] as String? ?? '',
      role: json['role'] as String?,
      country: json['country']?.toString(),
      industries: json['industries'] != null
          ? List<String>.from(json['industries'] as List)
          : null,
      status: json['status'] as int?,
      dob: json['dob']?.toString(),
      gender: json['gender']?.toString(),
      phoneNumber: (json['phone_number'] ?? json['phone'])?.toString(),
      image: (json['avatar_url'] ?? json['image'])?.toString(),
      company: json['company']?.toString(),
      location: json['location']?.toString(),
      notifyCriticalAlerts: (json['notify_critical_alerts'] as bool?) ?? true,
      notifyMediumAlerts: (json['notify_medium_alerts'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'full_name': name,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
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
    'notify_critical_alerts': notifyCriticalAlerts,
    'notify_medium_alerts': notifyMediumAlerts,
  };
}
