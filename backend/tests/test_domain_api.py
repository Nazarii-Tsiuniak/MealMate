from uuid import uuid4
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from app.main import create_app
from tests.conftest import auth, register

DAY = "2026-12-28"
NEXT = "2027-01-04"


def recipe_payload(**changes):
    return {
        "name": "Омлет із зеленню", "description": "Легкий сніданок",
        "category": "breakfast", "preparation_minutes": 15, "calories": 320, "servings": 2,
        "ingredients": [
            {"name": "Яйця", "quantity": 4, "unit": "шт"},
            {"name": "Молоко", "quantity": 100, "unit": "мл"},
            {"name": "Сіль", "note": "за смаком"},
        ], "preparation_steps": ["Збити яйця", "Приготувати омлет"],
    } | changes


@pytest.fixture
def headers(client):
    assert register(client).status_code == 201
    return auth(client)


def create(client, headers, **changes):
    response = client.post("/api/v1/recipes", headers=headers, json=recipe_payload(**changes))
    assert response.status_code == 201, response.text
    return response.json()


def assign(client, headers, recipe_id, day=DAY, meal="breakfast", portions=1):
    response = client.put("/api/v1/meal-plans", headers=headers, json={
        "date": day, "meal_type": meal, "recipe_id": recipe_id, "planned_servings": portions})
    assert response.status_code == 200, response.text
    return response.json()


def shopping(client, headers, day=DAY):
    response = client.get("/api/v1/shopping-items", headers=headers, params={"week_start": day})
    assert response.status_code == 200, response.text
    return response.json()


def daily(client, headers, day=DAY):
    response = client.get("/api/v1/statistics/daily", headers=headers, params={"date": day})
    assert response.status_code == 200, response.text
    return response.json()


def test_recipe_crud_and_children_order(client, headers, application):
    recipe = create(client, headers)
    recipe_id = recipe["id"]
    assert recipe["preparation_steps"] == recipe_payload()["preparation_steps"]
    assert recipe["ingredients"][2]["quantity"] is None
    assert client.get(f"/api/v1/recipes/{recipe_id}", headers=headers).json() == recipe
    changed = recipe_payload(name="Новий омлет", preparation_steps=["Крок Б", "Крок А"],
        ingredients=[{"name": "Зелень", "quantity": 20, "unit": "г"}])
    result = client.put(f"/api/v1/recipes/{recipe_id}", headers=headers, json=changed)
    assert result.status_code == 200, result.text
    assert result.json()["preparation_steps"] == ["Крок Б", "Крок А"]
    assert [row["name"] for row in result.json()["ingredients"]] == ["Зелень"]
    assert client.get("/api/v1/recipes", headers=headers).json() == [result.json()]
    assert client.delete(f"/api/v1/recipes/{recipe_id}", headers=headers).status_code == 204
    assert client.get(f"/api/v1/recipes/{recipe_id}", headers=headers).status_code == 404
    assert client.get("/api/v1/recipes", headers=headers).json() == []


def test_unicode_search_category_and_literal_wildcards(client, headers):
    create(client, headers)
    create(client, headers, name="Омлет вечірній", category="dinner")
    create(client, headers, name="Страва 100%_користі", category="salad")
    result = client.get("/api/v1/recipes", headers=headers, params={"search": "ОМЛЕТ", "category": "breakfast"})
    assert len(result.json()) == 1
    assert client.get("/api/v1/recipes", headers=headers, params={"search": "не знайдено"}).json() == []
    assert len(client.get("/api/v1/recipes", headers=headers, params={"search": "%_"}).json()) == 1
    assert client.get("/api/v1/recipes", headers=headers, params={"category": "invalid"}).status_code == 422


