from sqlalchemy.exc import IntegrityError

from app.core.errors import DomainError
from app.core.security import Security
from app.repositories.user_repository import UserRepository
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse
from app.schemas.user import UserRead


class AuthService:
    def __init__(self, users: UserRepository, security: Security):
        self.users = users
        self.security = security

    def register(self, data: RegisterRequest) -> UserRead:
        if self.users.by_email(str(data.email)):
            raise DomainError(409, "Ця електронна пошта вже зареєстрована")
        hashed = self.security.hash_password(data.password.get_secret_value())
        try:
            user = self.users.add(name=data.name, email=str(data.email), password_hash=hashed)
            self.users.commit()
        except IntegrityError:
            self.users.rollback()
            raise DomainError(409, "Ця електронна пошта вже зареєстрована") from None
        return UserRead.model_validate(user)

    def login(self, data: LoginRequest) -> TokenResponse:
        user = self.users.by_email(str(data.email))
        valid = self.security.verify_password(data.password.get_secret_value(), user.password_hash if user else None)
        if not valid or user is None:
            raise DomainError(401, "Неправильна електронна пошта або пароль")
        return TokenResponse(access_token=self.security.create_token(user.id),
            expires_in=self.security.settings.access_token_minutes * 60)
