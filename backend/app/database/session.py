from pathlib import Path

from sqlalchemy import create_engine, event
from sqlalchemy.engine import make_url
from sqlalchemy.orm import sessionmaker

from app.core.config import BACKEND_ROOT


def create_database(url: str):
    parsed = make_url(url)
    if parsed.drivername != "sqlite":
        raise ValueError("Підтримується SQLite")
    if parsed.database and parsed.database != ":memory:":
        path = Path(parsed.database)
        if not path.is_absolute():
            path = BACKEND_ROOT / path
        path.parent.mkdir(parents=True, exist_ok=True)
        parsed = parsed.set(database=str(path.resolve()))
    engine = create_engine(parsed, connect_args={"check_same_thread": False, "timeout": 10})

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(connection, record):
        cursor = connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    return engine, sessionmaker(bind=engine, expire_on_commit=False)