@pytest.mark.parametrize("changes", [
    {"name": " "}, {"preparation_minutes": 0}, {"calories": -1}, {"servings": 0},
    {"ingredients": []}, {"preparation_steps": []}, {"preparation_steps": [" "]},
    {"ingredients": [{"name": "Сіль"}]},
    {"ingredients": [{"name": "Сіль", "quantity": 1, "unit": "invalid"}]},
    {"ingredients": [{"name": "Сіль", "quantity": 0, "unit": "г"}]},
    {"ingredients": [{"name": "Сіль", "quantity": "NaN", "unit": "г"}]},
    {"ingredients": [{"name": "Сіль", "quantity": 1, "note": "за смаком"}]},
    {"ingredients": [{"name": "Сіль", "unit": "г", "note": "за смаком"}]},
    {"ingredients": [{"name": "Сіль", "quantity": 1, "unit": "г", "note": "за смаком"}]},
    {"user_id": str(uuid4())},
])
def test_recipe_validation(client, headers, changes):
    assert client.post("/api/v1/recipes", headers=headers, json=recipe_payload(**changes)).status_code == 422
    assert client.get("/api/v1/recipes", headers=headers).json() == []


def test_plan_replacement_fractional_portions_and_dates(client, headers):
    first = create(client, headers)
    second = create(client, headers, name="Салат", category="salad", calories=200)
    slot = assign(client, headers, first["id"], portions=0.25)
    assert daily(client, headers)["total_calories"] == 80
    replaced = assign(client, headers, second["id"], portions=1.5)
    assert replaced["id"] == slot["id"]
    assert daily(client, headers)["total_calories"] == 300
    assign(client, headers, first["id"], NEXT)
    result = client.get("/api/v1/meal-plans", headers=headers, params={"start_date": DAY, "end_date": DAY})
    assert result.json() == [replaced]
    assert client.get("/api/v1/meal-plans", headers=headers, params={"start_date": NEXT,"end_date": DAY}).status_code == 422
    assert client.delete('/api/v1/meal-plans/' + slot["id"], headers=headers).status_code == 204
    assert daily(client, headers)["total_calories"] == 0
    assert shopping(client, headers) == []
    assert shopping(client, headers, NEXT)


def test_shopping_portions_units_repetition_and_taste(client, headers):
    first = create(client, headers)
    assign(client, headers, first["id"], portions=0.5)
    assign(client, headers, first["id"], meal="lunch", portions=2)
    other = create(client, headers, ingredients=[
        {"name":" яЙцЯ ", "quantity":1,"unit":"шт"},
        {"name":"молоко", "quantity":1,"unit":"л"},
        {"name":"Молоко", "quantity":1,"unit":"кг"},
        {"name":"Сіль", "note":"за смаком"},
    ], servings=1)
    assign(client, headers, other["id"], meal="dinner")
    items = shopping(client, headers)
    assert len(items) == 4
    assert next(x for x in items if x["unit"]=="шт")["quantity"] == 6
    assert next(x for x in items if x["unit"]=="л")["quantity"] == 1.125
    assert next(x for x in items if x["unit"]=="кг")["quantity"] == 1
    assert next(x for x in items if x["unit"] is None)["quantity"] is None
    assert shopping(client, headers) == items


def test_purchase_status_manual_and_recipe_update_sync(client, headers):
    recipe = create(client, headers)
    slot = assign(client, headers, recipe["id"])
    items = shopping(client, headers)
    for item in items:
        assert client.patch('/api/v1/shopping-items/'+item["id"], headers=headers, json={"is_purchased": True}).status_code == 200
    manual = client.post("/api/v1/shopping-items", headers=headers, json={"week_start": DAY,"ingredient_name":"Хліб","quantity":1,"unit":"шт"}).json()
    assign(client, headers, recipe["id"])
    assert all(x["is_purchased"] for x in shopping(client,headers) if not x["is_manual"])
    assign(client, headers, recipe["id"], portions=2)
    items = shopping(client,headers)
    assert next(x for x in items if x["ingredient_name"]=="Сіль")["is_purchased"]
    assert not next(x for x in items if x["ingredient_name"]=="Яйця")["is_purchased"]
    assert next(x for x in items if x["id"]==manual["id"])
    update = recipe_payload(calories=400, servings=4, ingredients=[{"name":"Рис","quantity":200,"unit":"г"}])
    assert client.put('/api/v1/recipes/'+recipe["id"], headers=headers, json=update).status_code == 200
    items = shopping(client,headers)
    assert len(items) == 2
    assert next(x for x in items if not x["is_manual"])["quantity"] == 100
    assert daily(client,headers)["total_calories"] == 800
    assert client.delete('/api/v1/recipes/'+recipe["id"], headers=headers).status_code == 204
    assert shopping(client,headers) == [next(x for x in items if x["is_manual"])]
    assert daily(client,headers)["total_calories"] == 0


