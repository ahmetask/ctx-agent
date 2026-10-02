#!/usr/bin/env bash
# Integration tests for ctx-agent scripts against throwaway git repos.
set -u
S="$(cd "$(dirname "$0")/../scripts" && pwd)"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ✓ $1"; }
bad() { fail=$((fail + 1)); echo "  ✗ $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

new_repo() {
  d=$(mktemp -d); cd "$d" || exit 1
  git init -q; git config user.email t@t; git config user.name t
  printf '{ "scripts": { "lint": "true", "test": "true" } }\n' > package.json
  mkdir -p src; echo 'x' > src/a.js
  git add -A; git commit -qm init
}

echo "detect-stack"
new_repo
out=$("$S/detect-stack.sh")
check "detects npm lint/test" 'grep -q "sensor.fast.lint=npm run lint" <<<"$out" && grep -q "sensor.fast.test=npm run test" <<<"$out"' "$out"
check "reports affordances" 'grep -q "tests-present:" <<<"$out"'

echo "init"
out=$("$S/init.sh")
check "creates map + modules" '[ -f AGENTS.md ] && [ -f .harness/config ] && [ -f .harness/context/architecture.md ] && [ -f CLAUDE.md ]' "$out"
check "config has detected sensors" 'grep -q "^sensor.fast.test=npm run test" .harness/config'
check "harness map lists sensors" 'grep -q "sensor.fast.lint" .harness/harness.md'
check "covers filled" 'grep -q "covers: src/" .harness/context/architecture.md'
echo "keep" > AGENTS.md; out=$("$S/init.sh")
check "init is non-destructive" '[ "$(cat AGENTS.md)" = keep ] && grep -q "kept     AGENTS.md" <<<"$out"'
git add -A; git commit -qm harness

check "fresh init has no drift (comments ignored)" '"$S/drift.sh" >/dev/null' "$("$S/drift.sh")"
printf 'hint.q=say "hi"\nhint.w="wrapped"\n' >> .harness/config
. "$S/lib.sh"
check "cfg_get keeps inner quotes, strips wrapping" '[ "$(cfg_get hint.q)" = "say \"hi\"" ] && [ "$(cfg_get hint.w)" = wrapped ]'
git checkout -q -- .harness/config 2>/dev/null || sed -i '/^hint\.[qw]=/d' .harness/config

echo "budget"
check "within budget" '"$S/budget.sh" -q >/dev/null'
head -c 9000 /dev/zero | tr "\0" "a" >> .harness/context/conventions.md
check "detects over-budget module" '! "$S/budget.sh" -q >/dev/null'
git checkout -q -- .harness/context/conventions.md

echo "sensors"
printf 'sensor.fast.boom=echo bad thing; exit 3\nhint.boom=do the right thing\n' >> .harness/config
out=$("$S/sensors.sh" fast); rc=$?
check "failing sensor -> exit 1 + hint" '[ $rc -eq 1 ] && grep -q "fix hint: do the right thing" <<<"$out"' "$out"
check "success is silent" '[ -z "$(grep -v boom <<<"$out" | grep -v "bad thing" | grep -v "fix hint")" ]' "$out"
seq 1 200 | sed 's/^/line /' > big.txt
printf 'sensor.fast.noisy=cat big.txt; exit 1\n' >> .harness/config
out=$("$S/sensors.sh" fast)
check "noisy output squeezed" 'grep -q "lines elided" <<<"$out" && [ $(wc -l <<<"$out") -lt 60 ]' "$out"
sed -i '/boom\|noisy/d' .harness/config; rm big.txt

echo "post-edit hook"
printf 'sensor.edit.nox=grep -L forbidden {file} | grep -q . || { echo "forbidden in {file}"; exit 1; }\n' >> .harness/config
echo ok > src/b.js
"$S/post-edit.sh" <<<"{\"tool_input\":{\"file_path\":\"$PWD/src/b.js\"}}"; rc=$?
check "clean edit passes + ledgered" '[ $rc -eq 0 ] && grep -qx "src/b.js" .harness/.ledger'
echo forbidden > src/c.js
err=$("$S/post-edit.sh" 2>&1 >/dev/null <<<"{\"tool_input\":{\"file_path\":\"src/c.js\"}}"); rc=$?
check "violating edit -> exit 2 with feedback" '[ $rc -eq 2 ] && grep -q "forbidden in src/c.js" <<<"$err"' "rc=$rc $err"
"$S/post-edit.sh" <<<"{\"tool_input\":{\"file_path\":\"$PWD/AGENTS.md\"}}"
check "context edits not ledgered" '! grep -q AGENTS.md .harness/.ledger'
sed -i '/sensor.edit.nox/d' .harness/config

echo "stop gate"
out=$("$S/stop-gate.sh" <<<'{"stop_hook_active":true}')
check "respects stop_hook_active" '[ -z "$out" ]'
printf 'sensor.fast.red=exit 1\n' >> .harness/config
out=$("$S/stop-gate.sh" <<<'{}')
check "blocks on red fast sensors" 'grep -q "\"decision\": *\"block\"" <<<"$out"' "$out"
sed -i '/sensor.fast.red/d' .harness/config
out=$("$S/stop-gate.sh" <<<'{}')
check "green + few files -> allow" '[ -z "$out" ]' "$out"
for i in 1 2 3 4 5; do echo "src/f$i.js" >> .harness/.ledger; done
out=$("$S/stop-gate.sh" <<<'{}')
check "many files -> asks for sync" 'grep -q harness-sync <<<"$out"' "$out"
sed -i 's/^gate.stop=block/gate.stop=off/' .harness/config
check "gate off" '[ -z "$("$S/stop-gate.sh" <<<"{}")" ]'

echo "drift"
"$S/ledger.sh" clear >/dev/null
printf '\n- `src/gone.js` — old; see `a.js`\n' >> AGENTS.md
printf 'see sensor.fast.ghost\n' >> .harness/harness.md
git add -A; git commit -qm docs; sleep 1
echo y >> src/a.js; git commit -qam code
out=$("$S/drift.sh"); rc=$?
check "bare existing filename is not dead" '! grep -q "dead-ref.*a.js" <<<"$out"' "$out"
check "dead-ref" 'grep -q "dead-ref.*src/gone.js" <<<"$out"' "$out"
check "stale module" 'grep -q "stale.*architecture.md" <<<"$out"' "$out"
check "orphan sensor" 'grep -q "orphan.*sensor.fast.ghost" <<<"$out"' "$out"
check "exit 1 on drift" '[ $rc -eq 1 ]'
for i in 1 2 3; do printf 'x\tfast\tlint\tfail\n' >> .harness/.sensor-log; done
check "recurring failure flagged" '"$S/drift.sh" | grep -q "recurring.*fast/lint"'

echo "session start"
out=$(CLAUDE_ENV_FILE=$PWD/env "$S/session-start.sh")
check "lists modules by 'When to read'" 'grep -q "architecture.md — adding modules" <<<"$out"' "$out"
check "exports CTX_AGENT_ROOT" 'grep -q CTX_AGENT_ROOT env'
check "context injection is small (<2KB)" '[ ${#out} -lt 2048 ]' "${#out}"
check "no plans section without active plans" '! grep -q "active exec plans" <<<"$out"'
mkdir -p .harness/plans/active .harness/plans/completed
echo '# x' > .harness/plans/active/fix-login.md; echo '# y' > .harness/plans/completed/old.md
out=$("$S/session-start.sh")
check "lists active exec plans only" 'grep -q "^- .harness/plans/active/fix-login.md" <<<"$out" && ! grep -q old.md <<<"$out"' "$out"
rm -rf .harness/plans
cd /; d2=$(mktemp -d); cd "$d2"; git init -q
check "uninitialized repo: one-line hint" '[ $("$S/session-start.sh" | wc -l) -eq 1 ]'

echo; echo "passed $pass, failed $fail"
[ $fail -eq 0 ]
