#!/usr/bin/env bash
#
# validate.sh — check ScaleTail services against the standard setup.
#
# Runs the checks a service must pass before a PR (CONTRIBUTING.md "Verify your
# change"), plus a few the CI does not cover. With no arguments it checks every
# service and the template; pass one or more service names to check just those.
#
#   compose config   docker compose config --quiet, with dummy values for any
#                    required variable the template leaves empty.
#   .env             required variables present; no committed credentials.
#   README.md        the required sections are present.
#
# Structural deviations (extra containers, a stack with no application) are
# documented per-service in the README and reviewed by humans, so they are not
# asserted here.
#
# Usage: ./scripts/validate.sh [service-name ...]

set -uo pipefail

# Resolve the repo root (this script lives in <root>/scripts).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# --- pick the directories to validate --------------------------------
if [ "$#" -gt 0 ]; then
  DIRS=()
  for name in "$@"; do
    if [ -d "services/$name" ]; then
      DIRS+=("services/$name/")
    else
      echo "error: unknown service '$name' (no services/$name/)" >&2
      exit 2
    fi
  done
else
  DIRS=(services/*/ templates/service-template/)
fi

# --- docker compose availability -------------------------------------
COMPOSE_CMD=""
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
fi

status=0

for dir in "${DIRS[@]}"; do
  name="${dir%/}"           # e.g. services/adguardhome
  failed=()

  # 1. compose config (skipped when docker compose is unavailable locally).
  if [ -n "$COMPOSE_CMD" ]; then
    vars=(SERVICE IMAGE_URL)
    ok=0
    for _ in $(seq 1 30); do
      if out=$(cd "$dir" && env "${vars[@]/%/=dummy}" $COMPOSE_CMD config --quiet 2>&1); then
        # "The X variable is not set" -> used in compose.yaml but missing from .env.
        unset_vars=$(sed -nE 's/.*The "?([A-Za-z0-9_]+)"? variable is not set.*/\1/p' <<<"$out" | sort -u)
        for v in $unset_vars; do
          failed+=("$v is used in compose.yaml but not defined in .env")
        done
        ok=1
        break
      fi
      # "required variable X is missing a value" -> add a dummy and retry.
      missing=$(grep -oE 'required variable [A-Za-z0-9_]+' <<<"$out" | awk '{print $3}' | sort -u | grep -vxFf <(printf '%s\n' "${vars[@]}") || true)
      if [ -z "$missing" ]; then
        failed+=("docker compose config failed (not a missing required variable)")
        ok=1
        break
      fi
      while read -r v; do vars+=("$v"); done <<<"$missing"
    done
    [ "$ok" = 1 ] || failed+=("docker compose config could not be satisfied")
  fi

  # 2. .env — required variables present.
  if [ -f "$dir.env" ]; then
    for v in SERVICE IMAGE_URL TS_AUTHKEY TZ; do
      grep -qE "^${v}=" "$dir.env" || failed+=("$v missing from .env")
    done
    # Secret scan: a secret-looking variable with a non-empty value that is not
    # a ${VAR:?...} reference and not empty quotes is a committed credential.
    leaked=$(awk -F= '
      $1 ~ /^(TS_AUTHKEY|[A-Za-z0-9_]*(KEY|TOKEN|PASSWORD|SECRET|PASS))$/ {
        val = substr($0, index($0, "=") + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", val)
        if (val != "" && val !~ /^\$\{/ && val != "\"\"" && val != "\047\047") print $1
      }
    ' "$dir.env")
    if [ -n "$leaked" ]; then
      failed+=("credential committed in .env: $(echo "$leaked" | tr '\n' ' ' | sed 's/ $//')")
    fi
  else
    failed+=("missing .env")
  fi

  # 3. README.md — required sections.
  if [ -f "$dir"README.md ]; then
    for sec in "At a glance" "Before you start" "Deviations from the standard setup" "First run" "Links"; do
      grep -qE "^## ${sec}$" "$dir"README.md || failed+=("README.md missing '## $sec'")
    done
  else
    failed+=("missing README.md")
  fi

  # 4. compose.yaml — structure (see header: deviations are not asserted here).
  compose_file="$dir"compose.yaml
  [ -f "$compose_file" ] || compose_file="$dir"compose.yml
  [ -f "$compose_file" ] || failed+=("missing compose.yaml (or compose.yml)")

  if [ ${#failed[@]} -eq 0 ]; then
    echo "OK  $name"
  else
    echo "FAIL $name"
    for msg in "${failed[@]}"; do
      echo "     - $msg"
    done
    status=1
  fi
done

if [ -z "$COMPOSE_CMD" ]; then
  echo
  echo "note: docker compose is not installed here, so compose config was not checked."
  echo "      It will be checked by the CI workflow (.github/workflows/compose-validation.yml)."
fi

exit $status
