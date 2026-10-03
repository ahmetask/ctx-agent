from dataclasses import dataclass

from .errors import InvalidValue


def _non_negative_int(name, value):
    if isinstance(value, bool) or not isinstance(value, int):
        raise InvalidValue(f"{name} must be an integer")
    if value < 0:
        raise InvalidValue(f"{name} must not be negative")
    return value


@dataclass
class Item:
    sku: str
    name: str
    qty: int
    unit_price_cents: int

    def __post_init__(self):
        if not self.sku or " " in self.sku:
            raise InvalidValue("sku must be non-empty and contain no spaces")
        if not self.name.strip():
            raise InvalidValue("name must not be empty")
        _non_negative_int("qty", self.qty)
        _non_negative_int("unit_price_cents", self.unit_price_cents)

    @property
    def value_cents(self):
        return self.qty * self.unit_price_cents

    def to_dict(self):
        return {
            "sku": self.sku,
            "name": self.name,
            "qty": self.qty,
            "unit_price_cents": self.unit_price_cents,
        }

    @classmethod
    def from_dict(cls, d):
        return cls(
            sku=d["sku"],
            name=d["name"],
            qty=d["qty"],
            unit_price_cents=d["unit_price_cents"],
        )
