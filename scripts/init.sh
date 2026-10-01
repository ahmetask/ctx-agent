#!/usr/bin/env bash
# Scaffold the harness non-destructively. Never overwrites existing files.
# The agent then fills placeholders ({{...}}) from the actual codebase.
. "$(dirname "$0")/lib.sh"
T="$(cd "$(dirname "$0")/../templates" && pwd)"
cd "$ROOT" || exit 1

made() { echo "created  $1"; }
kept() { echo "kept     $1 (exists)"; }

detect=$("$(dirname "$0")/detect-stack.sh")
sensors=$(printf '%s\n' "$detect" | sed -n '/^# stacks/,/^# harnessability/p' | sed '1d;$d')
afford=$(printf '%s\n' "$detect" | sed -n '/^# harnessability/,$p' | sed '1d' | sed 's/^/- /')
controls=$(printf '%s\n' "$sensors" | grep '^sensor\.' | while IFS= read -r l; do
  k="${l%%=*}"; tier=$(echo "$k" | cut -d. -f2)
  echo "| ${k##*.} | fb | C | maint | $tier | \`$k\` |"
done)
covers=$(find . -mindepth 1 -maxdepth 1 -type d ! -name '.*' ! -name node_modules ! -name vendor ! -name target ! -name dist ! -name build -printf '%f/ ' 2>/dev/null)

mkdir -p .harness/context
fill() { # fill SRC DEST
  if [ -e "$2" ]; then kept "$2"; return; fi
  S="$sensors" C="$controls" A="$afford" CV="$covers" P="$(basename "$ROOT")" awk '
    BEGIN { s=ENVIRON["S"]; c=ENVIRON["C"]; a=ENVIRON["A"]; cv=ENVIRON["CV"]; p=ENVIRON["P"] }
    { if ($0=="{{SENSORS}}") { print (s==""?"# (none detected - ask the human)":s); next }
      if ($0=="{{CONTROLS}}") { if (c!="") print c; next }
      if ($0=="{{AFFORDANCES}}") { print a; next }
      gsub(/\{\{COVERS\}\}/, cv); gsub(/\{\{PROJECT\}\}/, p); print }' "$1" > "$2"
  made "$2"
}
fill "$T/AGENTS.md" AGENTS.md
fill "$T/harness/config" .harness/config
fill "$T/harness/harness.md" .harness/harness.md
fill "$T/harness/state.md" .harness/state.md
for m in "$T"/harness/context/*.md; do fill "$m" ".harness/context/$(basename "$m")"; done
[ -e .harness/.gitignore ] || { cp "$T/harness/gitignore" .harness/.gitignore; made .harness/.gitignore; }

if [ ! -e CLAUDE.md ]; then
  printf '@AGENTS.md\n' > CLAUDE.md; made CLAUDE.md
elif ! grep -q '@AGENTS.md' CLAUDE.md; then
  echo "action   CLAUDE.md exists without @AGENTS.md: merge its durable facts into AGENTS.md, then make CLAUDE.md import it"
fi
echo "next     verify each sensor command once; fill {{...}} and empty sections from the code; keep within budget (budget.sh)"
