#!/bin/bash
echo "SELECT 1 FROM dual;" | sqlplus -s system/${ORACLE_PASSWORD}@localhost:1521/XEPDB1 | grep -q 1