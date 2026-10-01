#!/usr/bin/env bash
# Detect ecosystems by marker files and print suggested sensors in .harness/config
# format, plus harnessability signals (ambient affordances). Read-only.
# Never guesses beyond marker files: the agent must verify each command once.
. "$(dirname "$0")/lib.sh"
cd "$ROOT" || exit 1

has() { [ -e "$1" ]; }
any() { compgen -G "$1" >/dev/null 2>&1; }
has_npm_script() { grep -Eq "\"$1\"[[:space:]]*:" package.json 2>/dev/null; }
has_make_target() { grep -Eq "^$1:" Makefile 2>/dev/null; }
s() { printf 'sensor.%s.%s=%s\n' "$1" "$2" "$3"; }

echo "# stacks"
found=0
if has package.json; then
  found=1; pm=npm; has pnpm-lock.yaml && pm=pnpm; has yarn.lock && pm=yarn; has bun.lockb && pm=bun
  echo "# node ($pm)"
  for t in lint typecheck test; do has_npm_script "$t" && s fast "$t" "$pm run $t"; done
  has tsconfig.json && ! has_npm_script typecheck && s fast typecheck "npx tsc --noEmit"
  any ".eslintrc*" || any "eslint.config.*" && s edit eslint "npx eslint {file}"
fi
if has pyproject.toml || has setup.py || has requirements.txt; then
  found=1; echo "# python"
  grep -q ruff pyproject.toml 2>/dev/null && { s edit ruff "ruff check {file}"; s fast ruff "ruff check ."; }
  grep -q mypy pyproject.toml 2>/dev/null && s fast typecheck "mypy ."
  { has pytest.ini || grep -q pytest pyproject.toml 2>/dev/null || [ -d tests ]; } && s fast test "pytest -q -x"
fi
if has go.mod; then
  found=1; echo "# go"
  s edit gofmt 'test -z "$(gofmt -l {file})"'; s fast vet "go vet ./..."; s fast test "go test ./..."
fi
if has Cargo.toml; then
  found=1; echo "# rust"
  s fast clippy "cargo clippy -q -- -D warnings"; s fast test "cargo test -q"
fi
if has pom.xml; then found=1; echo "# jvm (maven)"; s fast test "mvn -q test"; s slow verify "mvn -q verify"; fi
if any "build.gradle*"; then
  found=1; echo "# jvm (gradle)"; g=gradle; has gradlew && g=./gradlew
  s fast test "$g test -q"; s slow check "$g check -q"
fi
if any "*.sln" || any "*.csproj"; then found=1; echo "# dotnet"; s fast build "dotnet build -nologo -v q"; s fast test "dotnet test -nologo -v q"; fi
if has Gemfile; then
  found=1; echo "# ruby"
  grep -q rubocop Gemfile && s edit rubocop "bundle exec rubocop {file}"
  [ -d spec ] && s fast test "bundle exec rspec"
fi
if has composer.json; then found=1; echo "# php"; [ -f vendor/bin/phpunit ] && s fast test "vendor/bin/phpunit"; fi
if has mix.exs; then found=1; echo "# elixir"; s fast test "mix test"; s fast format "mix format --check-formatted"; fi
if has pubspec.yaml; then found=1; echo "# dart"; s fast analyze "dart analyze"; s fast test "dart test"; fi
if has Package.swift; then found=1; echo "# swift"; s fast test "swift test"; fi
if has Makefile; then
  echo "# make"
  for t in lint check test; do has_make_target "$t" && s fast "make-$t" "make $t"; done
fi
any "*.sh" && command -v shellcheck >/dev/null && s edit shellcheck "shellcheck {file}"
[ $found -eq 0 ] && echo "# no known ecosystem markers; ask the human which commands lint/test this repo"

echo "# harnessability (ambient affordances)"
af() { printf '%-22s %s\n' "$1" "$2"; }
typed=no
{ has tsconfig.json || has go.mod || has Cargo.toml || has pom.xml || any "build.gradle*" || any "*.csproj" || has Package.swift || grep -q mypy pyproject.toml 2>/dev/null; } && typed=yes
af "static-types:" "$typed"
tests=no; { [ -d test ] || [ -d tests ] || [ -d spec ] || [ -d __tests__ ] || git ls-files 2>/dev/null | grep -Eqi '(_test|\.test|\.spec|Test)\.[a-z]+$'; } && tests=yes
af "tests-present:" "$tests"
lint=no; { any ".eslintrc*" || any "eslint.config.*" || grep -q ruff pyproject.toml 2>/dev/null || has .golangci.yml || has .rubocop.yml || has Cargo.toml || has .editorconfig; } && lint=yes
af "lint/format-config:" "$lint"
ci=no; { [ -d .github/workflows ] || has .gitlab-ci.yml || has Jenkinsfile || [ -d .circleci ] || has azure-pipelines.yml; } && ci=yes
af "ci-pipeline:" "$ci"
hooks=no; { has .pre-commit-config.yaml || [ -d .husky ] || has lefthook.yml; } && hooks=yes
af "pre-commit-hooks:" "$hooks"
af "top-level-modules:" "$(find . -mindepth 1 -maxdepth 1 -type d ! -name '.*' ! -name node_modules ! -name vendor ! -name target ! -name dist ! -name build | wc -l | tr -d ' ')"
