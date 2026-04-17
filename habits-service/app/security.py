"""
Weryfikacja JWT w habits-service.

Strategia: stateless — habits-service zna JWT_SECRET i weryfikuje token
lokalnie (bez roundtrippu do auth-service). To daje:
- niskie latency
- brak single point of failure przy każdym requestcie
- luźne sprzężenie (habits-service działa nawet jak auth-service jest chwilowo down)

Fallback `verify_via_auth_service` jest dostępny gdyby kiedyś trzeba
było sprawdzić blacklistę / rewokację — demonstruje komunikację
serwis ↔ serwis po REST.
"""
from uuid import UUID

import httpx
from jose import JWTError, jwt

from app.config import settings
from app.errors import UnauthorizedError


def decode_token_local(token: str) -> dict:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError as e:
        raise UnauthorizedError("Invalid or expired token", details={"reason": str(e)})


async def verify_via_auth_service(token: str) -> UUID:
    """
    Fallback: zapytaj auth-service przez REST o weryfikację tokenu.
    Używane tylko w razie potrzeby (demonstracja komunikacji serwis-serwis).
    """
    url = f"{settings.auth_service_url}/auth/verify"
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(url, headers={"Authorization": f"Bearer {token}"})
    except httpx.HTTPError as e:
        raise UnauthorizedError(
            "Auth service unreachable",
            details={"upstream_error": str(e)},
        )

    if resp.status_code != 200:
        raise UnauthorizedError(
            "Token verification failed",
            details={"upstream_status": resp.status_code},
        )
    return UUID(resp.json()["user_id"])
