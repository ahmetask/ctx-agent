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
touch .harness/state.md  # handoff written -> no state nudge
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
rm -f .harness/checkpoint.md
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
check "no checkpoint section before any checkpoint" '! grep -q "last checkpoint" <<<"$out"'

echo "checkpoint (session memory)"
mkdir -p .harness/plans/active
printf '# Fix login\n- status: gate=implement · branch=x\n\n## Next action\nadd the retry test\n' > .harness/plans/active/fix-login.md
echo dirty >> src/a.js; echo src/a.js > .harness/.ledger; printf 'x\tfast\ttest\tfail\n' >> .harness/.sensor-log
"$S/checkpoint.sh" precompact </dev/null
cp=$(cat .harness/checkpoint.md 2>/dev/null)
check "records event, git, uncommitted, ledger" 'grep -q "precompact" <<<"$cp" && grep -q "^- git: " <<<"$cp" && grep -q "uncommitted (.*src/a.js" <<<"$cp" && grep -q "edited since sync: src/a.js" <<<"$cp"' "$cp"
check "records failing sensors and plan next action" 'grep -q "failing sensors (last run): .*fast/test" <<<"$cp" && grep -q "gate=implement.*next: add the retry test" <<<"$cp"' "$cp"
printf 'x\tfast\ttest\tpass\n' >> .harness/.sensor-log; "$S/checkpoint.sh" </dev/null
check "sensor that recovered is not reported" '! grep -q "fast/test" .harness/checkpoint.md'
out=$("$S/session-start.sh" </dev/null)
check "session start shows checkpoint" 'grep -q "last checkpoint" <<<"$out" && grep -q "next: add the retry test" <<<"$out"' "$out"
check "context injection still small (<2KB)" '[ ${#out} -lt 2048 ]' "${#out}"
check "checkpoint is gitignored by template" 'grep -qx checkpoint.md "$S/../templates/harness/gitignore"'
rm -rf .harness/plans; git checkout -q -- src/a.js

echo "stop gate: state handoff nudge"
sed -i 's/^gate.stop=off/gate.stop=block/' .harness/config; "$S/ledger.sh" clear >/dev/null
rm -f .harness/checkpoint.md; touch -d '1 hour ago' .harness/state.md; echo src/a.js > .harness/.ledger
out=$("$S/stop-gate.sh" <<<'{"session_id":"s1"}')
check "code changed, state.md not -> asks for handoff" 'grep -q "state.md did not" <<<"$out"' "$out"
check "stop gate refreshes checkpoint" '[ -f .harness/checkpoint.md ]'
check "nudges once per session" '[ -z "$("$S/stop-gate.sh" <<<"{\"session_id\":\"s1\"}")" ]'
check "nudges again in a new session" 'grep -q "state.md did not" <<<"$("$S/stop-gate.sh" <<<"{\"session_id\":\"s2\"}")"'
touch .harness/state.md; rm -f .harness/.state-nudged
check "no nudge when state.md is newer" '[ -z "$("$S/stop-gate.sh" <<<"{\"session_id\":\"s3\"}")" ]'
touch .harness/.ledger; echo 'gate.state=off' >> .harness/config; rm -f .harness/.state-nudged
check "gate.state=off disables nudge" '[ -z "$("$S/stop-gate.sh" <<<"{\"session_id\":\"s4\"}")" ]'
sed -i '/^gate.state=off/d' .harness/config