def test_manual_edit_equivalent_units_reset_status_and_delete(client, headers):
    response = client.post('/api/v1/shopping-items', headers=headers, json={"week_start":"2026-12-30","ingredient_name":"Рис","quantity":1,"unit":"кг"})
    assert response.status_code == 201
    item=response.json()
    assert item["week_start"] == DAY
    path='/api/v1/shopping-items/'+item["id"]
    assert client.patch(path,headers=headers,json={"is_purchased":True}).json()["is_purchased"]
    assert client.patch(path,headers=headers,json={"quantity":1000,"unit":"г"}).json()["is_purchased"]
    changed = client.patch(path,headers=headers,json={"quantity":500,"is_purchased":True}).json()
    assert changed["quantity"] == 500 and not changed["is_purchased"]
    assert client.patch(path,headers=headers,json={"quantity":None}).status_code == 422
    assert client.patch(path,headers=headers,json={"quantity":None,"unit":None}).json()["quantity"] is None
    assert client.patch(path,headers=headers,json={}).status_code == 400
    assert shopping(client, headers, NEXT) == []
    assert client.delete(path,headers=headers).status_code == 204
    assert shopping(client,headers) == []


def test_automatic_items_only_allow_purchase_toggle(client, headers):
    recipe=create(client,headers)
    assign(client,headers,recipe["id"])
    item=shopping(client,headers)[0]
    path='/api/v1/shopping-items/'+item["id"]
    assert client.patch(path,headers=headers,json={"quantity":100}).status_code == 409
    assert client.delete(path,headers=headers).status_code == 409
    assert client.patch(path,headers=headers,json={"is_purchased":True}).status_code == 200


def test_daily_weekly_goals_unknown_and_year_boundary(client, headers):
    known=create(client,headers)
    unknown=create(client,headers,calories=None)
    assign(client,headers,known["id"],portions=2)
    client.patch('/api/v1/users/me',headers=headers,json={"daily_calorie_goal":500})
    day=daily(client,headers)
    assert day["meals"] == {"breakfast":640,"lunch":0,"dinner":0}
    assert day["total_calories"] == 640 and day["known_calories"] == 640
    assert day["goal_progress_percent"] == 128 and day["progress_fraction"] == 1
    assert day["remaining_calories"] == -140 and day["is_complete"]
    assign(client,headers,known["id"],day="2027-01-03",meal="dinner")
    assign(client,headers,known["id"],day=NEXT)
    week=client.get('/api/v1/statistics/weekly',headers=headers,params={"start_date":"2027-01-01"}).json()
    assert week["start_date"] == DAY and week["end_date"] == "2027-01-03"
    assert len(week["days"]) == len(week["chart"]) == 7
    assert week["average_calories"] == pytest.approx(960/7)
    assign(client,headers,unknown["id"],meal="lunch")
    day=daily(client,headers)
    assert day["total_calories"] is None and day["known_calories"] == 640
    assert day["meals"]["lunch"] is None and not day["is_complete"]
    week=client.get('/api/v1/statistics/weekly',headers=headers,params={"start_date":DAY}).json()
    assert not week["is_complete"] and not week["chart"][0]["is_complete"]
    assert week["average_calories"] == pytest.approx(960/7)


