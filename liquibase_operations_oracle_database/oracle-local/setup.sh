#!/bin/bash
set -u

ORACLE_IMAGE="gvenzl/oracle-xe:latest"
SYS_PASSWORD="Oracle123"
NETWORK_NAME="liquibase_operations_oracle_database_lb_test_net"
SUBNET_CIDR="172.25.0.0/24"

DBS=(
  "172.25.0.10|oracle-uat10|15210|UAT"
  "172.25.0.11|oracle-uat11|15211|UAT"
  "172.25.0.20|oracle-prod20|15220|PROD"
  "172.25.0.21|oracle-prod21|15221|PROD"
)

get_passwords() {
  local ip="$1"
  case "$ip" in
    172.25.0.10) echo "uat\$#muleuser10|uat#\$tibcouser10|uat#\$javauser10" ;;
    172.25.0.11) echo "uat#\$muleuser11|uat#\$tibcouser11|uat#\$javauser11" ;;
    172.25.0.20) echo "prod\$#muleuser20|prod#\$tibcouser20|prod#\$javauser20" ;;
    172.25.0.21) echo "prod\$#muleuser21|prod\$#tibcouser21|prod#\$javauser21" ;;
    *) echo "ERROR|ERROR|ERROR" ;;
  esac
}

echo "======================================================================================"
echo "🚀 Starting full Oracle multi-DB setup"
echo "======================================================================================"

echo
echo "🧹 Cleaning old containers..."
for db in "${DBS[@]}"; do
  IFS='|' read -r IP CONTAINER PORT ENV <<< "$db"
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
done
docker network rm "$NETWORK_NAME" >/dev/null 2>&1 || true

echo
echo "🌐 Creating Docker network: $NETWORK_NAME ($SUBNET_CIDR)"
docker network create --subnet="$SUBNET_CIDR" "$NETWORK_NAME" >/dev/null

echo
echo "🐳 Starting Oracle XE containers..."
for db in "${DBS[@]}"; do
  IFS='|' read -r IP CONTAINER PORT ENV <<< "$db"

  docker run -d \
    --name "$CONTAINER" \
    --platform linux/amd64 \
    --network "$NETWORK_NAME" \
    --ip "$IP" \
    -p "$PORT:1521" \
    -e ORACLE_PASSWORD="$SYS_PASSWORD" \
    "$ORACLE_IMAGE" >/dev/null

  echo "   ✅ $CONTAINER started at $IP (host port: $PORT)"
done

echo
echo "⏳ Waiting for all Oracle DBs to be ready..."
for db in "${DBS[@]}"; do
  IFS='|' read -r IP CONTAINER PORT ENV <<< "$db"
  echo "   ⏳ Waiting for $CONTAINER ($IP)..."

  until docker exec "$CONTAINER" bash -lc \
    "echo \"SELECT name, open_mode FROM v\\\$pdbs;\" | sqlplus -s \"sys/$SYS_PASSWORD@localhost:1521/XE as sysdba\" | grep -q READ"
  do
    sleep 10
  done

  echo "   ✅ $CONTAINER is ready"
done

echo
echo "👤 Creating application users in each DB..."
for db in "${DBS[@]}"; do
  IFS='|' read -r IP CONTAINER PORT ENV <<< "$db"
  IFS='|' read -r MULE_PASS TIBCO_PASS JAVA_PASS <<< "$(get_passwords "$IP")"

  echo "   🔧 Configuring users in $CONTAINER ($IP)..."

  docker exec -i "$CONTAINER" sqlplus -s "sys/$SYS_PASSWORD@localhost:1521/XE as sysdba" <<EOF || echo "   ❌ User creation failed in $CONTAINER"
ALTER SESSION SET CONTAINER = XEPDB1;

CREATE USER muleuser IDENTIFIED BY "$MULE_PASS";
GRANT CONNECT, RESOURCE TO muleuser;
ALTER USER muleuser QUOTA UNLIMITED ON USERS;

CREATE USER tibcouser IDENTIFIED BY "$TIBCO_PASS";
GRANT CONNECT, RESOURCE TO tibcouser;
ALTER USER tibcouser QUOTA UNLIMITED ON USERS;

CREATE USER javauser IDENTIFIED BY "$JAVA_PASS";
GRANT CONNECT, RESOURCE TO javauser;
ALTER USER javauser QUOTA UNLIMITED ON USERS;

EXIT;
EOF

  echo "   ✅ Done for $CONTAINER"
done

echo
echo "======================================================================================"
echo "🎉 ALL DATABASES SUMMARY"
echo "======================================================================================"

for db in "${DBS[@]}"; do
  IFS='|' read -r IP CONTAINER PORT ENV <<< "$db"
  IFS='|' read -r MULE_PASS TIBCO_PASS JAVA_PASS <<< "$(get_passwords "$IP")"

  echo
  echo "DB: $IP ($ENV)"
  echo "  Container:   $CONTAINER"
  echo "  Host Port:   $PORT"
  echo "  JDBC URL:    jdbc:oracle:thin:@//$IP:1521/XEPDB1"
  echo "  Host JDBC:   jdbc:oracle:thin:@//localhost:$PORT/XEPDB1"
  echo "  muleuser  / $MULE_PASS"
  echo "  tibcouser / $TIBCO_PASS"
  echo "  javauser  / $JAVA_PASS"
done

echo
echo "======================================================================================"
echo "🧪 TEST COMMANDS"
echo "======================================================================================"
echo
echo "From host (Mac):"
for db in "${DBS[@]}"; do
  IFS='|' read -r IP CONTAINER PORT ENV <<< "$db"
  echo "  docker exec -it $CONTAINER bash"
  echo "  sqlplus sys/$SYS_PASSWORD@localhost:1521/XEPDB1 as sysdba"
  echo
done

echo "======================================================================================"
echo "✅ Setup finished"
echo "======================================================================================"