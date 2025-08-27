FROM --platform=$BUILDPLATFORM alpine:3.19 AS base

LABEL maintainer="Nick Haven <nicholaschaven@gmail.com>"
LABEL description="ADB Butler - Android Debug Bridge server with monitoring capabilities"
LABEL version="2.0.0"
LABEL org.opencontainers.image.source="https://github.com/nicholashaven/adb-butler"
LABEL org.opencontainers.image.licenses="Apache-2.0"

ENV PATH=$PATH:/opt/platform-tools
ENV NODE_ENV=production

RUN set -xeo pipefail && \
    apk update && \
    apk add --no-cache \
        wget \
        ca-certificates \
        nodejs \
        npm \
        supervisor \
        dcron \
        bash \
        curl \
        unzip && \
    # Install glibc for better compatibility
    wget -O "/etc/apk/keys/sgerrand.rsa.pub" \
        "https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub" && \
    wget -O "/tmp/glibc.apk" \
        "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-2.35-r1.apk" && \
    wget -O "/tmp/glibc-bin.apk" \
        "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-bin-2.35-r1.apk" && \
    apk add --no-cache --force-overwrite "/tmp/glibc.apk" "/tmp/glibc-bin.apk" && \
    # Clean up
    rm "/etc/apk/keys/sgerrand.rsa.pub" && \
    rm -f "/root/.wget-hsts" && \
    rm -f "/tmp/glibc.apk" "/tmp/glibc-bin.apk" && \
    rm -rf /var/cache/apk/* && \
    # Create necessary directories
    mkdir -m 0750 /root/.android && \
    mkdir -p /etc/supervisord.d && \
    mkdir -p /var/spool/cron/crontabs

RUN npm install --global --production rethinkdb

COPY adb/* /root/.android/
COPY bin/* /
COPY supervisor/supervisord.conf /etc/
COPY cron/root /var/spool/cron/crontabs/root
RUN chmod +x /bootstrap.sh /clean.js /label.js /root/.android/update-platform-tools.sh && \
    # Only install ADB platform tools on x86_64 (Google doesn't provide ARM64 version)
    if [ "$(uname -m)" = "x86_64" ]; then \
        /root/.android/update-platform-tools.sh; \
    else \
        echo "ADB platform tools not available for $(uname -m) architecture"; \
        echo "This image will work for Node.js services but ADB functionality will be limited"; \
    fi

RUN addgroup -g 1000 adbuser && \
    adduser -D -s /bin/bash -u 1000 -G adbuser adbuser && \
    chown -R adbuser:adbuser /root/.android

EXPOSE 5037

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD if [ "$(uname -m)" = "x86_64" ]; then adb version || exit 1; else echo "ADB not available on $(uname -m)" || exit 0; fi

# Use exec form for better signal handling
ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
