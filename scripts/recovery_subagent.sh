#!/usr/bin/env bash
# recovery_subagent.sh - lightweight recovery helper for OpenClaw
# Usage: run manually or via a supervisor when main agent is unresponsive
LOG=/tmp/openclaw/openclaw-$(date +%F).log
OUT=/home/san/.openclaw/workspace/scripts/recovery_report_$(date +%s).txt

echo "Collecting last 200 lines of OpenClaw log..." > "$OUT"
sudo tail -n 200 /tmp/openclaw/openclaw-$(date +%F).log >> "$OUT" 2>/dev/null || tail -n 200 /tmp/openclaw/openclaw-2026-02-10.log >> "$OUT"

echo "\nChecking gateway status (systemd --user)..." >> "$OUT"
systemctl --user status openclaw-gateway.service >> "$OUT" 2>&1 || echo "systemctl --user status failed or not available" >> "$OUT"

echo "\nAttempting graceful restart of gateway (user service)..." >> "$OUT"
if systemctl --user restart openclaw-gateway.service; then
  echo "Restart succeeded" >> "$OUT"
else
  echo "Restart failed; will not attempt further restarts automatically" >> "$OUT"
fi

echo "\nCurrent openclaw processes:" >> "$OUT"
ps aux | grep openclaw | grep -v grep >> "$OUT"

echo "Recovery report written to $OUT"

# Optional: print to stdout for interactive runs
cat "$OUT"
