from datetime import datetime

import pytest

from orders.models import CANCELLED, PAID, LineItem
from orders.repository import OrderRepository
from orders.service import OrderError, OrderService

NOW = datetime(2026, 1, 1, 12, 0)


def service():
    return OrderService(OrderRepository())


def test_place_rejects_empty_order():
    with pytest.raises(OrderError):
        service().place("o1", [], NOW)


def test_pay_marks_paid():
    svc = service()
    svc.place("o1", [LineItem("a", 1, 100)], NOW)
    assert svc.pay("o1", NOW).status == PAID


def test_cancel_twice_is_noop():
    svc = service()
    svc.place("o1", [LineItem("a", 1, 100)], NOW)
    assert svc.cancel("o1", NOW).status == CANCELLED
    assert svc.cancel("o1", NOW) is None
