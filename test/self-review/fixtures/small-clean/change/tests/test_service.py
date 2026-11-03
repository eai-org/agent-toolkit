from datetime import datetime

import pytest

from orders.models import CANCELLED, MAX_NOTE_CHARS, PAID, LineItem
from orders.repository import OrderRepository
from orders.service import OrderError, OrderService

NOW = datetime(2026, 1, 1, 12, 0)


def service():
    return OrderService(OrderRepository())


def test_place_rejects_empty_order():
    with pytest.raises(OrderError):
        service().place("o1", [], NOW)


def test_place_keeps_note_through_repository():
    repo = OrderRepository()
    svc = OrderService(repo)
    svc.place("o1", [LineItem("a", 1, 100)], NOW, note="leave at the door")
    assert repo.get("o1").note == "leave at the door"


def test_place_rejects_note_over_limit():
    with pytest.raises(OrderError):
        service().place("o1", [LineItem("a", 1, 100)], NOW, note="x" * (MAX_NOTE_CHARS + 1))


def test_place_accepts_note_at_limit():
    order = service().place("o1", [LineItem("a", 1, 100)], NOW, note="x" * MAX_NOTE_CHARS)
    assert len(order.note) == MAX_NOTE_CHARS


def test_pay_marks_paid():
    svc = service()
    svc.place("o1", [LineItem("a", 1, 100)], NOW)
    assert svc.pay("o1", NOW).status == PAID


def test_cancel_twice_is_noop():
    svc = service()
    svc.place("o1", [LineItem("a", 1, 100)], NOW)
    assert svc.cancel("o1", NOW).status == CANCELLED
    assert svc.cancel("o1", NOW) is None
