#!/bin/sh
set -e

echo "============================================================================================================================="
echo "============================================     Starting liquibase-update-dryrun.sh      ============================================="
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
# NOTE: CHANGEREQUEST_ID is NOT required here — dryrun only previews SQL, does not tag.
#       For update operations it will be set; for rollback dryruns it will be empty — both are valid.

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
echo "GoCD Pipeline — liquibase-update-dryrun.sh"
echo "  DB URL:           $DB_URL"
echo "  DB Username:      $DB_USER"
echo "  CHANGEREQUEST_ID: ${CHANGEREQUEST_ID:-(not set — rollback dryrun)}"
echo "  Changelog:        $CHANGELOG_DIR/$CHANGELOG_FILE"
echo

cd "$CHANGELOG_DIR" || exit 1

echo "📄 ─────────────────────────────────────────────>> STATUS before dryrun"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" status --verbose

echo "🔍 ─────────────────────────────────────────────>> VALIDATE"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" validate

echo
echo "🕵️‍♂️ ─────────────────────────────────────────────>> DRY RUN (updateSQL)"
"$LIQUIBASE_BIN" --defaultsFile="$LB_PROPS" updateSQL

echo
echo "============================================================================================================================="
echo "✅ liquibase-update-dryrun.sh completed [user=$DB_USERNAME_LOWER]"
echo "============================================================================================================================="