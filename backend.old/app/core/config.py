from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
        protected_namespaces=("settings_",),  # silence model_path warning
    )

    database_url: str
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 14
    cors_origins: str = "http://localhost:3000"
    media_dir: str = "./media"
    model_path: str = "./model.pt"
    detector: str = "yolo"
    fps_target: int = 5
    confidence_threshold: float = 0.35

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
