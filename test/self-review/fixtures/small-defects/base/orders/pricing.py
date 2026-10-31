"""Totals and discounts, all in int cents."""
from typing import Sequence

from .models import LineItem

BULK_THRESHOLD = 10
BULK_DISCOUNT_PERCENT = 5


def subtotal_cents(items: Sequence[LineItem]) -> int:
    """Sum of line totals."""
    total = 0
    for item in items:
        total += item.total_cents()
    return total


def bulk_discount_cents(items: Sequence[LineItem]) -> int:
    """5% off the subtotal once the order holds BULK_THRESHOLD units or more."""
    units = sum(i.quantity for i in items)
    if units < BULK_THRESHOLD:
        return 0
    return subtotal_cents(items) * BULK_DISCOUNT_PERCENT // 100


def total_cents(items: Sequence[LineItem]) -> int:
    """Subtotal minus discounts, never below zero."""
    return max(0, subtotal_cents(items) - bulk_discount_cents(items))
