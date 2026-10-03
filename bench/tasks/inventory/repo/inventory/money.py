from .errors import InvalidValue


def parse_cents(text):
    """'2.5' -> 250. Rejects negatives and more than two decimals."""
    text = text.strip()
    if text.startswith("-"):
        raise InvalidValue(f"price must not be negative: {text}")
    whole, _, frac = text.partition(".")
    if not whole:
        whole = "0"
    if len(frac) > 2 or not whole.isdigit() or (frac and not frac.isdigit()):
        raise InvalidValue(f"invalid price: {text}")
    return int(whole) * 100 + int((frac + "00")[:2])


def format_cents(cents):
    """250 -> '$2.50'; 123456 -> '$1,234.56'."""
    sign = "-" if cents < 0 else ""
    cents = abs(cents)
    return f"{sign}${cents // 100:,}.{cents % 100:02d}"
