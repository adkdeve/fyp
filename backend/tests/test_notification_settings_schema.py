from app.schemas.auth import NotificationSettingsOut


def test_notification_settings_out_includes_low_alerts() -> None:
    payload = NotificationSettingsOut(
        critical_alerts=True,
        medium_alerts=False,
        low_alerts=True,
    )

    assert payload.low_alerts is True
