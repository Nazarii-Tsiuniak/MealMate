"""Реальні HTTP-запити до окремого процесу Uvicorn і повторний запуск."""
import json
import os
import socket
import subprocess
import sys
import time
from urllib.error import URLError
from urllib.request import Request, urlopen

from tests.conftest import ROOT, migration_config
from alembic import command


def test_http_auth_and_profile_survive_server_restart(settings):
    command.upgrade(migration_config(settings.database_url), "head")
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    env = os.environ | {
        "MEALMATE_JWT_SECRET": settings.jwt_secret.get_secret_value(),
        "MEALMATE_DATABASE_URL": settings.database_url,
    }

    def request(path, method="GET", data=None, token=None):
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = "Bearer " + token
        req = Request(base + path, method=method, headers=headers,
            data=None if data is None else json.dumps(data).encode("utf-8"))
        with urlopen(req, timeout=5) as response:
            return response.status, json.load(response)

    def start():
        process = subprocess.Popen([sys.executable, "-m", "uvicorn", "app.main:create_app", "--factory", "--host", "127.0.0.1", "--port", str(port), "--no-access-log"],
            cwd=ROOT, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        try:
            for _ in range(100):
                if process.poll() is not None:
                    raise AssertionError("Uvicorn завершився до запуску")
                try:
                    request("/openapi.json")
                    return process
                except URLError:
                    time.sleep(0.05)
            raise AssertionError("Uvicorn не запустився вчасно")
        except BaseException:
            stop(process)
            raise

    def stop(process):
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)

    credentials = {"email": "restart@example.com", "password": "Restart-pass-123"}
    process = start()
    try:
        status, user = request("/api/v1/auth/register", "POST", credentials | {"name": "Назар"})
        assert status == 201
        status, result = request("/api/v1/auth/login", "POST", credentials)
        assert status == 200
        token = result["access_token"]
        status, _ = request("/api/v1/users/me", "PATCH", {"daily_calorie_goal": 1900}, token)
        assert status == 200
        status, recipe = request("/api/v1/recipes", "POST", {
            "name": "Омлет", "category": "breakfast", "preparation_minutes": 15,
            "calories": 320, "servings": 2,
            "ingredients": [{"name":"Молоко","quantity":100,"unit":"мл"}],
            "preparation_steps": ["Приготувати"],
        }, token)
        assert status == 201
        status, slot = request("/api/v1/meal-plans", "PUT", {
            "date":"2026-12-28", "meal_type":"breakfast", "recipe_id":recipe["id"], "planned_servings":0.5,
        }, token)
        assert status == 200
        status, items = request("/api/v1/shopping-items?week_start=2026-12-28", token=token)
        assert status == 200 and items[0]["quantity"] == 25
        item_id = items[0]["id"]
        request("/api/v1/shopping-items/"+item_id, "PATCH", {"is_purchased":True}, token)
        status, manual = request("/api/v1/shopping-items", "POST", {
            "week_start":"2026-12-28", "ingredient_name":"Хліб", "quantity":1, "unit":"шт",
        }, token)
        assert status == 201
    finally:
        stop(process)
    process = start()
    try:
        status, persisted = request("/api/v1/users/me", token=token)
        assert status == 200
        assert persisted["id"] == user["id"]
        assert persisted["daily_calorie_goal"] == 1900
        assert request("/api/v1/auth/login", "POST", credentials)[0] == 200
        assert request("/api/v1/recipes/"+recipe["id"], token=token)[1] == recipe
        assert request("/api/v1/meal-plans?start_date=2026-12-28", token=token)[1] == [slot]
        items = request("/api/v1/shopping-items?week_start=2026-12-28", token=token)[1]
        assert len(items) == 2
        assert next(item for item in items if item["id"]==item_id)["is_purchased"]
        assert next(item for item in items if item["id"]==manual["id"])["is_manual"]
        assert request("/api/v1/statistics/daily?date=2026-12-28", token=token)[1]["total_calories"] == 160
        assert request("/api/v1/statistics/weekly?start_date=2026-12-28", token=token)[1]["average_calories"] == 160/7

    finally:
        stop(process)
