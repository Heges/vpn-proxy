#!/bin/sh
set -eu

echo "[1/4] starting OpenVPN..."
openvpn --config /vpn/client.ovpn --daemon --writepid /run/openvpn.pid --log /var/log/openvpn.log

echo "[2/4] waiting for tun0..."
i=0
while [ $i -lt 60 ]; do
  if ip addr show tun0 >/dev/null 2>&1; then
    break
  fi
  i=$((i+1))
  sleep 1
done

if ! ip addr show tun0 >/dev/null 2>&1; then
  echo "tun0 did not appear. OpenVPN failed."
  echo "===== openvpn log ====="
  cat /var/log/openvpn.log || true
  exit 1
fi

echo "[3/4] tunnel is up"
ip addr show tun0 || true
ip route || true

echo "[4/4] starting tinyproxy..."
mkdir -p /run/tinyproxy
touch /var/log/tinyproxy/tinyproxy.log

exec tinyproxy -d -c /etc/tinyproxy/tinyproxy.conf