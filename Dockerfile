# Stage 1 — minimal setup of a base NiFi filesystem (if needed)
FROM eclipse-temurin:17-jre-jammy AS base
RUN useradd --no-create-home --shell /bin/false nifi
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Stage 2 — final lightweight image
FROM eclipse-temurin:17-jre-jammy

# Copy nifi user from base stage
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group
COPY --from=base /etc/ssl/certs /etc/ssl/certs

# Copy your prebuilt NiFi (from Jenkins docker context)
COPY nifi-bin/ /opt/nifi/

RUN chown -R nifi:nifi /opt/nifi

USER nifi

ENV NIFI_HOME=/opt/nifi \
    PATH=$NIFI_HOME/bin:$PATH \
    NIFI_WEB_HTTP_PORT=8080

EXPOSE 8080
ENTRYPOINT ["/opt/nifi/bin/nifi.sh", "run"]