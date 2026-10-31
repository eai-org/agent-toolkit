from orders.models import LineItem
from orders.pricing import bulk_discount_cents, subtotal_cents, total_cents


def items(*pairs):
    return [LineItem(sku=f"sku{i}", quantity=q, unit_cents=c) for i, (q, c) in enumerate(pairs)]


def test_subtotal_sums_every_line():
    assert subtotal_cents(items((2, 150), (1, 99))) == 399


def test_bulk_discount_below_threshold_is_zero():
    assert bulk_discount_cents(items((9, 100))) == 0


def test_bulk_discount_at_threshold_is_five_percent():
    assert bulk_discount_cents(items((10, 100))) == 50


def test_total_never_negative():
    assert total_cents([]) == 0
