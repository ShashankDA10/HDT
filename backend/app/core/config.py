from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    LLM_PROVIDER: str = "groq"
    FIREBASE_SERVICE_ACCOUNT_PATH: str = "./firebase-service-account.json"
    DEV_UID: str = ""


settings = Settings()
