#!/bin/sh
# Push router status to Uptime Kuma (push monitor).
# Cron: * * * * * /usr/sbin/status-push.sh
# Config: /etc/config/status_push → status_push.main.url

set -e

if [ -n "${STATUS_PUSH_URL:-}" ]; then
	BASE="$STATUS_PUSH_URL"
elif command -v uci >/dev/null 2>&1; then
	en=$(uci -q get status_push.main.enabled 2>/dev/null || echo 1)
	[ "$en" = "0" ] && exit 0
	BASE=$(uci -q get status_push.main.url 2>/dev/null || true)
fi
[ -n "$BASE" ] || exit 0

HOST=$(echo "$BASE" | sed -n 's|^https\?://\([^/]*\).*|\1|p')
[ -n "$HOST" ] || HOST="status.aykc.cloud"

PING_MS=""
if command -v ping >/dev/null 2>&1; then
	GW=$(ip -4 route show default 2>/dev/null | awk '/default/ {print $3; exit}')
	TGT="${GW:-1.1.1.1}"
	PING_MS=$(ping -c1 -W2 "$TGT" 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p' | head -1)
fi

resolve_a() {
	local ip=""
	if command -v nslookup >/dev/null 2>&1; then
		ip=$(nslookup "$HOST" 127.0.0.1 2>/dev/null | awk '/^Address: / && $2 !~ /#/ && $2 ~ /^[0-9.]+$/ {print $2; exit}')
		[ -z "$ip" ] && ip=$(nslookup "$HOST" 127.0.0.1 2>/dev/null | awk '/Address/ && $NF ~ /^[0-9]+\.[0-9]+\./ {print $NF; exit}')
		[ -z "$ip" ] && ip=$(nslookup "$HOST" 1.1.1.1 2>/dev/null | awk '/^Address: / && $2 !~ /#/ && $2 ~ /^[0-9.]+$/ {print $2; exit}')
	fi
	echo "$ip"
}

IP=$(resolve_a)
URL="${BASE}?status=up&msg=OK&ping=${PING_MS}"
CURL_OPTS="-fsS --max-time 12 --retry 1"
if [ -n "$IP" ]; then
	curl $CURL_OPTS --resolve "${HOST}:443:${IP}" "$URL" >/dev/null
else
	curl $CURL_OPTS "$URL" >/dev/null
fi
