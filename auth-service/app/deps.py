"""Dependencies — np. wyciąganie usera z JWT."""
from fastapi import Depends, Header

from app.errors import UnauthorizedError
from app.security import JWTError, decode_access_token


def get_current_user_claims(authorization: str | None = Header(default=None)) -> dict:
    """
    Wyciąga i waliduje JWT z nagłówka `Authorization: Bearer <token>`.
    Zwraca claims (sub=user_id, email, ...).
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise UnauthorizedError("Missing or invalid Authorization header")

    token = authorization.split(" ", 1)[1].strip()
    try:
        claims = decode_access_token(token)
    except JWTError as e:
        raise UnauthorizedError("Invalid or expired token", details={"reason": str(e)})

    if "sub" not in claims:
        raise UnauthorizedError("Token missing subject")
    return claims
