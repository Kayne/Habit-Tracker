"""Pydantic — walidacja wejścia i strukturę odpowiedzi."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(
        min_length=8,
        max_length=128,
        description="Min. 8 znaków, max 128 (ograniczenie bcrypta).",
    )
    display_name: str = Field(min_length=1, max_length=100)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserResponse(BaseModel):
    id: UUID
    email: EmailStr
    display_name: str
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int  # sekundy


class VerifyResponse(BaseModel):
    """Używane przez inne mikroserwisy do weryfikacji tokenu przez HTTP."""
    user_id: UUID
    email: EmailStr
    valid: bool = True
