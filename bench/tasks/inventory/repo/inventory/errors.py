class InventoryError(Exception):
    """Base class for user-facing errors. The CLI prints `error: <message>` and exits 2."""


class UnknownSku(InventoryError):
    def __init__(self, sku):
        super().__init__(f"unknown sku {sku!r}")
        self.sku = sku


class DuplicateSku(InventoryError):
    def __init__(self, sku):
        super().__init__(f"sku {sku!r} already exists")
        self.sku = sku


class InvalidValue(InventoryError):
    pass
