from contextlib import contextmanager
from sqlalchemy.exc import IntegrityError, OperationalError
from sqlalchemy.orm import Session
from app.core.errors import DomainError


class Repository:
    def __init__(self, session: Session):
        self.session = session

    @contextmanager
    def transaction(self):
        try:



            self.session.connection().exec_driver_sql("BEGIN IMMEDIATE")
            yield
            self.session.commit()
        except IntegrityError:
            self.session.rollback()
            raise DomainError(409, "Конфлікт даних. Оновіть список і повторіть дію") from None
        except OperationalError as exc:
            self.session.rollback()
            if "locked" in str(exc.orig).lower():
                raise DomainError(409, "Дані зараз оновлюються. Повторіть дію") from None
            raise
        except BaseException:
            self.session.rollback()
            raise
