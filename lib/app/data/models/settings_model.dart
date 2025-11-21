class NotificationSettings {
  final bool criticalAlerts;
  final bool mediumAlerts;
  final bool dailySummary;

  NotificationSettings({
    required this.criticalAlerts,
    required this.mediumAlerts,
    required this.dailySummary,
  });

  NotificationSettings copyWith({
    bool? criticalAlerts,
    bool? mediumAlerts,
    bool? dailySummary,
  }) {
    return NotificationSettings(
      criticalAlerts: criticalAlerts ?? this.criticalAlerts,
      mediumAlerts: mediumAlerts ?? this.mediumAlerts,
      dailySummary: dailySummary ?? this.dailySummary,
    );
  }
}