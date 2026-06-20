import os

class Settings:
    HOST = os.getenv("API_HOST", "0.0.0.0")
    PORT = int(os.getenv("API_PORT", "8001"))

settings = Settings()
