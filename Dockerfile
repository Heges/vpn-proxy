FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    openvpn \
    tinyproxy \
    dumb-init \
    iproute2 \
    iputils-ping \
    curl \
    ca-certificates \
    procps \
    sed \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

COPY tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
COPY entrypoint.sh /entrypoint.sh

RUN sed -i 's/\r$//' /entrypoint.sh \
 && sed -i 's/\r$//' /etc/tinyproxy/tinyproxy.conf \
 && chmod +x /entrypoint.sh \
 && mkdir -p /var/log/tinyproxy /run/tinyproxy /run/openvpn \
 && chown -R nobody:nogroup /var/log/tinyproxy /run/tinyproxy \
 && touch /var/log/tinyproxy/tinyproxy.log \
 && touch /var/log/openvpn.log \
 && chown nobody:nogroup /var/log/tinyproxy/tinyproxy.log

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/entrypoint.sh"]