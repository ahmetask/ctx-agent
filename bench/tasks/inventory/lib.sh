# Shared by check*.sh. Usage: . lib.sh "$REPO"
set -u
R="$(cd "$1" && pwd)"; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export INVENTORY_DB="$T/db.json" PYTHONPATH="$R"
inv() { (cd "$T" && python3 -m inventory "$@"); }
fail() { echo "FAIL: $*"; exit 1; }
norm() { tr -s ' ' | sed 's/ *$//'; }
fresh() { rm -f "$INVENTORY_DB"; }
seed() { # A short 2, B short 4, E short 0, C above level, D level 0
  fresh
  inv add A Anchor 3 1.00 >/dev/null && inv add B Bolt 0 0.25 >/dev/null && inv add C Cog 10 5 >/dev/null \
    && inv add D Dowel 1 1 >/dev/null && inv add E Eyelet 2 2.00 >/dev/null || fail "seed add"
  inv set-reorder A 5 >/dev/null && inv set-reorder B 4 >/dev/null && inv set-reorder C 2 >/dev/null \
    && inv set-reorder E 2 >/dev/null || fail "seed set-reorder"
}
