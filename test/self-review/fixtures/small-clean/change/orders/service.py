"""Use cases over the repository."""
from datetime import datetime
from typing import List, Optional

from . import log
from .models import CANCELLED, MAX_NOTE_CHARS, PAID, PENDING, LineItem, Order
from .pricing import total_cents
from .repository import OrderRepository


class OrderError(Exception):
    """Raised when a use case cannot proceed."""


class OrderService:
    """Place, pay and cancel orders."""

    def __init__(self, repo: OrderRepository) -> None:
        self._repo = repo

    def place(
        self, order_id: str, items: List[LineItem], now: datetime, note: Optional[str] = None
    ) -> Order:
        """Create a PENDING order; empty orders and over-long notes are rejected."""
        if not items:
            raise OrderError("an order needs at least one item")
        if note is not None and len(note) > MAX_NOTE_CHARS:
            raise OrderError(f"note exceeds {MAX_NOTE_CHARS} characters")
        order = Order(id=order_id, items=list(items), created_at=now, note=note)
        self._repo.save(order)
        log.info(f"placed {order_id} total={total_cents(items)}")
        return order

    def pay(self, order_id: str, now: datetime) -> Order:
        """Mark a PENDING order PAID."""
        order = self._require(order_id)
        if order.status != PENDING:
            raise OrderError(f"{order_id} is {order.status}, not {PENDING}")
        order.status = PAID
        order.paid_at = now
        self._repo.save(order)
        return order

    def cancel(self, order_id: str, now: datetime) -> Optional[Order]:
        """Cancel a PENDING order; cancelling twice is a no-op returning None."""
        order = self._require(order_id)
        if order.status == CANCELLED:
            return None
        if order.status != PENDING:
            raise OrderError(f"{order_id} is {order.status}, not {PENDING}")
        order.status = CANCELLED
        self._repo.save(order)
        return order

    def _require(self, order_id: str) -> Order:
        order = self._repo.get(order_id)
        if order is None:
            raise OrderError(f"unknown order {order_id}")
        return order
