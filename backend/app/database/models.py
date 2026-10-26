from __future__ import annotations

from datetime import date, datetime, timezone
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import (
    Boolean, CheckConstraint, Date, DateTime, Float, ForeignKey,
    ForeignKeyConstraint, Index, Integer, MetaData, Numeric, String,
    Text, UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention={
        "ix": "ix_%(table_name)s_%(column_0_name)s",
        "uq": "uq_%(table_name)s_%(column_0_name)s",
        "ck": "ck_%(table_name)s_%(constraint_name)s",
        "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
        "pk": "pk_%(table_name)s",
    })


def new_id() -> str:
    return str(uuid4())


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("daily_calorie_goal BETWEEN 1 AND 100000", name="valid_goal"),
        CheckConstraint("length(trim(name)) BETWEEN 1 AND 100", name="valid_name"),
        CheckConstraint("email = lower(email)", name="normalized_email"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    email: Mapped[str] = mapped_column(String(254), unique=True)
    name: Mapped[str] = mapped_column(String(100))
    password_hash: Mapped[str] = mapped_column(String(255))
    daily_calorie_goal: Mapped[int] = mapped_column(Integer, default=2000, server_default="2000")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    recipes: Mapped[list[Recipe]] = relationship(back_populates="user", passive_deletes=True)
    ingredients: Mapped[list[Ingredient]] = relationship(back_populates="user", passive_deletes=True)
    meal_plans: Mapped[list[MealPlan]] = relationship(foreign_keys="MealPlan.user_id", passive_deletes=True)
    shopping_items: Mapped[list[ShoppingItem]] = relationship(passive_deletes=True)


class Recipe(Base):
    __tablename__ = "recipes"
    __table_args__ = (
        UniqueConstraint("id", "user_id"),
        CheckConstraint("category IN ('breakfast','lunch','dinner','salad','dessert')", name="valid_category"),
        CheckConstraint("preparation_minutes > 0", name="positive_time"),
        CheckConstraint("calories IS NULL OR calories >= 0", name="nonnegative_calories"),
        CheckConstraint("servings > 0", name="positive_servings"),
        CheckConstraint("length(trim(name)) > 0", name="valid_name"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="", server_default="")
    category: Mapped[str] = mapped_column(String(20))
    preparation_minutes: Mapped[int] = mapped_column(Integer)
    # Значення на одну порцію, не на весь рецепт. NULL означає невідоме.
    calories: Mapped[int | None] = mapped_column(Integer)
    servings: Mapped[int] = mapped_column(Integer)
    user: Mapped[User] = relationship(back_populates="recipes")
    ingredients: Mapped[list[RecipeIngredient]] = relationship(back_populates="recipe", foreign_keys="RecipeIngredient.recipe_id", passive_deletes=True, order_by="RecipeIngredient.position")
    steps: Mapped[list[PreparationStep]] = relationship(back_populates="recipe", foreign_keys="PreparationStep.recipe_id", passive_deletes=True, order_by="PreparationStep.position")


class Ingredient(Base):
    __tablename__ = "ingredients"
    __table_args__ = (
        UniqueConstraint("id", "user_id"),
        UniqueConstraint("user_id", "normalized_name"),
        CheckConstraint("length(trim(name)) > 0 AND length(trim(normalized_name)) > 0", name="valid_name"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(200))
    normalized_name: Mapped[str] = mapped_column(String(200))
    user: Mapped[User] = relationship(back_populates="ingredients")


class RecipeIngredient(Base):
    __tablename__ = "recipe_ingredients"
    __table_args__ = (
        ForeignKeyConstraint(["recipe_id", "user_id"], ["recipes.id", "recipes.user_id"], ondelete="CASCADE"),
        ForeignKeyConstraint(["ingredient_id", "user_id"], ["ingredients.id", "ingredients.user_id"], ondelete="RESTRICT"),
        UniqueConstraint("recipe_id", "position"),
        CheckConstraint("position > 0", name="positive_position"),
        CheckConstraint("(quantity IS NULL AND unit IS NULL AND note IS NOT NULL AND note = 'за смаком') OR (quantity IS NOT NULL AND quantity > 0 AND unit IS NOT NULL AND unit IN ('г','кг','мл','л','шт'))", name="valid_amount"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    recipe_id: Mapped[str] = mapped_column(String(36), index=True)
    ingredient_id: Mapped[str] = mapped_column(String(36), index=True)
    quantity: Mapped[Decimal | None] = mapped_column(Numeric(18, 6))
    unit: Mapped[str | None] = mapped_column(String(5))
    note: Mapped[str | None] = mapped_column(String(100))
    position: Mapped[int] = mapped_column(Integer)
    recipe: Mapped[Recipe] = relationship(back_populates="ingredients", foreign_keys=[recipe_id])
    ingredient: Mapped[Ingredient] = relationship(foreign_keys=[ingredient_id])


class PreparationStep(Base):
    __tablename__ = "preparation_steps"
    __table_args__ = (
        ForeignKeyConstraint(["recipe_id", "user_id"], ["recipes.id", "recipes.user_id"], ondelete="CASCADE"),
        UniqueConstraint("recipe_id", "position"),
        CheckConstraint("position > 0", name="positive_position"),
        CheckConstraint("length(trim(text)) > 0", name="nonempty_text"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    recipe_id: Mapped[str] = mapped_column(String(36), index=True)
    position: Mapped[int] = mapped_column(Integer)
    text: Mapped[str] = mapped_column(Text)
    recipe: Mapped[Recipe] = relationship(back_populates="steps", foreign_keys=[recipe_id])


class MealPlan(Base):
    __tablename__ = "meal_plans"
    __table_args__ = (
        ForeignKeyConstraint(["recipe_id", "user_id"], ["recipes.id", "recipes.user_id"], ondelete="CASCADE"),
        UniqueConstraint("user_id", "date", "meal_type"),
        CheckConstraint("meal_type IN ('breakfast','lunch','dinner')", name="valid_meal_type"),
        CheckConstraint("planned_servings > 0 AND planned_servings <= 1000", name="valid_planned_servings"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    date: Mapped[date] = mapped_column(Date)
    meal_type: Mapped[str] = mapped_column(String(15))
    recipe_id: Mapped[str] = mapped_column(String(36), index=True)
    planned_servings: Mapped[float] = mapped_column(Float, default=1, server_default="1")
    recipe: Mapped[Recipe] = relationship(foreign_keys=[recipe_id])


class ShoppingItem(Base):
    __tablename__ = "shopping_items"
    __table_args__ = (
        UniqueConstraint("user_id", "week_start", "aggregation_key"),
        CheckConstraint("length(trim(ingredient_name)) > 0", name="valid_name"),
        CheckConstraint("category IN ('vegetables','dairy','meatFish','groceries','spices','other')", name="valid_category"),
        CheckConstraint("(quantity IS NULL AND unit IS NULL) OR (quantity IS NOT NULL AND quantity > 0 AND unit IS NOT NULL AND unit IN ('г','кг','мл','л','шт'))", name="valid_amount"),
        CheckConstraint("(is_manual = 1 AND aggregation_key IS NULL) OR (is_manual = 0 AND aggregation_key IS NOT NULL)", name="valid_source"),
        CheckConstraint("is_manual IN (0,1) AND is_purchased IN (0,1)", name="valid_flags"),
        Index("ix_shopping_items_user_week", "user_id", "week_start"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    week_start: Mapped[date] = mapped_column(Date)
    ingredient_name: Mapped[str] = mapped_column(String(200))
    quantity: Mapped[Decimal | None] = mapped_column(Numeric(18, 6))
    unit: Mapped[str | None] = mapped_column(String(5))
    category: Mapped[str] = mapped_column(String(20))
    is_manual: Mapped[bool] = mapped_column(Boolean, default=False, server_default="0")
    is_purchased: Mapped[bool] = mapped_column(Boolean, default=False, server_default="0")
    aggregation_key: Mapped[str | None] = mapped_column(String(300))
