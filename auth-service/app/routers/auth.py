"""Endpointy: /auth/register, /auth/login, /auth/me, /auth/verify."""
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user_claims
from app.errors import ConflictError, NotFoundError, UnauthorizedError
from app.models import User
from app.schemas import (
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UserResponse,
    VerifyResponse,
)
from app.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Rejestracja nowego użytkownika",
)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == payload.email.lower()).first()
    if existing:
        raise ConflictError("Email already registered", details={"field": "email"})

    user = User(
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        display_name=payload.display_name.strip(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Logowanie — zwraca JWT",
)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email.lower()).first()
    # Stała wiadomość — nie ujawniamy czy email istnieje (enumeration)
    if not user or not verify_password(payload.password, user.password_hash):
        raise UnauthorizedError("Invalid email or password")

    token, expires_in = create_access_token(user.id, user.email)
    return TokenResponse(access_token=token, expires_in=expires_in)


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Informacje o aktualnie zalogowanym użytkowniku",
)
def me(claims: dict = Depends(get_current_user_claims), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == UUID(claims["sub"])).first()
    if not user:
        raise NotFoundError("User not found")
    return user


@router.get(
    "/verify",
    response_model=VerifyResponse,
    summary="Weryfikacja tokenu (używane przez inne mikroserwisy)",
)
def verify(claims: dict = Depends(get_current_user_claims)):
    # Sam fakt przejścia przez dependency oznacza valid=True
    return VerifyResponse(user_id=UUID(claims["sub"]), email=claims["email"])
