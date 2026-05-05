from pydantic import BaseModel, EmailStr


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    phone: str | None = None
    role: str = "supervisor"
    site_id: int | None = None
    is_active: bool = True


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class UserOut(BaseModel):
    id: int
    email: str
    full_name: str
    role: str
    phone: str | None
    avatar_url: str | None
    company: str | None = None
    location: str | None = None
    site_id: int | None = None
    notify_low_alerts: bool = True
    notify_critical_alerts: bool = True
    notify_medium_alerts: bool = True
    is_active: bool

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut | None = None


class UserUpdateRequest(BaseModel):
    full_name: str | None = None
    name: str | None = None
    phone: str | None = None
    company: str | None = None
    location: str | None = None
    avatar_url: str | None = None


class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str


class NotificationSettingsOut(BaseModel):
    low_alerts: bool
    critical_alerts: bool
    medium_alerts: bool


class NotificationSettingsUpdate(BaseModel):
    low_alerts: bool | None = None
    critical_alerts: bool | None = None
    medium_alerts: bool | None = None
