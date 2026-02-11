#!/usr/bin/env bash
# tpm_monitor.sh - Monitor token usage and trigger cooldown if approaching limits
# Supports different TPM limits per model provider

LOG_FILE=/tmp/openclaw/openclaw-$(date +%Y-%m-%d).log
STATE_FILE=/tmp/openclaw-tpm-state.json
COOLDOWN_FILE=/tmp/openclaw-tpm-cooldown.lock
CONFIG_FILE=/home/san/.openclaw/openclaw.json
COOLDOWN_SECONDS=30
ALERT_WEBHOOK=""  # Optional: Discord webhook for alerts

# TPM Limits by model provider
KIMI_MAX_TPM=1900000      # Kimi K2.5: 1.9 million TPM
DEFAULT_MAX_TPM=800000    # Gemini, ChatGPT: 800K TPM

# Function to detect current primary model
get_current_model(){
    if [ -f "$CONFIG_FILE" ]; then
        grep -oP '"primary"[[:space:]]*:[[:space:]]*"\K[^"]+' "$CONFIG_FILE" | head -1
    else
        echo "unknown"
    fi
}

# Function to get TPM limit based on model
get_tpm_limit(){
    model=$1
    if echo "$model" | grep -qi "kimi"; then
        echo $KIMI_MAX_TPM
    else
        echo $DEFAULT_MAX_TPM
    fi
}

# Function to extract token usage from logs (approximate)
get_recent_token_usage(){
    # Look for token usage patterns in recent logs (last 60 seconds)
    if [ -f "$LOG_FILE" ]; then
        # This is an approximation based on log patterns
        tail -n 1000 "$LOG_FILE" 2>/dev/null | grep -oP 'tokens[[:space:]]*[=:][[:space:]]*\K[0-9]+' | awk '{sum+=$1} END {print sum+0}'
    else
        echo 0
    fi
}

# Function to check cooldown status
check_cooldown(){
    if [ -f "$COOLDOWN_FILE" ]; then
        cooldown_end=$(cat "$COOLDOWN_FILE")
        now=$(date +%s)
        if [ "$now" -lt "$cooldown_end" ]; then
            remaining=$((cooldown_end - now))
            echo "COOLDOWN_ACTIVE:$remaining"
            return 0
        else
            rm -f "$COOLDOWN_FILE"
        fi
    fi
    echo "COOLDOWN_INACTIVE"
    return 1
}

# Function to activate cooldown
activate_cooldown(){
    limit=$1
    cooldown_end=$(( $(date +%s) + COOLDOWN_SECONDS ))
    echo "$cooldown_end" > "$COOLDOWN_FILE"
    echo "$(date -Iseconds) - TPM COOLDOWN ACTIVATED: Token usage near limit ${limit}. Blocking new requests for ${COOLDOWN_SECONDS}s" >> /tmp/openclaw-tpm.log
    
    # Send alert if webhook configured
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -s -X POST -H "Content-Type: application/json" \
            -d "{\"content\":\"⚠️ Token usage cooldown activated. TPM limit approaching ${limit}. Cooldown: ${COOLDOWN_SECONDS}s\"}" \
            "$ALERT_WEBHOOK" >/dev/null 2>&1
    fi
}

# Function to write state
write_state(){
    usage=$1
    status=$2
    model=$3
    limit=$4
    cat > "$STATE_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "currentModel": "$model",
  "tokenUsageLastMinute": $usage,
  "maxTPM": $limit,
  "cooldownStatus": "$status",
  "cooldownRemaining": ${5:-0}
}
EOF
}

# Main logic
main(){
    # Get current model and appropriate limit
    current_model=$(get_current_model)
    max_tpm=$(get_tpm_limit "$current_model")
    
    # Check if currently in cooldown
    cooldown_status=$(check_cooldown)
    
    # Get recent token usage (approximate)
    recent_usage=$(get_recent_token_usage)
    
    if [ "$cooldown_status" != "COOLDOWN_INACTIVE" ]; then
        remaining=$(echo "$cooldown_status" | cut -d: -f2)
        echo "$(date -Iseconds) - TPM Monitor [${current_model}]: Cooldown active, ${remaining}s remaining (limit: ${max_tpm})"
        write_state "$recent_usage" "active" "$current_model" "$max_tpm" "$remaining"
        exit 0
    fi
    
    # Check if approaching limit
    if [ "$recent_usage" -ge "$max_tpm" ]; then
        echo "$(date -Iseconds) - TPM Monitor [${current_model}]: Token usage ($recent_usage) approaching limit ($max_tpm)"
        activate_cooldown "$max_tpm"
        write_state "$recent_usage" "just_activated" "$current_model" "$max_tpm" "$COOLDOWN_SECONDS"
    else
        usage_percent=$(( recent_usage * 100 / max_tpm ))
        echo "$(date -Iseconds) - TPM Monitor [${current_model}]: Usage at ${usage_percent}% (${recent_usage}/${max_tpm})"
        write_state "$recent_usage" "normal" "$current_model" "$max_tpm" 0
    fi
}

# Run main
main
