from datetime import datetime, timedelta

import pytest

from orders.coupons import CouponRepository
from orders.models import CANCELLED, PAID, Coupon, LineItem
from orders.repository import OrderRepository
from orders.service import OrderError, OrderService

NOW = datetime(2026, 1, 1, 12, 0)


def service(*coupons):
    repo = CouponRepository()
    for coupon in coupons:
        repo.add(coupon)
    return OrderService(OrderRepository(), repo)


def test_place_rejects_empty_order():
    with pytest.raises(OrderError):
        service().place("o1", [], NOW)


def test_place_with_coupon_records_code():
    svc = service(Coupon("TEN", 10))
    order = svc.place("o1", [LineItem("a", 1, 100)], NOW, coupon_code="ten")
    assert order.coupon_code == "TEN"


def test_expired_coupon_rejected():
    svc = service(Coupon("OLD", 10, expires_at=NOW - timedelta(days=1)))
    with pytest.raises(OrderError):
        svc.place("o1", [LineItem("a", 1, 100)], NOW, coupon_code="OLD")


def test_pay_marks_paid():
    svc = service()
    svc.place("o1", [LineItem("a", 1, 100)], NOW)
    assert svc.pay("o1", NOW).status == PAID


def test_cancel_twice_is_noop():
    svc = service()
    svc.place("o1", [LineItem("a", 1, 100)], NOW)
    assert svc.cancel("o1", NOW).status == CANCELLED
    assert svc.cancel("o1", NOW) is None
