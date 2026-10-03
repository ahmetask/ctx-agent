import argparse
import sys

from . import __version__, table
from .errors import InventoryError, InvalidValue
from .importer import read_csv
from .models import Item
from .money import format_cents, parse_cents
from .storage import Store


def _int(text):
    try:
        return int(text)
    except ValueError:
        raise InvalidValue(f"not an integer: {text}") from None


def cmd_add(store, args):
    store.add(Item(args.sku, args.name, _int(args.qty), parse_cents(args.price)))
    store.save()
    print(f"added {args.sku}")


def cmd_remove(store, args):
    store.remove(args.sku)
    store.save()
    print(f"removed {args.sku}")


def cmd_adjust(store, args):
    item = store.get(args.sku)
    new_qty = item.qty + _int(args.delta)
    if new_qty < 0:
        raise InvalidValue(f"{args.sku}: qty would become {new_qty}")
    item.qty = new_qty
    store.save()
    print(f"{args.sku} qty {new_qty}")


def cmd_list(store, args):
    rows = [(i.sku, i.name, i.qty, format_cents(i.unit_price_cents)) for i in store.sorted_items()]
    if not rows:
        print("no items")
        return
    print(table.render(["SKU", "NAME", "QTY", "PRICE"], rows, numeric={"QTY", "PRICE"}))


def cmd_show(store, args):
    item = store.get(args.sku)
    print(f"sku: {item.sku}")
    print(f"name: {item.name}")
    print(f"qty: {item.qty}")
    print(f"unit_price: {format_cents(item.unit_price_cents)}")
    print(f"value: {format_cents(item.value_cents)}")


def cmd_value(store, args):
    total = sum(i.value_cents for i in store.items.values())
    print(f"total value: {format_cents(total)} across {len(store.items)} item(s)")


def cmd_import(store, args):
    items = read_csv(args.csv)
    for item in items:
        store.add(item)
    store.save()
    print(f"imported {len(items)} item(s)")


def build_parser():
    p = argparse.ArgumentParser(prog="inventory")
    p.add_argument("--version", action="version", version=__version__)
    sub = p.add_subparsers(dest="command", required=True)

    a = sub.add_parser("add", help="add a new item")
    a.add_argument("sku")
    a.add_argument("name")
    a.add_argument("qty")
    a.add_argument("price", help="unit price, e.g. 2.50")
    a.set_defaults(func=cmd_add)

    r = sub.add_parser("remove", help="delete an item")
    r.add_argument("sku")
    r.set_defaults(func=cmd_remove)

    j = sub.add_parser("adjust", help="change quantity by a signed delta")
    j.add_argument("sku")
    j.add_argument("delta")
    j.set_defaults(func=cmd_adjust)

    sub.add_parser("list", help="list all items").set_defaults(func=cmd_list)

    s = sub.add_parser("show", help="show one item")
    s.add_argument("sku")
    s.set_defaults(func=cmd_show)

    sub.add_parser("value", help="total stock value").set_defaults(func=cmd_value)

    i = sub.add_parser("import", help="add items from a CSV (sku,name,qty,price)")
    i.add_argument("csv")
    i.set_defaults(func=cmd_import)
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        store = Store.load()
        args.func(store, args)
    except InventoryError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0
