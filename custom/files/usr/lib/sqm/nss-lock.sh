#!/bin/sh
# Serialize sqm-nss-defer and the detached 99-sqm-enabled worker.
# A dead holder is stolen, so a killed hotplug cannot block SQM until reboot.

NSS_SQM_LOCK=/var/lock/sqm-nss.lockdir

nss_sqm_lock() {
	local pid

	[ "$NSS_SQM_LOCK" = "/var/lock/sqm-nss.lockdir" ] || return 1
	mkdir -p /var/lock 2>/dev/null || true
	if mkdir "$NSS_SQM_LOCK" 2>/dev/null; then
		echo $$ >"$NSS_SQM_LOCK/pid"
		return 0
	fi
	pid=$(cat "$NSS_SQM_LOCK/pid" 2>/dev/null)
	if [ -n "$pid" ] && [ "$pid" = "$$" ]; then
		return 0
	fi
	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		return 1
	fi
	rm -rf "$NSS_SQM_LOCK"
	mkdir "$NSS_SQM_LOCK" 2>/dev/null || return 1
	echo $$ >"$NSS_SQM_LOCK/pid"
	return 0
}

nss_sqm_lock_wait() {
	local i=0

	while [ "$i" -lt 30 ]; do
		nss_sqm_lock && return 0
		sleep 1
		i=$((i + 1))
	done
	logger -t sqm-nss "lock busy, skipping"
	return 1
}

nss_sqm_unlock() {
	local pid

	[ "$NSS_SQM_LOCK" = "/var/lock/sqm-nss.lockdir" ] || return 0
	[ -d "$NSS_SQM_LOCK" ] || return 0
	pid=$(cat "$NSS_SQM_LOCK/pid" 2>/dev/null)
	[ "$pid" = "$$" ] || return 0
	rm -rf "$NSS_SQM_LOCK"
}
