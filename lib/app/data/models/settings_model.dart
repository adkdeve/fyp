class NotificationSettings {
  final bool criticalAlerts;
  final bool mediumAlerts;

  NotificationSettings({
    required this.criticalAlerts,
    required this.mediumAlerts,
  });

  NotificationSettings copyWith({bool? criticalAlerts, bool? mediumAlerts}) {
    return NotificationSettings(
      criticalAlerts: criticalAlerts ?? this.criticalAlerts,
      mediumAlerts: mediumAlerts ?? this.mediumAlerts,
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      criticalAlerts: (json['critical_alerts'] as bool?) ?? true,
      mediumAlerts: (json['medium_alerts'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'critical_alerts': criticalAlerts,
    'medium_alerts': mediumAlerts,
  };
}
