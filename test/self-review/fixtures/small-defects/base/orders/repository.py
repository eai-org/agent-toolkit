"""In-memory persistence. Rows are plain dicts so they can be dumped to JSON."""
from datetime import datetime
from typing import Dict, Optional

from .models import LineItem, Order


def to_row(order: Order) -> dict:
    """Serialize an order to a JSON-ready dict."""
    return {
        "id": order.id,
        "items": [[i.sku, i.quantity, i.unit_cents] for i in order.items],
        "created_at": order.created_at.isoformat(),
        "status": order.status,
        "paid_at": order.paid_at.isoformat() if order.paid_at else None,
    }


def from_row(row: dict) -> Order:
    """Rebuild an order from a dict produced by to_row."""
    return Order(
        id=row["id"],
        items=[LineItem(*i) for i in row["items"]],
        created_at=datetime.fromisoformat(row["created_at"]),
        status=row["status"],
        paid_at=datetime.fromisoformat(row["paid_at"]) if row["paid_at"] else None,
    )


class OrderRepository:
    """Dict-backed store; swap for a database in production."""

    def __init__(self) -> None:
        self._rows: Dict[str, dict] = {}

    def save(self, order: Order) -> None:
        """Insert or replace an order."""
        self._rows[order.id] = to_row(order)

    def get(self, order_id: str) -> Optional[Order]:
        """Return the order, or None when unknown."""
        row = self._rows.get(order_id)
        return from_row(row) if row else None

    def delete(self, order_id: str) -> bool:
        """Remove an order; False when it did not exist."""
        return self._rows.pop(order_id, None) is not None
