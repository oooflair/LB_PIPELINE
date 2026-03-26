#!/bin/sh
set -e

echo "============================================================================================================================="
echo "============================================     Starting liquibase-update.sh      ============================================="
echo "============================================================================================================================="

ENV_ARG=${1:-}
if [ -n "$ENV_ARG" ]; then ENVIRONMENT="$ENV_ARG"; else ENVIRONMENT=${ENVIRONMENT:-}; fi
if [ -z "$ENVIRONMENT" ]; then echo "❌ ERROR: ENVIRONMENT not provided"; exit 1; fi
ENV_LOWER=$(printf '%s' "$ENVIRONMENT" | awk '{print tolower($0)}')

: "${DB_URL:?Missing DB_URL}"
: "${DB_USER:?Missing DB_USER}"
: "${DB_PASS:?Missing DB_PASS}"
: "${DB_IP_UNDERSCORE:?Missing DB_IP_UNDERSCORE}"
: "${DB_USERNAME_LOWER:?Missing DB_USERNAME_LOWER}"
: "${CHANGEREQUEST_ID:?Missing CHANGEREQUEST_ID}"

CHANGELOG_DIR="/liquibase/databases/${ENV_LOWER}/${ENV_LOWER}_${DB_IP_UNDERSCORE}/users/${DB_USERNAME_LOWER}"
CHANGELOG_FILE="changelog.xml"

if [ ! -f "$CHANGELOG_DIR/$CHANGELOG_FILE" ]; then
  echo "❌ ERROR: Missing changelog: $CHANGELOG_DIR/$CHANGELOG_FILE"
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
echo "GoCD Pipeline — liquibase-update.sh"
echo "  DB URL:           $DB_URL"
echo "  DB Username:      $DB_USER"
echo "  CHANGEREQUEST_ID: $CHANGEREQUEST_ID"
echo "  Changelog:        $CHANGELOG_DIR/$CHANGELOG_FILE"
echo

cd "$CHANGELOG_DIR" || exit 1

echo "📄 ─────────────────────────────────────────────>> STATUS before update"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" status --verbose

echo
echo "📜 ─────────────────────────────────────────────>> HISTORY before update"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" history

echo
echo "🏷️  ─────────────────────────────────────────────>> TAG: $CHANGEREQUEST_ID"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" tag "$CHANGEREQUEST_ID"

echo
echo "⚙️  ─────────────────────────────────────────────>> UPDATE"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" update

echo
echo "📄 ─────────────────────────────────────────────>> STATUS after update"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" status --verbose

echo
echo "📜 ─────────────────────────────────────────────>> HISTORY after update"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" history

echo
echo "============================================================================================================================="
echo "✅ liquibase-update.sh completed [user=$DB_USERNAME_LOWER]"
echo "============================================================================================================================="