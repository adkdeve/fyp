extension DateTimeExtensions on DateTime {
  String toShortDate() => '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';

  bool isSameDate(DateTime other) =>
      day == other.day && month == other.month && year == other.year;
}
