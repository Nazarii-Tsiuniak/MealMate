from sqlalchemy.exc import IntegrityError

from app.core.errors import DomainError
from app.core.security import Security
from app.database.models import User
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserRead, UserUpdate


class UserService:
    def __init__(self, users: UserRepository, security: Security):
        self.users = users
        self.security = security

    def authenticate(self, token: str) -> User:
        user_id = self.security.token_subject(token)
        user = self.users.by_id(user_id)
        if user is None:
            raise DomainError(401, "Користувач токена більше недоступний")
        return user

    def profile(self, user: User) -> UserRead:
        return UserRead.model_validate(user)

    def update_profile(self, user: User, data: UserUpdate) -> UserRead:
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            raise DomainError(400, "Вкажіть хоча б одне поле для оновлення")
        if "email" in changes:
            other = self.users.by_email(str(changes["email"]))
            if other is not None and other.id != user.id:
                raise DomainError(409, "Ця електронна пошта вже зареєстрована")
        try:
            self.users.update(user, changes)
            self.users.commit()
        except IntegrityError:
            self.users.rollback()
            raise DomainError(409, "Ця електронна пошта вже зареєстрована") from None
        return UserRead.model_validate(user)
