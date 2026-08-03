#!/bin/sh
# Refresh AdGuard Home filter lists via HTTP API.
# Credentials: optional /etc/adguardhome/api.env (mode 600) — never commit secrets.
#
#   AGH_URL=http://127.0.0.1:8081
#   AGH_AUTH_HEADER='Authorization: Basic <base64>'
#
# Or set AGH_USER / AGH_PASS and this script builds Basic auth.
# Cron example: 15 4 * * * /etc/adguardhome/filter-refresh.sh

set -e
ENV_FILE="${ENV_FILE:-/etc/adguardhome/api.env}"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

AGH_URL="${AGH_URL:-http://127.0.0.1:8081}"
LOG="${LOG:-/tmp/agh_filter_refresh.log}"

if [ -z "${AGH_AUTH_HEADER:-}" ]; then
	if [ -n "${AGH_USER:-}" ] && [ -n "${AGH_PASS:-}" ]; then
		# busybox base64
		b64=$(printf '%s:%s' "$AGH_USER" "$AGH_PASS" | base64 | tr -d '\n')
		AGH_AUTH_HEADER="Authorization: Basic $b64"
	else
		echo "filter-refresh: set AGH_AUTH_HEADER or AGH_USER/AGH_PASS in $ENV_FILE" >&2
		exit 1
	fi
fi

{
	echo "[$(date)] filter refresh start"
	# wait for API (max ~2 min)
	i=0
	while [ "$i" -lt 24 ]; do
		code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 \
			-H "$AGH_AUTH_HEADER" "$AGH_URL/control/status" || echo 000)
		[ "$code" = "200" ] && break
		i=$((i + 1))
		sleep 5
	done
	if [ "${code:-000}" != "200" ]; then
		echo "[$(date)] AGH API not ready (last=$code)"
		exit 1
	fi
	curl -sS -H "Content-Type: application/json" -H "$AGH_AUTH_HEADER" \
		-d '{"whitelist":false}' \
		"$AGH_URL/control/filtering/refresh" || true
	echo "[$(date)] filter refresh done"
} >>"$LOG" 2>&1
