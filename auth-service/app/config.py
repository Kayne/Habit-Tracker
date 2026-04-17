"""
Konfiguracja auth-service.

Wszystkie sekrety i parametry czytamy ze zmiennych środowiskowych.
NIC nie jest hardkodowane w kodzie. Jedynie wartości domyślne dla devu
(ale i tak JWT_SECRET wymaga ustawienia ręcznie — patrz .env.example).
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # DB
    postgres_user: str
    postgres_password: str
    postgres_db: str
    postgres_host: str = "postgres"
    postgres_port: int = 5432
    auth_db_schema: str = "auth_schema"

    # JWT
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )


settings = Settings()
