import hashlib
import json
from decimal import Decimal, ROUND_HALF_UP
from unittest.mock import patch

import pytest
from sqlalchemy import select

from app.database.models import Base
from app.repositories.recipe_repository import RecipeRepository
from scripts.demo_recipes import RECIPES, FOODS
from scripts.seed_recipes import seed_recipes, seed_id
from tests.conftest import register, auth


def snapshot(application):
    with application.state.engine.connect() as connection:
        return {table.name: {str(row._mapping['id']): hashlib.sha256(json.dumps(dict(row._mapping), default=str, ensure_ascii=False, sort_keys=True).encode()).hexdigest() for row in connection.execute(select(table))} for table in Base.metadata.sorted_tables}


def add_original(client, headers):
    response = client.post('/api/v1/recipes', headers=headers, json={
        'name':'Омлет', 'description':'Власний рецепт користувача', 'category':'breakfast',
        'preparation_minutes':15, 'calories':320, 'servings':2,
        'ingredients':[{'name':'Яйця','quantity':3,'unit':'шт'},{'name':'Молоко','quantity':100,'unit':'мл'}],
        'preparation_steps':['Приготувати омлет'],
    })
    assert response.status_code == 201
    return response.json()


def test_dataset_is_complete_and_energy_is_derived_from_ingredients():
    assert len(RECIPES) == len({r.key for r in RECIPES}) == len({r.name for r in RECIPES}) == 10
    assert {r.category for r in RECIPES} == {'breakfast','lunch','dinner'}
    for recipe in RECIPES:
        data=recipe.payload()
        total=sum((Decimal(amount)*Decimal(FOODS[key][2])/100 for key,amount in recipe.amounts),Decimal(0))
        assert data.calories == int((total/data.servings).quantize(Decimal('1'),rounding=ROUND_HALF_UP))
        assert 200 <= data.calories <= 800
        assert data.description and len(data.preparation_steps)>=3
        assert all(item.quantity>0 and item.unit in ('г','мл','шт') for item in data.ingredients)
    assert RECIPES[0].payload().calories == 325
    assert RECIPES[1].payload().calories == 470
    assert {r.servings for r in RECIPES} >= {1,2,3,4,6}


def test_seed_preserves_all_existing_rows_is_scoped_and_idempotent(client, application):
    register(client)
    register(client,email='other@example.com')
    headers=auth(client)
    original=add_original(client,headers)
    slot=client.put('/api/v1/meal-plans',headers=headers,json={'date':'2026-10-26','meal_type':'breakfast','recipe_id':original['id']}).json()
    before=snapshot(application)
    with application.state.session_factory() as session:
        result=seed_recipes(session,'NAZAR@example.com')
    assert (result.created,result.skipped)==(10,0)
    after=snapshot(application)
    for table,rows in before.items():
        assert all(after[table][key]==digest for key,digest in rows.items())
    catalog=client.get('/api/v1/recipes',headers=headers).json()
    assert len(catalog)==11
    assert client.get('/api/v1/recipes/'+original['id'],headers=headers).json()==original
    assert client.get('/api/v1/meal-plans',headers=headers,params={'start_date':'2026-10-26','end_date':'2026-10-26'}).json()==[slot]
    assert client.get('/api/v1/recipes',headers=auth(client,'other@example.com')).json()==[]
    with application.state.session_factory() as session:
        again=seed_recipes(session,'nazar@example.com')
    assert (again.created,again.skipped)==(0,10)
    assert snapshot(application)==after


def test_dry_run_and_missing_user_write_nothing(client,application):
    register(client)
    before=snapshot(application)
    with application.state.session_factory() as session:
        result=seed_recipes(session,'nazar@example.com',dry_run=True)
    assert result.created==10 and result.dry_run
    assert snapshot(application)==before
    with application.state.session_factory() as session:
        with pytest.raises(ValueError,match='Користувача не знайдено'):
            seed_recipes(session,'absent@example.com')
    assert snapshot(application)==before


def test_seed_does_not_reset_edited_recipe_or_overwrite_same_name(client,application):
    user=register(client).json()
    headers=auth(client)
    custom=RECIPES[0].payload().model_dump(mode='json')
    custom.update(description='Мій власний варіант',calories=999)
    existing=client.post('/api/v1/recipes',headers=headers,json=custom).json()
    with application.state.session_factory() as session:
        result=seed_recipes(session,'nazar@example.com')
    assert (result.created,result.skipped)==(9,1)
    seeded_id=seed_id(user['id'],RECIPES[1].key)
    edited=RECIPES[1].payload().model_dump(mode='json')|{'name':'Моя змінена каша','calories':555}
    assert client.put('/api/v1/recipes/'+seeded_id,headers=headers,json=edited).status_code==200
    before=snapshot(application)
    with application.state.session_factory() as session:
        again=seed_recipes(session,'nazar@example.com')
    assert again.created==0
    assert snapshot(application)==before
    assert client.get('/api/v1/recipes/'+existing['id'],headers=headers).json()['calories']==999


def test_seed_rolls_back_the_whole_batch_on_failure(client,application):
    register(client)
    before=snapshot(application)
    original=RecipeRepository.save
    count=0
    def fail(repository,*args,**kwargs):
        nonlocal count
        count+=1
        if count==3: raise RuntimeError('injected')
        return original(repository,*args,**kwargs)
    with patch.object(RecipeRepository,'save',fail):
        with application.state.session_factory() as session:
            with pytest.raises(RuntimeError,match='injected'):
                seed_recipes(session,'nazar@example.com')
    assert snapshot(application)==before


def test_every_seed_recipe_can_be_read_planned_scaled_and_persisted(client,application,settings):
    from fastapi.testclient import TestClient
    from app.main import create_app
    user=register(client).json()
    headers=auth(client)
    with application.state.session_factory() as session:
        seed_recipes(session,'nazar@example.com')
    for index,entry in enumerate(RECIPES):
        recipe_id=seed_id(user['id'],entry.key)
        details=client.get('/api/v1/recipes/'+recipe_id,headers=headers)
        assert details.status_code==200 and details.json()['ingredients']
        day=f'2027-01-{index+4:02d}'
        first=client.put('/api/v1/meal-plans',headers=headers,json={'date':day,'meal_type':'breakfast','recipe_id':recipe_id,'planned_servings':0.5})
        assert first.status_code==200
        daily=client.get('/api/v1/statistics/daily',headers=headers,params={'date':day}).json()
        assert daily['total_calories']==entry.payload().calories*0.5
        doubled=client.put('/api/v1/meal-plans',headers=headers,json={'date':day,'meal_type':'breakfast','recipe_id':recipe_id,'planned_servings':2})
        assert doubled.json()['id']==first.json()['id']
        daily=client.get('/api/v1/statistics/daily',headers=headers,params={'date':day}).json()
        assert daily['total_calories']==entry.payload().calories*2
    items=client.get('/api/v1/shopping-items',headers=headers,params={'week_start':'2027-01-04'}).json()
    assert items and all(item['quantity']>0 for item in items)
    restarted=create_app(settings)
    with TestClient(restarted) as new:
        assert len(new.get('/api/v1/recipes',headers=headers).json())==10
        assert new.get('/api/v1/statistics/daily',headers=headers,params={'date':'2027-01-04'}).json()['total_calories']==RECIPES[0].payload().calories*2