def test_ownership_for_every_resource(client, headers):
    recipe=create(client,headers)
    slot=assign(client,headers,recipe["id"])
    item=shopping(client,headers)[0]
    register(client,email="other@example.com")
    other=auth(client,"other@example.com")
    for path in ['/api/v1/recipes/'+recipe["id"], '/api/v1/meal-plans/'+slot["id"], '/api/v1/shopping-items/'+item["id"]]:
        assert client.delete(path,headers=other).status_code == 404
    assert client.get('/api/v1/recipes/'+recipe["id"],headers=other).status_code == 404
    assert client.put('/api/v1/recipes/'+recipe["id"],headers=other,json=recipe_payload()).status_code == 404
    assert client.patch('/api/v1/shopping-items/'+item["id"],headers=other,json={"is_purchased":True}).status_code == 404
    assert client.put('/api/v1/meal-plans',headers=other,json={"date":DAY,"meal_type":"breakfast","recipe_id":recipe["id"]}).status_code == 404
    assert client.get('/api/v1/recipes',headers=other).json() == []
    assert shopping(client,other) == []
    assert daily(client,other)["total_calories"] == 0
    assert client.get('/api/v1/meal-plans',headers=other,params={"start_date":DAY}).json() == []


def test_sync_failure_rolls_back_recipe_and_plan(client, headers):
    recipe=create(client,headers)
    with patch('app.services.shopping_service.ShoppingService.synchronize',side_effect=RuntimeError('injected')):
        response=client.put('/api/v1/meal-plans',headers=headers,json={"date":DAY,"meal_type":"breakfast","recipe_id":recipe["id"]})
        assert response.status_code == 500
        response=client.put('/api/v1/recipes/'+recipe["id"],headers=headers,json=recipe_payload(name="Не зберігати"))
        assert response.status_code == 500
    assert daily(client,headers)["total_calories"] == 0
    assert client.get('/api/v1/recipes/'+recipe["id"],headers=headers).json()["name"] == recipe["name"]


def test_domain_persistence_with_new_engine(client, headers, settings):
    recipe=create(client,headers)
    slot=assign(client,headers,recipe["id"],portions=0.5)
    item=shopping(client,headers)[0]
    client.patch('/api/v1/shopping-items/'+item["id"],headers=headers,json={"is_purchased":True})
    restarted=create_app(settings)
    with TestClient(restarted) as new:
        assert new.get('/api/v1/recipes/'+recipe["id"],headers=headers).json() == recipe
        assert new.get('/api/v1/meal-plans',headers=headers,params={"start_date":DAY}).json() == [slot]
        assert any(x["is_purchased"] for x in shopping(new,headers))
        assert daily(new,headers)["total_calories"] == 160


@pytest.mark.parametrize("value", [0, -0.5, 1001, "NaN", "Infinity", True])
def test_invalid_portions_do_not_mutate_plan_or_shopping(client, headers, value):
    recipe=create(client,headers)
    initial=assign(client,headers,recipe["id"],portions=0.5)
    items=shopping(client,headers)
    response=client.put('/api/v1/meal-plans',headers=headers,json={"date":DAY,"meal_type":"breakfast","recipe_id":recipe["id"],"planned_servings":value})
    assert response.status_code == 422
    assert client.get('/api/v1/meal-plans',headers=headers,params={"start_date":DAY}).json() == [initial]
    assert shopping(client,headers) == items


@pytest.mark.parametrize("method,path,payload", [
    ("post","/api/v1/recipes",recipe_payload()),
    ("get","/api/v1/recipes",None),
    ("put","/api/v1/meal-plans",{"date":DAY,"meal_type":"breakfast","recipe_id":str(uuid4())}),
    ("get","/api/v1/meal-plans",None),
    ("get","/api/v1/shopping-items",None),
    ("post","/api/v1/shopping-items",{"week_start":DAY,"ingredient_name":"Хліб"}),
    ("get","/api/v1/statistics/daily?date="+DAY,None),
    ("get","/api/v1/statistics/weekly?start_date="+DAY,None),
])
def test_domain_routes_require_jwt(client,method,path,payload):
    kwargs={} if payload is None else {"json":payload}
    assert getattr(client,method)(path,**kwargs).status_code == 401


