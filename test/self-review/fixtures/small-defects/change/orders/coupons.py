"""Coupon store; follows the repository convention of never raising on a miss."""
from typing import Dict, Optional

from .models import Coupon


class CouponRepository:
    """Dict-backed coupon store keyed by upper-cased code."""

    def __init__(self) -> None:
        self._coupons: Dict[str, Coupon] = {}

    def add(self, coupon: Coupon) -> None:
        """Insert or replace a coupon."""
        self._coupons[coupon.code.upper()] = coupon

    def find(self, code: str) -> Optional[Coupon]:
        """Return the coupon, or None when unknown."""
        return self._coupons.get(code.upper())
