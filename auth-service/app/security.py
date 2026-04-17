"""
Bezpieczeństwo: hashowanie haseł (bcrypt) + wydawanie/weryfikacja JWT.

Dlaczego bcrypt:
- odporny na brute force dzięki adaptacyjnemu cost factor
- standard de facto dla haseł
- w passlib mamy bezpieczny wrapper

Dlaczego JWT HS256:
- stateless — habits-service może zweryfikować token samodzielnie
  bez roundtrippu do auth-service, co zmniejsza coupling i latency
- shared secret jest w zmiennej środowiskowej (env), nie w repo
"""
from datetime import datetime, timedelta, timezone
from uuid import UUID

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    return _pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return _pwd_context.verify(plain, hashed)


def create_access_token(user_id: UUID, email: str) -> tuple[str, int]:
    """Zwraca (token, expires_in_seconds)."""
    expire_delta = timedelta(minutes=settings.jwt_expire_minutes)
    exp = datetime.now(timezone.utc) + expire_delta
    payload = {
        "sub": str(user_id),
        "email": email,
        "exp": exp,
        "iat": datetime.now(timezone.utc),
        "iss": "auth-service",
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, int(expire_delta.total_seconds())


def decode_access_token(token: str) -> dict:
    """Rzuca JWTError jeśli token niepoprawny/expired."""
    return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])


__all__ = [
    "hash_password",
    "verify_password",
    "create_access_token",
    "decode_access_token",
    "JWTError",
]
