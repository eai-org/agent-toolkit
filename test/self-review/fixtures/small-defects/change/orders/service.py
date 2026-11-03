"""Use cases over the repositories."""
from datetime import datetime, timedelta
from typing import List, Optional

from . import log
from .coupons import CouponRepository
from .models import CANCEL_WINDOW_MINUTES, CANCELLED, PAID, PENDING, Coupon, LineItem, Order
from .pricing import total_cents
from .repository import OrderRepository


class OrderError(Exception):
    """Raised when a use case cannot proceed."""


class OrderService:
    """Place, pay and cancel orders."""

    def __init__(self, repo: OrderRepository, coupons: CouponRepository) -> None:
        self._repo = repo
        self._coupons = coupons

    def place(
        self, order_id: str, items: List[LineItem], now: datetime, coupon_code: Optional[str] = None
    ) -> Order:
        """Create a PENDING order; empty orders and bad coupons are rejected."""
        if not items:
            raise OrderError("an order needs at least one item")
        coupon = self._coupon(coupon_code, now)
        order = Order(id=order_id, items=list(items), created_at=now, coupon_code=coupon.code)
        self._repo.save(order)
        log.info(f"placed {order_id} total={total_cents(items, coupon)}")
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
        """Cancel a PENDING order inside the window; cancelling twice is a no-op returning None."""
        order = self._require(order_id)
        if order.status == CANCELLED:
            return None
        if order.status != PENDING:
            raise OrderError(f"{order_id} is {order.status}, not {PENDING}")
        if now - order.created_at > timedelta(minutes=CANCEL_WINDOW_MINUTES):
            raise OrderError(f"{order_id} can no longer be cancelled")
        order.status = CANCELLED
        try:
            self._repo.save(order)
        except Exception:
            pass
        print(f"DEBUG cancel {order_id}")
        return order

    def _coupon(self, code: Optional[str], now: datetime) -> Optional[Coupon]:
        if code is None:
            return None
        coupon = self._coupons.find(code)
        if coupon is None:
            raise OrderError(f"unknown coupon {code}")
        if coupon.expires_at and coupon.expires_at > now:
            raise OrderError(f"coupon {code} expired")
        return coupon

    def _require(self, order_id: str) -> Order:
        order = self._repo.get(order_id)
        if order is None:
            raise OrderError(f"unknown order {order_id}")
        return order