@pytest.mark.parametrize("payload", [
    {"quantity":-1,"unit":"г"}, {"quantity":1}, {"unit":"шт"},
    {"quantity":"Infinity","unit":"г"}, {"ingredient_name":" "},
    {"is_manual":False}, {"user_id":str(uuid4())},
])
def test_manual_input_validation(client,headers,payload):
    data={"week_start":DAY,"ingredient_name":"Цукор"}|payload
    assert client.post('/api/v1/shopping-items',headers=headers,json=data).status_code == 422
    assert shopping(client,headers) == []


def test_concurrent_assignments_keep_single_slot_and_exact_shopping(client,headers):
    from concurrent.futures import ThreadPoolExecutor
    recipe=create(client,headers)
    def update(portions):
        return client.put('/api/v1/meal-plans',headers=headers,json={"date":DAY,"meal_type":"breakfast","recipe_id":recipe["id"],"planned_servings":portions})
    with ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(update,[1,2]))
    assert all(response.status_code == 200 for response in results)
    assert results[0].json()["id"] == results[1].json()["id"]
    slots=client.get('/api/v1/meal-plans',headers=headers,params={"start_date":DAY}).json()
    assert len(slots) == 1
    portions=slots[0]["planned_servings"]
    assert daily(client,headers)["total_calories"] == portions*320
    assert next(x for x in shopping(client,headers) if x["unit"]=="шт")["quantity"] == portions*2


def test_manual_units_stay_explicit_and_empty_statistics(client,headers):
    item=client.post('/api/v1/shopping-items',headers=headers,json={"week_start":DAY,"ingredient_name":"Рис","quantity":1000,"unit":"г"}).json()
    assert item["quantity"] == 1000 and item["unit"] == "г"
    updated=client.patch('/api/v1/shopping-items/'+item["id"],headers=headers,json={"quantity":500}).json()
    assert updated["quantity"] == 500 and updated["unit"] == "г"
    day=daily(client,headers)
    assert day["total_calories"] == 0 and day["is_complete"]
    week=client.get('/api/v1/statistics/weekly',headers=headers,params={"start_date":DAY}).json()
    assert week["average_calories"] == 0 and week["is_complete"]
    assert len(week["chart"]) == 7


def test_all_affected_weeks_update_and_delete_cascade(client,headers):
    recipe=create(client,headers)
    assign(client,headers,recipe["id"])
    assign(client,headers,recipe["id"],day=NEXT,portions=2)
    assert client.put('/api/v1/recipes/'+recipe["id"],headers=headers,json=recipe_payload(servings=4)).status_code == 200
    assert next(x for x in shopping(client,headers) if x["unit"]=="шт")["quantity"] == 1
    assert next(x for x in shopping(client,headers,NEXT) if x["unit"]=="шт")["quantity"] == 2
    client.delete('/api/v1/recipes/'+recipe["id"],headers=headers)
    assert shopping(client,headers) == shopping(client,headers,NEXT) == []
    assert daily(client,headers)["total_calories"] == daily(client,headers,NEXT)["total_calories"] == 0


def test_tiny_scaled_quantity_rejects_atomically_instead_of_storing_zero(client,headers):
    recipe=create(client,headers,servings=1000000,ingredients=[{"name":"Сіль","quantity":0.000001,"unit":"г"}])
    response=client.put('/api/v1/meal-plans',headers=headers,json={"date":DAY,"meal_type":"breakfast","recipe_id":recipe["id"]})
    assert response.status_code == 422
    assert daily(client,headers)["total_calories"] == 0
    assert shopping(client,headers) == []
