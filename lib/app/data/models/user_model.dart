class UserModel {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? country;
  final List<String>? industries;
  final int? status;
  final String? dob;
  final String? gender;
  final String? phoneNumber;
  final String? image;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.country,
    this.industries,
    this.status,
    this.dob,
    this.gender,
    this.phoneNumber,
    this.image,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    firstName: json['first_name'],
    lastName: json['last_name'],
    email: json['email'],
    country: json['country']?.toString(),
    industries: json['industries'] != null
        ? List<String>.from(json['industries'])
        : null,
    status: json['status'],
    dob: json['dob']?.toString(),
    gender: json['gender']?.toString(),
    phoneNumber: json['phone_number']?.toString(),
    image: json['image']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'country': country,
    'industries': industries,
    'status': status,
    'dob': dob,
    'gender': gender,
    'phone_number': phoneNumber,
    'image': image,
  };
}

