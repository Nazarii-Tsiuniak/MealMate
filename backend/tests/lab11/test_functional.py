from tests.conftest import auth, register
from tests.lab11.conftest import DAY, EMAIL, PASSWORD, recipe_payload, record


def test_TC_001_correct_credentials(client, lab_user, record_property):
    response = client.post("/api/v1/auth/login", json={"email": EMAIL, "password": PASSWORD})
    record(record_property, "TC-001", f"Login HTTP {response.status_code}")
    assert response.status_code == 200
    token = response.json()["access_token"]
    assert token and response.json()["token_type"] == "bearer"
    profile = client.get("/api/v1/users/me", headers={"Authorization": "Bearer " + token})
    assert profile.status_code == 200 and profile.json()["id"] == lab_user["id"]
    assert "password" not in profile.text
    record_property("profile_http", profile.status_code)


def test_TC_002_create_recipe(client, lab_headers, record_property):
    payload = recipe_payload()
    response = client.post("/api/v1/recipes", headers=lab_headers, json=payload)
    record(record_property, "TC-002", f"POST HTTP {response.status_code}")
    assert response.status_code == 201
    data = response.json()
    details = client.get("/api/v1/recipes/" + data["id"], headers=lab_headers)
    assert details.status_code == 200
    assert details.json() == data
    assert data["name"] == payload["name"] and data["servings"] == 2
    assert len(data["ingredients"]) == 3 and data["preparation_steps"] == payload["preparation_steps"]
    record_property("ingredients", len(data["ingredients"]))


def test_TC_003_assign_meal(client, lab_headers, lab_recipe, record_property):
    response = client.put("/api/v1/meal-plans", headers=lab_headers, json={
        "date": DAY, "meal_type": "breakfast", "recipe_id": lab_recipe["id"], "planned_servings": 1,
    })
    record(record_property, "TC-003", f"PUT HTTP {response.status_code}")
    assert response.status_code == 200
    result = client.get("/api/v1/meal-plans", headers=lab_headers, params={"start_date": DAY, "end_date": DAY})
    assert result.status_code == 200 and len(result.json()) == 1
    assert result.json()[0]["recipe_id"] == lab_recipe["id"]
    assert result.json()[0]["date"] == DAY and result.json()[0]["meal_type"] == "breakfast"
    record_property("slots", len(result.json()))


def test_TC_004_portions_recalculate_calories(client, lab_headers, lab_recipe, record_property):
    body = {"date": DAY, "meal_type": "breakfast", "recipe_id": lab_recipe["id"]}
    first = client.put("/api/v1/meal-plans", headers=lab_headers, json=body | {"planned_servings": 0.5})
    assert first.status_code == 200
    half = client.get("/api/v1/statistics/daily", headers=lab_headers, params={"date": DAY}).json()
    second = client.put("/api/v1/meal-plans", headers=lab_headers, json=body | {"planned_servings": 2})
    assert second.status_code == 200
    double = client.get("/api/v1/statistics/daily", headers=lab_headers, params={"date": DAY}).json()
    record(record_property, "TC-004", f"0.5 порції: {half['total_calories']} ккал; 2 порції: {double['total_calories']} ккал")
    assert half["total_calories"] == 160 and double["total_calories"] == 640
    assert half["meals"]["breakfast"] == 160 and double["meals"]["breakfast"] == 640
    assert first.json()["id"] == second.json()["id"]
    rows = client.get("/api/v1/meal-plans", headers=lab_headers, params={"start_date": DAY, "end_date": DAY}).json()
    assert len(rows) == 1


def test_TC_005_automatic_shopping(client, lab_headers, lab_recipe, record_property):
    for meal, portions in [("breakfast", 1), ("lunch", 0.5)]:
        response = client.put("/api/v1/meal-plans", headers=lab_headers, json={
            "date": DAY, "meal_type": meal, "recipe_id": lab_recipe["id"], "planned_servings": portions,
        })
        assert response.status_code == 200
    response = client.get("/api/v1/shopping-items", headers=lab_headers, params={"week_start": DAY})
    assert response.status_code == 200
    rows = {row["ingredient_name"]: row for row in response.json()}
    record(record_property, "TC-005", f"GET HTTP {response.status_code}; позицій {len(rows)}; яйця {rows['Яйця']['quantity']} шт; молоко {rows['Молоко']['quantity']} мл")
    assert len(response.json()) == len(rows) == 3
    assert rows["Яйця"]["quantity"] == 3 and rows["Яйця"]["unit"] == "шт"
    assert rows["Молоко"]["quantity"] == 75 and rows["Молоко"]["unit"] == "мл"
    assert rows["Сіль"]["quantity"] is None and rows["Сіль"]["unit"] is None
    assert not any(row["is_manual"] for row in rows.values())


def test_TC_006_wrong_password(client, lab_user, record_property):
    response = client.post("/api/v1/auth/login", json={"email": EMAIL, "password": "Wrong-password-123"})
    record(record_property, "TC-006", f"Login HTTP {response.status_code}; access_token відсутній: {'access_token' not in response.json()}")
    assert response.status_code == 401 and "access_token" not in response.json()
    assert response.headers["WWW-Authenticate"] == "Bearer"


def test_TC_007_invalid_email(client, record_property):
    response = client.post("/api/v1/auth/register", json={"name": "Тест", "email": "not-an-email", "password": PASSWORD})
    record(record_property, "TC-007", f"Register HTTP {response.status_code}")
    assert response.status_code == 422
    assert any(error["loc"] == ["body", "email"] for error in response.json()["detail"])
    assert PASSWORD not in response.text


def test_TC_008_invalid_recipe_servings(client, lab_headers, record_property):
    response = client.post("/api/v1/recipes", headers=lab_headers, json=recipe_payload(servings=0))
    record(record_property, "TC-008", f"POST HTTP {response.status_code}")
    assert response.status_code == 422
    assert any(error["loc"] == ["body", "servings"] for error in response.json()["detail"])
    catalog = client.get("/api/v1/recipes", headers=lab_headers)
    assert catalog.status_code == 200 and catalog.json() == []


def test_TC_009_protected_data_without_token(client, lab_recipe, record_property):
    response = client.get("/api/v1/recipes")
    record(record_property, "TC-009", f"GET без токена HTTP {response.status_code}")
    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert lab_recipe["name"] not in response.text


def test_TC_010_other_users_recipe(client, lab_headers, lab_recipe, record_property):
    register(client, email="lab11.other@example.com")
    other_headers = auth(client, "lab11.other@example.com")
    response = client.get("/api/v1/recipes/" + lab_recipe["id"], headers=other_headers)
    record(record_property, "TC-010", f"Чужий рецепт HTTP {response.status_code}")
    assert response.status_code == 404
    assert lab_recipe["name"] not in response.text
    assert client.get("/api/v1/recipes", headers=other_headers).json() == []
    assert client.get("/api/v1/recipes/" + lab_recipe["id"], headers=lab_headers).status_code == 200
