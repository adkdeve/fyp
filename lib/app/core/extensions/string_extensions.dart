extension StringExtensions on String {
  bool get isEmailAddress =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);

  bool get isPhone => RegExp(r'^\+?[0-9]{7,15}$').hasMatch(this);

  String capitalize() => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';

  // Password validation methods
  bool get hasMinLength => length >= 8;
  bool get hasUppercase => contains(RegExp(r'[A-Z]'));
  bool get hasLowercase => contains(RegExp(r'[a-z]'));
  bool get hasNumber => contains(RegExp(r'[0-9]'));
  bool get hasSpecialCharacter => contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  bool get isValidPassword =>
      hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialCharacter;

}
