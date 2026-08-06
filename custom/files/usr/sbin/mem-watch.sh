#!/bin/sh
# Lightweight RAM pressure logger → overlay (/root/crashlogs).
# Complements pstore (kernel OOM/panic): this captures userspace trend before death.
#
# Cron (enabled by uci-defaults): */5 * * * * /usr/sbin/mem-watch.sh

set -e
LOG_DIR="${LOG_DIR:-/root/crashlogs}"
LOG="${LOG:-$LOG_DIR/mem-watch.log}"
MAX_LINES="${MAX_LINES:-800}"

mkdir -p "$LOG_DIR"

{
	echo "----- $(date) -----"
	grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|SUnreclaim|AnonPages|Shmem):' /proc/meminfo
	# Top RSS processes (VmRSS kB)
	echo "top_rss:"
	for p in /proc/[0-9]*; do
		rss=$(awk '/^VmRSS:/{print $2}' "$p/status" 2>/dev/null) || continue
		[ -n "$rss" ] || continue
		[ "$rss" -ge 4000 ] 2>/dev/null || continue
		cmd=$(tr '\0' ' ' <"$p/cmdline" 2>/dev/null | head -c 60)
		[ -n "$cmd" ] || cmd="[$(basename "$p")]"
		printf '  %6s kB  %s\n' "$rss" "$cmd"
	done 2>/dev/null | sort -rn | head -8
	# Kernel/logd OOM hints since last boot (ring buffer)
	hits=$(logread 2>/dev/null | grep -iE 'oom-killer|Out of memory|Killed process|invoked oom' | tail -5)
	if [ -n "$hits" ]; then
		echo "oom_hints:"
		echo "$hits"
	fi
	echo
} >>"$LOG" 2>/dev/null || true

# Rotate: keep last MAX_LINES
if [ -f "$LOG" ]; then
	lines=$(wc -l <"$LOG" 2>/dev/null | tr -d ' ')
	if [ -n "$lines" ] && [ "$lines" -gt "$MAX_LINES" ] 2>/dev/null; then
		tail -n "$MAX_LINES" "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
	fi
fi

exit 0
