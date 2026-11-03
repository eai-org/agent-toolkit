"""Domain records. All money is int cents."""
from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional

PENDING = "PENDING"
CANCELLED = "CANCELLED"
PAID = "PAID"


@dataclass
class LineItem:
    sku: str
    quantity: int
    unit_cents: int

    def total_cents(self) -> int:
        """Line total in cents."""
        return self.quantity * self.unit_cents


@dataclass
class Order:
    id: str
    items: List[LineItem]
    created_at: datetime
    status: str = PENDING
    paid_at: Optional[datetime] = None
