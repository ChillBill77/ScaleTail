#!/usr/bin/env bash
#
# scaffold.sh — create a new ScaleTail service from the standard template.
#
# Follows CONTRIBUTING.md ("Add a service") and documentation/standard-setup.md.
# Copies templates/service-template/ into services/<name>/ and fills the
# SERVICE, IMAGE_URL and SERVICEPORT placeholders in .env and README.md.
# compose.yaml is copied unchanged — adapt it (volumes, healthcheck, Serve
# port) for the application afterwards.
#
# Usage: ./scripts/scaffold.sh <service-name> <image-url> [service-port]

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/scaffold.sh <service-name> <image-url> [service-port]

Create services/<service-name>/ from the standard template.

  <service-name>  lowercase name (a-z, 0-9, hyphens). Used as SERVICE, the
                  Tailnet hostname, and the container/data names.
  <image-url>     application image, e.g. ghcr.io/acme/myapp:latest.
  <service-port>  optional; the port written into README "Service port".
                  Omit to leave the template default and fill it by hand.

Examples:
  ./scripts/scaffold.sh my-service ghcr.io/acme/my-service:latest
  ./scripts/scaffold.sh my-service ghcr.io/acme/my-service:latest 8080
EOF
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  usage
  exit 1
fi

SERVICE="$1"
IMAGE_URL="$2"
SERVICEPORT="${3:-}"

# Validate the service name (lowercase a-z0-9 and hyphens).
if ! [[ "$SERVICE" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "error: <service-name> must be lowercase a-z, 0-9 and hyphens (got '$SERVICE')" >&2
  exit 1
fi

# Validate the image URL (non-empty, no whitespace).
if [[ -z "$IMAGE_URL" || "$IMAGE_URL" =~ [[:space:]] ]]; then
  echo "error: <image-url> must be a single non-empty image reference" >&2
  exit 1
fi

# Validate the port (numeric 1-65535) when given.
if [ -n "$SERVICEPORT" ]; then
  if ! [[ "$SERVICEPORT" =~ ^[0-9]+$ ]] || [ "$SERVICEPORT" -lt 1 ] || [ "$SERVICEPORT" -gt 65535 ]; then
    echo "error: <service-port> must be a number 1-65535 (got '$SERVICEPORT')" >&2
    exit 1
  fi
fi

DEST="services/$SERVICE"
if [ -e "$DEST" ]; then
  echo "error: $DEST already exists" >&2
  exit 1
fi

# Copy the template, including the hidden .env file.
cp -R templates/service-template "$DEST"

# Fill .env placeholders (SERVICE, IMAGE_URL, SERVICEPORT).
sed -i "s|^SERVICE=$|SERVICE=${SERVICE}|" "$DEST/.env"
sed -i "s|^IMAGE_URL=$|IMAGE_URL=${IMAGE_URL}|" "$DEST/.env"
if [ -n "$SERVICEPORT" ]; then
  sed -i "s|^SERVICEPORT=$|SERVICEPORT=${SERVICEPORT}|" "$DEST/.env"
fi

# Fill README placeholders. SERVICE -> name (lowercase, everywhere), the
# IMAGE value -> image URL, and the Service port value -> the port when given.
sed -i "s|SERVICE|${SERVICE}|g" "$DEST/README.md"
# IMAGE appears once as the "At a glance" value (backticked); escape & in the URL.
IMAGE_URL_ESC="${IMAGE_URL//&/\\&}"
sed -i "s|\`IMAGE\`|\`${IMAGE_URL_ESC}\`|" "$DEST/README.md"
if [ -n "$SERVICEPORT" ]; then
  sed -i "s|\`80\`|\`${SERVICEPORT}\`|" "$DEST/README.md"
fi

cat <<EOF

Created $DEST with:
  .env         SERVICE=${SERVICE}, IMAGE_URL=${IMAGE_URL}, SERVICEPORT=${SERVICEPORT:-<unset>}
  README.md    placeholders filled
  compose.yaml copied unchanged

Next steps (CONTRIBUTING.md "Add a service"):
  1. Adapt $DEST/compose.yaml — persistent volumes, devices/capabilities,
     the application healthcheck, and the Serve proxy port (it does not read
     SERVICEPORT from .env).
  2. Complete $DEST/README.md — the one/two-sentence description, "First run",
     "Before you start", "Deviations from the standard setup", and the Links.
  3. Add the service to the correct category in the root README.md (alphabetized).
  4. Run:  ./scripts/validate.sh $SERVICE
EOF
