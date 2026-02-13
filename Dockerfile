# syntax=docker/dockerfile:1.7
FROM dhi.io/debian-base:trixie

# Useful directories
WORKDIR /work
RUN mkdir -p /config /data /logs

# Copy the FastTransfer Linux x64 binary (downloaded by CI at repo root)
COPY FastTransfer /usr/local/bin/FastTransfer
RUN chmod 0755 /usr/local/bin/FastTransfer

# OCI Labels
LABEL org.opencontainers.image.title="FastTransfer (CLI) - Runtime Docker Image" \
      org.opencontainers.image.description="Minimal container to run FastTransfer (parallel transfer database to database)" \
      org.opencontainers.image.vendor="Architecture & Performance" \
      org.opencontainers.image.source="https://github.com/aetperf/FastTransfer-Image" \
      org.opencontainers.image.licenses="Proprietary"

VOLUME ["/config", "/data", "/work", "/logs"]

ENTRYPOINT ["/usr/local/bin/FastTransfer"]
