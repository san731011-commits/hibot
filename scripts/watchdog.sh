#!/usr/bin/env bash
# watchdog.sh - lightweight OpenClaw watchdog for manual testing
# Run manually for now: bash ./watchdog.sh

SETTINGS_LOG=/tmp/openclaw-watchdog.log
RECOVERY_SCRIPT=/home/san/.openclaw/workspace/scripts/recovery_subagent.sh
GATEWAY_RPC="http://127.0.0.1:18789/" # used only for quick curl check
TIMEOUT=3
TAIL_LINES=50
MAX_RESTART_ATTEMPTS=1

# Model fallback settings
CONFIG_FILE=/home/san/.openclaw/openclaw.json
BACKUP_DIR=/home/san/.openclaw/backup
FALLBACK_MODEL="openai/gpt-5-mini"
ERROR_PATTERNS="uncaught exception|epipe|429|error: write|slow listener"

timestamp(){ date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log(){ echo "$(timestamp) - $*" | tee -a "$SETTINGS_LOG"; }

# Lightweight health checks
check_process(){
  pgrep -a openclaw-gateway >/dev/null 2>&1
}

check_rpc(){
  # Try a short curl to gateway root (loopback). If gateway exposes JSON endpoints, adapt.
  curl --max-time $TIMEOUT -sS "$GATEWAY_RPC" >/dev/null 2>&1
}

check_recent_errors(){
  # Look for recent patterns in the latest log file
  if [ -f /tmp/openclaw/openclaw-2026-02-11.log ]; then
    tail -n $TAIL_LINES /tmp/openclaw/openclaw-2026-02-11.log 2>/dev/null | egrep -i "$ERROR_PATTERNS" >/dev/null 2>&1
    return $?
  fi
  if [ -f /tmp/openclaw/openclaw-2026-02-10.log ]; then
    tail -n $TAIL_LINES /tmp/openclaw/openclaw-2026-02-10.log 2>/dev/null | egrep -i "$ERROR_PATTERNS" >/dev/null 2>&1
    return $?
  fi
  return 1
}

# Recovery action (safe)
attempt_recovery(){
  log "Recovery: running recovery script ($RECOVERY_SCRIPT)"
  if [ -x "$RECOVERY_SCRIPT" ]; then
    bash "$RECOVERY_SCRIPT" | tee -a "$SETTINGS_LOG"
  else
    log "Recovery script not executable or missing: $RECOVERY_SCRIPT"
  fi
}

backup_config(){
  mkdir -p "$BACKUP_DIR"
  ts=$(date +%s)
  cp "$CONFIG_FILE" "$BACKUP_DIR/openclaw.json.bak.$ts" && log "Config backed up to $BACKUP_DIR/openclaw.json.bak.$ts"
}

set_fallback_model(){
  if [ ! -f "$CONFIG_FILE" ]; then
    log "Config file not found: $CONFIG_FILE"
    return 1
  fi
  # backup
  backup_config
  # replace primary model line (best-effort)
  if grep -q '"primary"' "$CONFIG_FILE"; then
    sed -i "s/\("primary"[[:space:]]*:[[:space:]]*\)\"[^\"]*\"/\1\"$FALLBACK_MODEL\"/" "$CONFIG_FILE"
    log "Set fallback primary model to $FALLBACK_MODEL in $CONFIG_FILE"
    return 0
  else
    log "Could not find primary model field in $CONFIG_FILE"
    return 1
  fi
}

reload_gateway(){
  # Try graceful reload via SIGUSR1 (if process present), else use systemctl --user restart
  pid=$(pgrep -f openclaw-gateway | head -n1)
  if [ -n "$pid" ]; then
    log "Sending SIGUSR1 to gateway pid $pid for reload"
    kill -USR1 "$pid" 2>/dev/null && return 0 || log "SIGUSR1 failed"
  fi
  log "Attempting systemctl --user restart openclaw-gateway.service"
  systemctl --user restart openclaw-gateway.service >/dev/null 2>&1 && return 0
  log "systemctl --user restart failed or not available"
  return 1
}

# Main
log "watchdog: start"

ok=1
if ! check_process; then
  log "watchdog: openclaw-gateway process not found"
  ok=0
fi

if ! check_rpc; then
  log "watchdog: RPC probe failed (timeout=${TIMEOUT}s)"
  ok=0
fi

if check_recent_errors; then
  log "watchdog: recent error patterns detected in logs"
  ok=0
fi

if [ $ok -eq 1 ]; then
  log "watchdog: healthy"
  exit 0
fi

log "watchdog: problem detected -> running recovery attempt(s)"

# First attempt recovery script
attempt=0
while [ $attempt -lt $MAX_RESTART_ATTEMPTS ]; do
  attempt=$((attempt+1))
  log "watchdog: recovery attempt #$attempt"
  attempt_recovery
  sleep 2
  if check_process && check_rpc; then
    log "watchdog: recovery succeeded"
    exit 0
  fi
done

# If still unhealthy and errors indicate model/provider issues (429), attempt model fallback
if check_recent_errors; then
  log "watchdog: attempting model fallback to $FALLBACK_MODEL"
  if set_fallback_model; then
    if reload_gateway; then
      log "watchdog: fallback applied and gateway reloaded, verifying"
      sleep 2
      if check_process && check_rpc; then
        log "watchdog: fallback recovery succeeded"
        exit 0
      else
        log "watchdog: fallback applied but gateway not healthy after reload"
      fi
    else
      log "watchdog: failed to reload gateway after setting fallback model"
    fi
  else
    log "watchdog: failed to set fallback model"
  fi
fi

log "watchdog: recovery attempts exhausted or failed. Manual intervention recommended."
# leave recovery report(s) under /home/san/.openclaw/workspace/scripts/
exit 1
