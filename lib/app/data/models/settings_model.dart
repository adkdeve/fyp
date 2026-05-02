class NotificationSettings {
  final bool criticalAlerts;
  final bool mediumAlerts;
  final bool lowAlerts;

  NotificationSettings({
    required this.criticalAlerts,
    required this.mediumAlerts,
    required this.lowAlerts,
  });

  NotificationSettings copyWith({
    bool? criticalAlerts,
    bool? mediumAlerts,
    bool? lowAlerts,
  }) {
    return NotificationSettings(
      criticalAlerts: criticalAlerts ?? this.criticalAlerts,
      mediumAlerts: mediumAlerts ?? this.mediumAlerts,
      lowAlerts: lowAlerts ?? this.lowAlerts,
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      criticalAlerts: (json['critical_alerts'] as bool?) ?? true,
      mediumAlerts: (json['medium_alerts'] as bool?) ?? true,
      lowAlerts: (json['low_alerts'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'critical_alerts': criticalAlerts,
    'medium_alerts': mediumAlerts,
    'low_alerts': lowAlerts,
  };
}
