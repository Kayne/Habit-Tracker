"""Konfiguracja habits-service — sekrety wyłącznie z env."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # DB
    postgres_user: str
    postgres_password: str
    postgres_db: str
    postgres_host: str = "postgres"
    postgres_port: int = 5432
    habits_db_schema: str = "habits_schema"

    # JWT (ten sam sekret co w auth-service — stateless verification)
    jwt_secret: str
    jwt_algorithm: str = "HS256"

    # URL auth-service (fallback weryfikacji tokenu przez HTTP)
    auth_service_url: str = "http://auth-service:8001"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )


settings = Settings()
