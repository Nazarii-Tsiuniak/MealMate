from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database.models import User


class UserRepository:
    def __init__(self, session: Session):
        self.session = session

    def by_email(self, email: str) -> User | None:
        return self.session.scalar(select(User).where(User.email == email))

    def by_id(self, user_id: str) -> User | None:
        return self.session.get(User, user_id)

    def add(self, *, name: str, email: str, password_hash: str) -> User:
        user = User(name=name, email=email, password_hash=password_hash)
        self.session.add(user)
        self.session.flush()
        return user

    def update(self, user: User, changes: dict) -> User:
        for field, value in changes.items():
            setattr(user, field, value)
        self.session.flush()
        return user

    def commit(self) -> None:
        self.session.commit()

    def rollback(self) -> None:
        self.session.rollback()
