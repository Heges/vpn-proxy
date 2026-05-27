#!/bin/sh
set -eu

OPENVPN_CONFIG="/vpn/client.ovpn"
OPENVPN_PID_FILE="/run/openvpn.pid"
OPENVPN_LOG="/var/log/openvpn.log"

TINYPROXY_CONFIG="/etc/tinyproxy/tinyproxy.conf"
TINYPROXY_LOG="/var/log/tinyproxy/tinyproxy.log"

CHECK_URL="https://api.ipify.org"
CHECK_INTERVAL_SECONDS="30"
CHECK_CONNECT_TIMEOUT_SECONDS="5"
CHECK_MAX_TIME_SECONDS="15"

cleanup() {
  echo "[cleanup] stopping services..."

  if [ -n "${TINYPROXY_PID:-}" ] && kill -0 "$TINYPROXY_PID" >/dev/null 2>&1; then
    kill "$TINYPROXY_PID" >/dev/null 2>&1 || true
  fi

  if [ -f "$OPENVPN_PID_FILE" ]; then
    OPENVPN_PID="$(cat "$OPENVPN_PID_FILE" || true)"
    if [ -n "$OPENVPN_PID" ] && kill -0 "$OPENVPN_PID" >/dev/null 2>&1; then
      kill "$OPENVPN_PID" >/dev/null 2>&1 || true
    fi
  fi
}

fail_and_exit() {
  echo "[fatal] $1"

  echo "===== ip addr ====="
  ip -br addr || true

  echo "===== ip route ====="
  ip route || true

  echo "===== openvpn log ====="
  tail -n 120 "$OPENVPN_LOG" || true

  echo "===== tinyproxy log ====="
  tail -n 120 "$TINYPROXY_LOG" || true

  cleanup
  exit 1
}

trap cleanup INT TERM

mkdir -p /run/tinyproxy /run/openvpn /var/log/tinyproxy
touch "$OPENVPN_LOG" "$TINYPROXY_LOG"
chown -R nobody:nogroup /run/tinyproxy /var/log/tinyproxy || true

echo "[1/6] starting log forwarder..."
tail -F "$OPENVPN_LOG" "$TINYPROXY_LOG" &
LOG_TAIL_PID="$!"

echo "[2/6] validating OpenVPN config..."
if [ ! -f "$OPENVPN_CONFIG" ]; then
  fail_and_exit "OpenVPN config was not found: $OPENVPN_CONFIG"
fi

echo "[3/6] starting OpenVPN..."
openvpn \
  --config "$OPENVPN_CONFIG" \
  --daemon \
  --writepid "$OPENVPN_PID_FILE" \
  --log "$OPENVPN_LOG"

echo "[4/6] waiting for tun0..."
i=0
while [ "$i" -lt 60 ]; do
  if ip addr show tun0 >/dev/null 2>&1; then
    break
  fi

  if [ -f "$OPENVPN_PID_FILE" ]; then
    OPENVPN_PID="$(cat "$OPENVPN_PID_FILE" || true)"
    if [ -n "$OPENVPN_PID" ] && ! kill -0 "$OPENVPN_PID" >/dev/null 2>&1; then
      fail_and_exit "OpenVPN process died while waiting for tun0"
    fi
  fi

  i=$((i + 1))
  sleep 1
done

if ! ip addr show tun0 >/dev/null 2>&1; then
  fail_and_exit "tun0 did not appear"
fi

echo "[5/6] tunnel is up"
ip -br addr || true
ip route || true

echo "[6/6] starting tinyproxy..."
tinyproxy -d -c "$TINYPROXY_CONFIG" &
TINYPROXY_PID="$!"

sleep 2

if ! kill -0 "$TINYPROXY_PID" >/dev/null 2>&1; then
  fail_and_exit "tinyproxy failed to start"
fi

echo "[ready] proxy is listening on 0.0.0.0:8888"

while true; do
  if ! kill -0 "$TINYPROXY_PID" >/dev/null 2>&1; then
    fail_and_exit "tinyproxy process is dead"
  fi

  if [ ! -f "$OPENVPN_PID_FILE" ]; then
    fail_and_exit "OpenVPN pid file is missing"
  fi

  OPENVPN_PID="$(cat "$OPENVPN_PID_FILE" || true)"
  if [ -z "$OPENVPN_PID" ]; then
    fail_and_exit "OpenVPN pid file is empty"
  fi

  if ! kill -0 "$OPENVPN_PID" >/dev/null 2>&1; then
    fail_and_exit "OpenVPN process is dead"
  fi

  if ! ip addr show tun0 >/dev/null 2>&1; then
    fail_and_exit "tun0 disappeared"
  fi

  if ! ip route get 1.1.1.1 | grep -q "dev tun0"; then
    fail_and_exit "default traffic is not routed through tun0"
  fi

  if ! curl \
      --interface tun0 \
      -fsS \
      --connect-timeout "$CHECK_CONNECT_TIMEOUT_SECONDS" \
      --max-time "$CHECK_MAX_TIME_SECONDS" \
      "$CHECK_URL" >/dev/null; then
    fail_and_exit "tun0 connectivity check failed"
  fi

  sleep "$CHECK_INTERVAL_SECONDS"
done