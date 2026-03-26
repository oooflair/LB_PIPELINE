#!/bin/bash
set -euo pipefail

echo "============================================================================================================================="
echo "============================================     Starting run-liquibase.sh      ============================================="
echo "============================================================================================================================="

MODE=${1:-}

if [ "$MODE" != "dryrun" ] && [ "$MODE" != "execute" ]; then
  echo "❌ ERROR: First argument must be 'dryrun' or 'execute'"
  exit 1
fi

ENVIRONMENT=${ENVIRONMENT:-}
DATABASE_URL=${DATABASE_URL:-}
DB_USERNAME=${DB_USERNAME:-}
CHANGEREQUEST_ID=${CHANGEREQUEST_ID:-}
OPERATION=${OPERATION:-}
ROLLBACK_TAG=${ROLLBACK_TAG:-}

# Optional: override Docker network name via env var (default auto-detected from compose project)
COMPOSE_NETWORK_NAME=${COMPOSE_NETWORK_NAME:-liquibase_operations_oracle_database_lb_test_net}

# ─────────────────────────────────────────────────────────────────────────────
# Validate inputs
# ─────────────────────────────────────────────────────────────────────────────
if [ -z "$ENVIRONMENT" ]; then
  printf "❌ ERROR: ENVIRONMENT is required (UAT/PROD)\n" >&2; exit 1
fi
if [ -z "$DATABASE_URL" ]; then
  printf "❌ ERROR: DATABASE_URL is required\n" >&2; exit 1
fi
if [ -z "$DB_USERNAME" ]; then
  printf "❌ ERROR: DB_USERNAME is required — enter Oracle DB username in GoCD UI\n" >&2; exit 1
fi
if [ -z "$OPERATION" ]; then
  printf "❌ ERROR: OPERATION is required (update/rollback)\n" >&2; exit 1
fi

ENV_LOWER=$(printf '%s' "$ENVIRONMENT" | awk '{print tolower($0)}')
ENV_UPPER=$(printf '%s' "$ENVIRONMENT" | awk '{print toupper($0)}')
OPERATION_LOWER=$(printf '%s' "$OPERATION" | awk '{print tolower($0)}')
DB_USERNAME_LOWER=$(printf '%s' "$DB_USERNAME" | awk '{print tolower($0)}')
DB_USERNAME_UPPER=$(printf '%s' "$DB_USERNAME" | awk '{print toupper($0)}')

if [ "$OPERATION_LOWER" != "update" ] && [ "$OPERATION_LOWER" != "rollback" ]; then
  printf "❌ ERROR: Invalid OPERATION: %s — must be 'update' or 'rollback'\n" "$OPERATION" >&2
  exit 1
fi

if [ "$OPERATION_LOWER" = "update" ] && [ -z "$CHANGEREQUEST_ID" ]; then
  printf "❌ ERROR: CHANGEREQUEST_ID required when OPERATION=update\n" >&2
  exit 1
fi

if [ "$OPERATION_LOWER" = "rollback" ] && [ -z "$ROLLBACK_TAG" ]; then
  printf "❌ ERROR: ROLLBACK_TAG required when OPERATION=rollback\n" >&2
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Extract DB IP from JDBC URL
# Example: jdbc:oracle:thin:@//10.5.20.213:1521/ORCLPDB1
# ─────────────────────────────────────────────────────────────────────────────
HOST_PART=$(printf '%s\n' "$DATABASE_URL" | sed -n 's/.*@\/\/\([^:\/]*\).*/\1/p')

if [ -z "$HOST_PART" ]; then
  printf "❌ ERROR: Could not extract host from DATABASE_URL: %s\n" "$DATABASE_URL" >&2
  exit 1
fi

if ! printf '%s' "$HOST_PART" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  printf "❌ ERROR: Host '%s' must be a valid IPv4. Use IP, not hostname.\n" "$HOST_PART" >&2
  exit 1
fi

DB_IP="$HOST_PART"
DB_IP_UNDERSCORE=$(printf '%s' "$DB_IP" | tr '.' '_')

echo
echo "✅ [INFO] Inputs resolved:"
echo "  MODE:             $MODE"
echo "  ENVIRONMENT:      $ENV_LOWER"
echo "  DB_IP:            $DB_IP  (→ $DB_IP_UNDERSCORE)"
echo "  DB_USERNAME:      $DB_USERNAME_LOWER"
echo "  DATABASE_URL:     $DATABASE_URL"
echo "  OPERATION:        $OPERATION_LOWER"
echo "  CHANGEREQUEST_ID: $CHANGEREQUEST_ID"
[ "$OPERATION_LOWER" = "rollback" ] && echo "  ROLLBACK_TAG:     $ROLLBACK_TAG"

# ─────────────────────────────────────────────────────────────────────────────
# Dynamic Password Resolution
# Pattern: {ENV}_{IP}_{USERNAME}_PASSWORD
# Example: UAT_10_5_20_213_MULEUSER_PASSWORD
# ─────────────────────────────────────────────────────────────────────────────
DB_PASS_VAR="${ENV_UPPER}_${DB_IP_UNDERSCORE}_${DB_USERNAME_UPPER}_PASSWORD"
DB_PASS=$(printenv "$DB_PASS_VAR" || true)

