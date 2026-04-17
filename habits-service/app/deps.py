"""Dependency: wyciągnij user_id z JWT."""
from uuid import UUID

from fastapi import Header

from app.errors import UnauthorizedError
from app.security import decode_token_local


def get_current_user_id(authorization: str | None = Header(default=None)) -> UUID:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise UnauthorizedError("Missing or invalid Authorization header")
    token = authorization.split(" ", 1)[1].strip()
    claims = decode_token_local(token)
    if "sub" not in claims:
        raise UnauthorizedError("Token missing subject")
    try:
        return UUID(claims["sub"])
    except (ValueError, TypeError):
        raise UnauthorizedError("Invalid subject in token")
