#!/bin/sh
# RAM samples for IPQ807x ~1GB. Cron: */5 * * * * /usr/sbin/mem-watch.sh
#
# The ring lives on tmpfs. Overlay is written only when memory is already
# tight, or when logread shows an OOM, so a healthy router does not wear NAND
# every five minutes. A pressure snapshot includes the recent ring so the
# trend before the dip is still on flash.

RING="${RING:-/tmp/mem-watch.ring}"
PERSIST_DIR="${PERSIST_DIR:-/root/crashlogs}"
PERSIST="${PERSIST:-$PERSIST_DIR/mem-watch.log}"
STAMP="${STAMP:-/tmp/mem-watch.persist.stamp}"
MAX_RING="${MAX_RING:-200}"
MAX_PERSIST="${MAX_PERSIST:-400}"
# kB. Below this, one overlay snapshot per PERSIST_GAP seconds.
PRESSURE_KB="${PRESSURE_KB:-65536}"
PERSIST_GAP="${PERSIST_GAP:-900}"

_trim() {
	local file="$1" max="$2" lines
	[ -f "$file" ] || return 0
	lines=$(wc -l <"$file" 2>/dev/null | tr -d ' ')
	if [ -n "$lines" ] && [ "$lines" -gt "$max" ] 2>/dev/null; then
		tail -n "$max" "$file" >"$file.tmp" 2>/dev/null && mv "$file.tmp" "$file"
	fi
}

avail=$(awk '/^MemAvailable:/{print $2; exit}' /proc/meminfo 2>/dev/null)
oom=$(logread -e 'oom-killer|Out of memory|Killed process|invoked oom' 2>/dev/null | tail -n 5)

{
	echo "----- $(date) -----"
	awk '/^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|SUnreclaim|AnonPages|Shmem):/' /proc/meminfo 2>/dev/null
	echo "top_rss:"
	for p in /proc/[0-9]*; do
		rss=$(awk '/^VmRSS:/{print $2; exit}' "$p/status" 2>/dev/null) || continue
		[ -n "$rss" ] || continue
		[ "$rss" -ge 4000 ] 2>/dev/null || continue
		cmd=$(tr '\0' ' ' <"$p/cmdline" 2>/dev/null | head -c 60)
		[ -n "$cmd" ] || cmd="[$(basename "$p")]"
		printf '  %6s kB  %s\n' "$rss" "$cmd"
	done 2>/dev/null | sort -rn | head -8
	if [ -n "$oom" ]; then
		echo "oom_hints:"
		printf '%s\n' "$oom"
	fi
	echo
} >>"$RING" 2>/dev/null || true

_trim "$RING" "$MAX_RING"

persist_now=0
if [ -n "$oom" ]; then
	persist_now=1
elif [ -n "$avail" ] && [ "$avail" -lt "$PRESSURE_KB" ] 2>/dev/null; then
	now=$(date +%s 2>/dev/null || echo 0)
	last=$(cat "$STAMP" 2>/dev/null || echo 0)
	case "$now" in
		''|*[!0-9]*) now=0 ;;
	esac
	case "$last" in
		''|*[!0-9]*) last=0 ;;
	esac
	if [ $((now - last)) -ge "$PERSIST_GAP" ]; then
		persist_now=1
	fi
fi

if [ "$persist_now" -eq 1 ]; then
	mkdir -p "$PERSIST_DIR" 2>/dev/null || exit 0
	{
		echo "===== persist $(date) avail=${avail:-?}kB ====="
		tail -n 40 "$RING" 2>/dev/null
	} >>"$PERSIST" 2>/dev/null || true
	date +%s >"$STAMP" 2>/dev/null || true
	_trim "$PERSIST" "$MAX_PERSIST"
fi

exit 0
