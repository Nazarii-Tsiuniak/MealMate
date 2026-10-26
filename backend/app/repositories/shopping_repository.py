from sqlalchemy import select
from app.database.models import ShoppingItem
from app.repositories.base import Repository


class ShoppingRepository(Repository):
    def for_week(self, user_id, week):
        return list(self.session.scalars(select(ShoppingItem).where(
            ShoppingItem.user_id == user_id, ShoppingItem.week_start == week
        ).order_by(ShoppingItem.category, ShoppingItem.ingredient_name, ShoppingItem.id)))

    def find(self, user_id, item_id):
        return self.session.scalar(select(ShoppingItem).where(ShoppingItem.user_id == user_id, ShoppingItem.id == item_id))

    def add(self, item):
        self.session.add(item)
        self.session.flush()
        return item

    def delete(self, item):
        self.session.delete(item)

    def flush(self):
        self.session.flush()
