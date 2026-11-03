from datetime import datetime

from orders.models import LineItem, Order
from orders.repository import from_row, to_row

NOW = datetime(2026, 1, 1, 12, 0)


def test_note_round_trips():
    order = Order(id="o1", items=[LineItem("a", 1, 100)], created_at=NOW, note="fragile")
    assert from_row(to_row(order)).note == "fragile"


def test_row_dumped_before_notes_loads_with_none():
    row = to_row(Order(id="o1", items=[LineItem("a", 1, 100)], created_at=NOW))
    del row["note"]
    assert from_row(row).note is None
