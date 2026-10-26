# Архітектура після рефакторингу

Впроваджено один новий патерн **Facade** — `backend/app/services/meal_planning_facade.py`, клас `MealPlanningFacade`. Проста публічна поверхня охоплює чотири сценарії, а не CRUD усього застосунку:

- `save_recipe(user_id, data, recipe_id=None)`: транзакція → власник і зачеплені тижні (лише редагування) → запис → синхронізація → RecipeRead → commit.
- `delete_recipe`: транзакція → власник → тижні до каскадного видалення → видалення → синхронізація → commit.
- `assign_meal`: транзакція → власник рецепта → створення/заміна слота → синхронізація тижня → MealPlanRead → commit.
- `delete_meal`: транзакція → власник слота → тиждень до видалення → видалення → синхронізація → commit.

Приватний `_recipe_weeks` прибирає повтор побудови унікального набору тижнів. Для створення рецепта дати плану не читаються. Фасад використовує наявні Repository та ShoppingService; алгоритм синхронізації не копіюється.

`RecipeService` залишає читання, перевірку власника і перетворення у DTO; залежить лише від RecipeRepository. `MealPlanService` залишає читання діапазону й `find` з перевіркою власника; залежить лише від MealPlanRepository. Методи запису перенесені до фасаду, старих паралельних точок запису в сервісах не залишено.

`app/dependencies.py`: `get_meal_planning_facade` отримує три компоненти через Depends; кеш залежностей FastAPI зберігає спільні репозиторії/Session. Маршрути GET використовують попередні читальні сервіси. POST/PUT/DELETE рецептів та PUT/DELETE плану отримують Facade. Pydantic-валідація та current_user залишаються на HTTP-межі.

Транзакції, BEGIN IMMEDIATE, rollback/commit, порядок SQL/перевірок і формати DTO збережені. Міграції, ORM, JSON-схеми, формули калорій/порцій та Flutter-код не змінені. Статистика читає актуальний план; зайвого перерахунку статистики при записі не додано.

## Файли

Створено: `backend/app/services/meal_planning_facade.py`, `backend/tests/test_meal_planning_facade.py`, матеріали `docs/lab12/`.

Змінено: `backend/app/services/recipe_service.py`, `backend/app/services/meal_plan_service.py`, `backend/app/dependencies.py`, `backend/app/routers/recipes.py`, `backend/app/routers/meal_plans.py`.

Наявні тести, репозиторії, алгоритми покупок/калорій, авторизація й Flutter не змінені.

UML класів: [after_facade.mmd](after_facade.mmd). Взаємодія: [facade_sequence.mmd](facade_sequence.mmd). Інтерфейс фасаду — його чотири публічні методи; окремий абстрактний інтерфейс без альтернативних реалізацій не створювався.

```mermaid
classDiagram
  class RecipeRouter {
    recipes(user, service)
    details(id, user, service)
    create(data, user, facade)
    update(id, data, user, facade)
    delete(id, user, facade)
  }
  class MealPlanRouter {
    plans(user, service, start, end)
    assign(data, user, facade)
    delete(id, user, facade)
  }
  class MealPlanningFacade {
    save_recipe(user_id, data, recipe_id) RecipeRead
    delete_recipe(user_id, recipe_id)
    assign_meal(user_id, data) MealPlanRead
    delete_meal(user_id, plan_id)
    _recipe_weeks(user_id, recipe_id)
  }
  class RecipeService {
    find(user_id, recipe_id)
    read(recipe) RecipeRead
    list(user_id, search, category)
    details(user_id, recipe_id)
  }
  class MealPlanService {
    list(user_id, start, end)
    find(user_id, plan_id)
  }
  class RecipeRepository {
    transaction()
    find(user_id, id)
    save(user_id, data, normalize, recipe)
    delete(user_id, id)
  }
  class MealPlanRepository {
    transaction()
    recipe_dates(user_id, recipe_id)
    between(user_id, start, end)
    find(user_id, id)
    assign(user_id, data)
    delete(slot)
  }
  class ShoppingService {
    synchronize(user_id, weeks)
  }
  class NutritionService {
    daily(user, date)
    weekly(user, start)
  }
  RecipeRouter --> RecipeService : reads
  MealPlanRouter --> MealPlanService : reads
  RecipeRouter --> MealPlanningFacade : writes
  MealPlanRouter --> MealPlanningFacade : writes
  MealPlanningFacade --> RecipeService : ownership and serialization
  MealPlanningFacade --> MealPlanService : plan ownership
  MealPlanningFacade --> ShoppingService : affected weeks only
  RecipeService --> RecipeRepository
  MealPlanService --> MealPlanRepository
  MealPlanningFacade --> RecipeRepository : transactional recipe writes
  MealPlanningFacade --> MealPlanRepository : transactional plan writes
  ShoppingService --> MealPlanRepository
  NutritionService --> MealPlanRepository
  note for MealPlanningFacade "One existing Session; write + sync + serialize before commit"
```

```mermaid
sequenceDiagram
  participant Router as PUT /meal-plans
  participant Facade as MealPlanningFacade
  participant Tx as Repository.transaction
  participant Recipes as RecipeService
  participant Plans as MealPlanRepository
  participant Shopping as ShoppingService
  Router->>Facade: assign_meal(current_user.id, data)
  Facade->>Tx: BEGIN IMMEDIATE
  Facade->>Recipes: find(user_id, recipe_id)
  Recipes-->>Facade: owned recipe or 404
  Facade->>Plans: assign(user_id, data)
  Facade->>Shopping: synchronize(user_id, affected week)
  alt success
    Facade->>Facade: MealPlanRead.model_validate(slot)
    Facade->>Tx: COMMIT
    Facade-->>Router: MealPlanRead
  else ownership / sync / serialization error
    Facade->>Tx: ROLLBACK
    Facade-->>Router: existing error handling
  end
```