echo "read guard"
head -c 40000 /dev/zero | tr '\0' 'a' > big.txt; echo small > small.txt
err=$("$S/read-guard.sh" 2>&1 <<<"{\"tool_input\":{\"file_path\":\"$PWD/big.txt\"}}"); rc=$?
check "large whole-file read refused with hint" '[ $rc -eq 2 ] && grep -q "offset/limit" <<<"$err"' "rc=$rc $err"
"$S/read-guard.sh" <<<"{\"tool_input\":{\"file_path\":\"$PWD/big.txt\",\"limit\":100}}"; rc=$?
check "ranged read allowed" '[ $rc -eq 0 ]'
"$S/read-guard.sh" <<<"{\"tool_input\":{\"file_path\":\"$PWD/small.txt\"}}"; rc=$?
check "small read allowed" '[ $rc -eq 0 ]'
echo 'guard.read_max_tokens=0' >> .harness/config
"$S/read-guard.sh" <<<"{\"tool_input\":{\"file_path\":\"$PWD/big.txt\"}}" 2>/dev/null; rc=$?
check "guard.read_max_tokens=0 disables" '[ $rc -eq 0 ]'
sed -i '/^guard.read_max_tokens/d' .harness/config; rm -f big.txt small.txt

cd /; d2=$(mktemp -d); cd "$d2"; git init -q
check "uninitialized repo: one-line hint" '[ $("$S/session-start.sh" | wc -l) -eq 1 ]'
check "uninitialized repo: read guard and checkpoint are no-ops" '"$S/read-guard.sh" <<<"{}" && "$S/checkpoint.sh" </dev/null && [ ! -e .harness ]'

echo "bench task checks"
B="$S/../bench"; T="$B/tasks/inventory"
d3=$(mktemp -d); cp -R "$T/repo" "$d3/r"
check "checks fail on the untouched fixture" '! bash "$T/check1.sh" "$d3/r" >/dev/null 2>&1 && ! bash "$T/check2.sh" "$d3/r" >/dev/null 2>&1'
(cd "$d3/r" && git init -q && git apply "$T/reference.patch")
check "checks pass on the reference solution" 'for i in 1 2 3; do bash "$T/check$i.sh" "$d3/r" >/dev/null || exit 1; done'

echo "bench runner (fake claude)"
export FAKE_LOG="$d3/fake.log" FAKE_PATCH="$T/reference.patch"
out=$(CLAUDE_BIN="$S/../tests/fake-claude.sh" "$B/run.sh" --reps 1 --out "$d3/out" 2>&1); rc=$?
res="$d3/out/results.tsv"
check "runner exits 0 and writes summary" '[ $rc -eq 0 ] && [ -s "$d3/out/summary.md" ]' "$out"
check "one setup + 3 arms x 3 phases recorded" '[ $(($(wc -l < "$res") - 1)) -eq 10 ]' "$(cat "$res")"
check "hidden checks graded (all pass)" '[ "$(awk -F"\t" "NR>1 && \$4!=1" "$res")" = "" ]' "$(cat "$res")"
check "tokens from modelUsage" 'awk -F"\t" "\$2==\"baseline\"" "$res" | head -n1 | cut -f6-9 | grep -qx "300.200.1000.50"' "$(cat "$res")"
check "baseline runs without plugin" 'grep "^baseline " "$FAKE_LOG" | grep -vq "plugin=yes"' "$(cat "$FAKE_LOG")"
check "ctx arm: memory wiped between phases" '[ "$(grep "^ctx " "$FAKE_LOG" | cut -d" " -f3 | tr "\n" " ")" = "focus=none focus=none focus=none " ]' "$(cat "$FAKE_LOG")"
check "ctx-mem arm: memory carried" '[ "$(grep "^ctx-mem " "$FAKE_LOG" | cut -d" " -f3- | tr "\n" " ")" = "focus=none focus=phase 1 focus=phase 2 " ]' "$(cat "$FAKE_LOG")"
check "report shows delta vs baseline" 'grep -q "| ctx-mem | 3/3 | 0.3000 | -66.7% |" "$d3/out/summary.md"' "$(cat "$d3/out/summary.md")"
check "report includes setup cost" 'grep -q "Setup (harness-init" "$d3/out/summary.md"'
check "work dirs are separate git repos" '[ -d "$d3/out/work/r1/baseline/.git" ] && [ ! -d "$d3/out/work/r1/baseline/.harness" ]'
rm -rf "$d3"

echo; echo "passed $pass, failed $fail"
[ $fail -eq 0 ]
