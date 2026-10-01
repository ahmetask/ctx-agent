#!/usr/bin/env bash
# Run computational feedback sensors for a timing tier.
#   sensors.sh <edit|fast|slow|drift> [file]
# Tiers follow "keep quality left": edit (per change, ms-s), fast (pre-commit),
# slow (post-integration / CI), drift (continuous health, outside change lifecycle).
# Output is LLM-optimised: silent on success, squeezed failures + remediation hint.
# Exit: 0 all green, 1 at least one sensor failed.
. "$(dirname "$0")/lib.sh"

tier="${1:-fast}"; file="${2:-}"
max_lines=$(cfg_get output.max_lines 40)
fail=0; ran=0

mkdir -p "$HARNESS_DIR" 2>/dev/null || true
while IFS=$'\t' read -r name cmd; do
  [ -z "$name" ] && continue
  if [ -n "$file" ]; then cmd="${cmd//\{file\}/$file}"; elif [[ "$cmd" == *"{file}"* ]]; then continue; fi
  ran=$((ran + 1))
  out=$(cd "$ROOT" && bash -c "$cmd" 2>&1); rc=$?
  status=pass; [ $rc -ne 0 ] && status=fail
  is_initialized && printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tier" "$name" "$status" >> "$SENSOR_LOG"
  if [ $rc -ne 0 ]; then
    fail=1
    echo "✗ sensor[$tier/$name] failed (exit $rc): $cmd"
    printf '%s\n' "$out" | squeeze "$max_lines"
    hint=$(hint_for "$name")
    [ -n "$hint" ] && echo "→ fix hint: $hint"
  fi
done < <(cfg_sensors "$tier")

if [ $fail -eq 0 ] && [ "${CTX_VERBOSE:-0}" = 1 ]; then
  echo "✓ $ran sensor(s) green in tier '$tier'"
fi
[ $ran -eq 0 ] && [ "${CTX_VERBOSE:-0}" = 1 ] && echo "no sensors configured for tier '$tier' (.harness/config)"
exit $fail
