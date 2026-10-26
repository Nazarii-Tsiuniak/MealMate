import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import make_url

from app.core.config import BACKEND_ROOT
from app.database.models import Base
from app.database.session import create_database

config = context.config
if config.config_file_name:
    fileConfig(config.config_file_name)

# Міграції не потребують JWT-секрету. Пріоритет: URL тесту, середовище, .env, ini.
from dotenv import dotenv_values
url = config.attributes.get("database_url") or os.getenv("MEALMATE_DATABASE_URL") or dotenv_values(BACKEND_ROOT / ".env").get("MEALMATE_DATABASE_URL") or config.get_main_option("sqlalchemy.url")
target_metadata = Base.metadata

if context.is_offline_mode():
    parsed = make_url(url)
    if parsed.database and parsed.database != ":memory:":
        from pathlib import Path
        path = Path(parsed.database)
        if not path.is_absolute():
            parsed = parsed.set(database=str(BACKEND_ROOT / path))
    context.configure(url=parsed, target_metadata=target_metadata, literal_binds=True, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()
else:
    engine, _ = create_database(url)
    try:
        with engine.connect() as connection:
            context.configure(connection=connection, target_metadata=target_metadata, compare_type=True, render_as_batch=True)
            with context.begin_transaction():
                context.run_migrations()
    finally:
        engine.dispose()
