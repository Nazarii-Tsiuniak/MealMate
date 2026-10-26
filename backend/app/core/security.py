from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import jwt
from pwdlib import PasswordHash

from app.core.config import Settings
from app.core.errors import DomainError


class Security:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.password_hash = PasswordHash.recommended()
        # Порівнюємо хеш також для невідомого email, без раннього виходу.
        self._dummy_hash = self.hash_password(uuid4().hex)

    def hash_password(self, password: str) -> str:
        return self.password_hash.hash(password)

    def verify_password(self, password: str, stored_hash: str | None) -> bool:
        valid = self.password_hash.verify(password, stored_hash or self._dummy_hash)
        return valid and stored_hash is not None

    def create_token(self, user_id: str) -> str:
        now = datetime.now(timezone.utc)
        return jwt.encode({
            "sub": user_id, "iat": now, "exp": now + timedelta(minutes=self.settings.access_token_minutes),
            "iss": self.settings.jwt_issuer, "aud": self.settings.jwt_audience,
            "jti": str(uuid4()),
        }, self.settings.jwt_secret.get_secret_value(), algorithm="HS256")

    def token_subject(self, token: str) -> str:
        try:
            payload = jwt.decode(token, self.settings.jwt_secret.get_secret_value(),
                algorithms=["HS256"], issuer=self.settings.jwt_issuer,
                audience=self.settings.jwt_audience,
                options={"require": ["sub", "iat", "exp", "iss", "aud", "jti"]})
            return str(UUID(payload["sub"]))
        except (jwt.InvalidTokenError, ValueError, TypeError, AttributeError):
            raise DomainError(401, "Токен недійсний або термін його дії минув") from None
