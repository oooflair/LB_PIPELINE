#!/bin/sh
set -e

echo "============================================================================================================================="
echo "============================================     Starting liquibase-rollback.sh      ============================================="
echo "============================================================================================================================="

ENV_ARG=${1:-}
if [ -n "$ENV_ARG" ]; then ENVIRONMENT="$ENV_ARG"; else ENVIRONMENT=${ENVIRONMENT:-}; fi
if [ -z "$ENVIRONMENT" ]; then echo "❌ ERROR: ENVIRONMENT required"; exit 1; fi
if [ -z "${ROLLBACK_TAG:-}" ]; then
  echo "❌ ERROR: ROLLBACK_TAG required"; exit 1
fi

ENV_LOWER=$(printf '%s' "$ENVIRONMENT" | awk '{print tolower($0)}')

: "${DB_URL:?Missing DB_URL}"
: "${DB_USER:?Missing DB_USER}"
: "${DB_PASS:?Missing DB_PASS}"
: "${DB_IP_UNDERSCORE:?Missing DB_IP_UNDERSCORE}"
: "${DB_USERNAME_LOWER:?Missing DB_USERNAME_LOWER}"

CHANGELOG_DIR="/liquibase/databases/${ENV_LOWER}/${ENV_LOWER}_${DB_IP_UNDERSCORE}/users/${DB_USERNAME_LOWER}"
CHANGELOG_FILE="changelog.xml"

if [ ! -f "$CHANGELOG_DIR/$CHANGELOG_FILE" ]; then
  echo "❌ ERROR: Changelog missing: $CHANGELOG_DIR/$CHANGELOG_FILE"
  exit 1
fi

LIQUIBASE_BIN=$(command -v liquibase || find / -type f -name liquibase 2>/dev/null | head -n 1 || true)
if [ -z "$LIQUIBASE_BIN" ]; then echo "❌ [ERROR] Liquibase binary not found!"; exit 1; fi

# ─────────────────────────────────────────────────────────────────────────────
# Write credentials to a temp properties file to avoid password in process list
# or Liquibase error output. Cleaned up unconditionally via trap.
# ─────────────────────────────────────────────────────────────────────────────
LB_PROPS=$(mktemp /tmp/liquibase-XXXXXX.properties)
trap 'rm -f "$LB_PROPS"' EXIT INT TERM
chmod 600 "$LB_PROPS"
cat > "$LB_PROPS" <<PROPS
driver=oracle.jdbc.OracleDriver
url=${DB_URL}
username=${DB_USER}
password=${DB_PASS}
changeLogFile=${CHANGELOG_FILE}
PROPS

echo
echo "GoCD Pipeline — liquibase-rollback.sh"
echo "  DB URL:       $DB_URL"
echo "  DB Username:  $DB_USER"
echo "  ROLLBACK_TAG: $ROLLBACK_TAG"
echo "  Changelog:    $CHANGELOG_DIR/$CHANGELOG_FILE"
echo

cd "$CHANGELOG_DIR" || exit 1

echo "📜 ─────────────────────────────────────────────>> HISTORY before rollback"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" history

echo
echo "🏷️  ─────────────────────────────────────────────>> TAG: PRE_ROLLBACK_${ROLLBACK_TAG} (safety snapshot)"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" tag "PRE_ROLLBACK_${ROLLBACK_TAG}"

echo
echo "↩️  ─────────────────────────────────────────────>> ROLLBACK to tag: $ROLLBACK_TAG"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" rollback "$ROLLBACK_TAG"

echo
echo "📜 ─────────────────────────────────────────────>> HISTORY after rollback"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" history

echo
echo "============================================================================================================================="
echo "✅ liquibase-rollback.sh completed [user=$DB_USERNAME_LOWER]"
echo "============================================================================================================================="