if [ -z "$DB_PASS" ]; then
  printf "❌ ERROR: Password not found for user '%s' on DB '%s' env '%s'\n" "$DB_USERNAME_UPPER" "$DB_IP" "$ENV_UPPER" >&2
  printf "   Add GoCD secure variable: %s = AES:...\n" "$DB_PASS_VAR" >&2
  printf "   NOTE: Username is entered in UI, password comes only from secure vars\n" >&2
  exit 1
fi

echo "✅ [INFO] Password resolved from GoCD secure variable: $DB_PASS_VAR"

# ─────────────────────────────────────────────────────────────────────────────
# Validate changelog path
# Path: databases/{env}/{env}_{ip}/users/{username}/changelog.xml
# ─────────────────────────────────────────────────────────────────────────────
LIQUIBASE_BASE_DIR=$(pwd)
DATABASES_DIR="$LIQUIBASE_BASE_DIR/../databases"
USER_CHANGELOG_DIR="$DATABASES_DIR/${ENV_LOWER}/${ENV_LOWER}_${DB_IP_UNDERSCORE}/users/${DB_USERNAME_LOWER}"
USER_CHANGELOG="${USER_CHANGELOG_DIR}/changelog.xml"

if [ ! -f "$USER_CHANGELOG" ]; then
  printf "❌ ERROR: No changelog found for user '%s' on DB '%s'\n" "$DB_USERNAME_LOWER" "$DB_IP" >&2
  printf "   Expected: databases/%s/%s_%s/users/%s/changelog.xml\n" \
    "$ENV_LOWER" "$ENV_LOWER" "$DB_IP_UNDERSCORE" "$DB_USERNAME_LOWER" >&2
  exit 1
fi

echo "✅ [INFO] Changelog found: $USER_CHANGELOG"

# ─────────────────────────────────────────────────────────────────────────────
# Docker image
# ─────────────────────────────────────────────────────────────────────────────
LIQUIBASE_DOCKER_IMAGE="sha256:2535553f6424f07b5bd77833f283d983e1a7bc0e6d5012a1ef104811e9c87c30"

# Check for the local test network; warn if not found (do NOT silently skip)
DOCKER_NETWORK_OPT=""
if docker network inspect "$COMPOSE_NETWORK_NAME" > /dev/null 2>&1; then
  DOCKER_NETWORK_OPT="--network $COMPOSE_NETWORK_NAME"
  echo "✅ [INFO] Docker network detected: $COMPOSE_NETWORK_NAME"
else
  echo "⚠️  [WARN] Docker network '$COMPOSE_NETWORK_NAME' not found — running without network attachment."
  echo "           If targeting a local Oracle container, set COMPOSE_NETWORK_NAME or start docker-compose first."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Decide which script to run inside container
# ─────────────────────────────────────────────────────────────────────────────
if [ "$MODE" = "dryrun" ]; then
  if [ "$OPERATION_LOWER" = "rollback" ]; then
    TARGET_SCRIPT="/liquibase_scripts/liquibase-rollback-dryrun.sh"
    echo "🕵️‍♂️  [INFO] DRYRUN → rollbackSQL"
  else
    TARGET_SCRIPT="/liquibase_scripts/liquibase-update-dryrun.sh"
    echo "🕵️‍♂️  [INFO] DRYRUN → updateSQL"
  fi
else
  if [ "$OPERATION_LOWER" = "rollback" ]; then
    TARGET_SCRIPT="/liquibase_scripts/liquibase-rollback.sh"
    echo "↩️  [INFO] EXECUTE → rollback"
  else
    TARGET_SCRIPT="/liquibase_scripts/liquibase-update.sh"
    echo "⚙️  [INFO] EXECUTE → update"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Run docker
# ─────────────────────────────────────────────────────────────────────────────
docker run --rm $DOCKER_NETWORK_OPT \
  --workdir /liquibase_scripts \
  -e DB_URL="$DATABASE_URL" \
  -e DB_USER="$DB_USERNAME_LOWER" \
  -e DB_PASS="$DB_PASS" \
  -e DB_IP_UNDERSCORE="$DB_IP_UNDERSCORE" \
  -e DB_USERNAME_LOWER="$DB_USERNAME_LOWER" \
  -e CHANGEREQUEST_ID="$CHANGEREQUEST_ID" \
  -e ROLLBACK_TAG="$ROLLBACK_TAG" \
  -e OPERATION_LOWER="$OPERATION_LOWER" \
  -e ENVIRONMENT="$ENV_LOWER" \
  -v "$DATABASES_DIR:/liquibase/databases:ro" \
  -v "$LIQUIBASE_BASE_DIR:/liquibase_scripts:ro" \
  "$LIQUIBASE_DOCKER_IMAGE" /bin/sh -c "
    sh $TARGET_SCRIPT '$ENV_LOWER'
  "

echo
echo "============================================================================================================================="
echo "✅ run-liquibase.sh completed — user=$DB_USERNAME_LOWER db=$DB_IP operation=$OPERATION_LOWER mode=$MODE"
echo "============================================================================================================================="