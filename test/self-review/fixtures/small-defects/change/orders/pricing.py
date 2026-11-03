"""Totals and discounts, all in int cents."""
from typing import Optional, Sequence

from .models import Coupon, LineItem

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


def coupon_discount_cents(items: Sequence[LineItem], coupon: Optional[Coupon]) -> int:
    """The coupon's percent of the subtotal; 0 without a coupon."""
    if coupon is None:
        return 0
    return subtotal_cents(items) * coupon.percent / 100


def total_cents(items: Sequence[LineItem], coupon: Optional[Coupon] = None) -> int:
    """Subtotal minus bulk and coupon discounts, never below zero."""
    discount = bulk_discount_cents(items) + coupon_discount_cents(items, coupon)
    return max(0, subtotal_cents(items) - discount)
