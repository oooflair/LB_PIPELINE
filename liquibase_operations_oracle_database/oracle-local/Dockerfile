FROM gvenzl/oracle-xe:latest

USER root

RUN mkdir -p /opt/oracle/scripts/setup /opt/oracle/scripts/startup

COPY init-users.sql /opt/oracle/scripts/setup/init-users.sql
COPY healthcheck.sh /opt/oracle/healthcheck.sh

RUN chmod +x /opt/oracle/healthcheck.sh

USER oracle

HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=10 \
  CMD /opt/oracle/healthcheck.sh