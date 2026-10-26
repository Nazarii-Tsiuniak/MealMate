"""Запускає тимчасовий FastAPI та наскрізний Flutter API-тест без емулятора."""
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from urllib.error import URLError
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
sys.path.insert(0, str(BACKEND))
from alembic import command
from alembic.config import Config


def main():
    flutter = shutil.which("flutter")
    if not flutter:
        raise SystemExit("Flutter не знайдено у PATH")
    with tempfile.TemporaryDirectory(prefix="mealmate-live-", ignore_cleanup_errors=True) as directory:
        database_url = "sqlite:///" + str(Path(directory) / "test.db")
        config = Config(str(BACKEND / "alembic.ini"))
        config.attributes["database_url"] = database_url
        command.upgrade(config, "head")
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        env = os.environ | {"MEALMATE_DATABASE_URL":database_url,
            "MEALMATE_JWT_SECRET":secrets.token_hex(32), "PYTHONIOENCODING":"utf-8"}
        process = subprocess.Popen([sys.executable,"-m","uvicorn","app.main:create_app","--factory","--host","127.0.0.1","--port",str(port),"--no-access-log"],
            cwd=BACKEND,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0)
        try:
            for _ in range(100):
                if process.poll() is not None:
                    raise RuntimeError("FastAPI не запустився")
                try:
                    with urlopen(f"http://127.0.0.1:{port}/openapi.json",timeout=1):
                        break
                except URLError:
                    time.sleep(0.05)
            else:
                raise RuntimeError("Час запуску FastAPI вичерпано")
            args=[flutter,"test","test/server_live_test.dart",f"--dart-define=MEALMATE_LIVE_API=http://127.0.0.1:{port}","--reporter","expanded"]
            if os.name=="nt":
                args=["cmd.exe","/d","/c",*args]
            return subprocess.call(args,cwd=ROOT,env=env)
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
            time.sleep(0.1)


if __name__ == "__main__":
    raise SystemExit(main())
