#!/bin/sh
# Refresh AdGuard Home filter lists via HTTP API.
# Credentials: optional /etc/adguardhome/api.env (mode 600) — never commit secrets.
#
#   AGH_URL=http://127.0.0.1:8081
#   AGH_AUTH_HEADER='Authorization: Basic <base64>'
#
# Or set AGH_USER / AGH_PASS and this script builds Basic auth.
# Cron example: 0 20 * * * /etc/adguardhome/filter-refresh.sh
#
# Restarts AdGuard Home BEFORE and AFTER each refresh so RSS/cache from
# large filter loads is released (tmpfs work_dir + big lists).

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

wait_agh_api() {
	local label="$1" i=0 code=000
	while [ "$i" -lt 24 ]; do
		code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 \
			-H "$AGH_AUTH_HEADER" "$AGH_URL/control/status" 2>/dev/null || echo 000)
		[ "$code" = "200" ] && return 0
		i=$((i + 1))
		sleep 5
	done
	echo "[$(date)] AGH API not ready after $label (last=$code)"
	return 1
}

agh_restart() {
	local why="$1"
	echo "[$(date)] AGH restart ($why) — drop RAM"
	if [ -x /etc/init.d/adguardhome ]; then
		/etc/init.d/adguardhome restart 2>/dev/null || true
	else
		killall -q AdGuardHome 2>/dev/null || true
	fi
	# settle before API polls
	sleep 3
}

{
	echo "[$(date)] filter refresh start"
	# ensure process/API up first (boot path / cron)
	wait_agh_api "initial" || exit 1

	agh_restart "before filter refresh"
	wait_agh_api "post-restart-before" || exit 1

	curl -sS -H "Content-Type: application/json" -H "$AGH_AUTH_HEADER" \
		-d '{"whitelist":false}' \
		"$AGH_URL/control/filtering/refresh" || true
	echo "[$(date)] filter refresh API call finished"

	agh_restart "after filter refresh"
	wait_agh_api "post-restart-after" || exit 1

	echo "[$(date)] filter refresh done"
} >>"$LOG" 2>&1
