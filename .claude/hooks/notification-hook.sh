#!/bin/bash
# Notification Hook for Agents Observability
# Reads JSON from stdin and sends to observability server

# Read JSON input from stdin
input=$(cat)

# Exit if no input
if [ -z "$input" ]; then
    exit 0
fi

# Extract values using jq if available, otherwise use grep/sed
if command -v jq >/dev/null 2>&1; then
    session_id=$(echo "$input" | jq -r '.session_id // empty')
    message=$(echo "$input" | jq -r '.message // empty')
    cwd=$(echo "$input" | jq -r '.cwd // empty')
    transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
else
    # Fallback using grep/sed for basic extraction
    session_id=$(echo "$input" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"\([^"]*\)"/\1/')
    message=$(echo "$input" | grep -o '"message":"[^"]*"' | sed 's/"message":"\([^"]*\)"/\1/')
    cwd=$(echo "$input" | grep -o '"cwd":"[^"]*"' | sed 's/"cwd":"\([^"]*\)"/\1/')
    transcript_path=$(echo "$input" | grep -o '"transcript_path":"[^"]*"' | sed 's/"transcript_path":"\([^"]*\)"/\1/')
fi

# Extract project name from cwd or use default
if [ -n "$cwd" ]; then
    project_name=$(basename "$cwd")
else
    project_name="unknown-project"
fi

# Create timestamp
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

# Check if this is an "agent needs input" notification
is_agent_needs_input="false"
notification_type="info"
notification_level="normal"

if echo "$message" | grep -qE "needs your permission|waiting for your input|needs your input"; then
    is_agent_needs_input="true"
    notification_type="warning"
    notification_level="high"
fi

# Escape JSON strings properly
escaped_message=$(echo "$message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\r/\\r/g; s/\t/\\t/g')
escaped_cwd=$(echo "$cwd" | sed 's/\\/\\\\/g; s/"/\\"/g')
escaped_transcript_path=$(echo "$transcript_path" | sed 's/\\/\\\\/g; s/"/\\"/g')

# Capture raw notification data and environment variables
raw_notification_data=$(echo "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\r/\\r/g; s/\t/\\t/g')
claude_args="${CLAUDE_ARGS:-}"
claude_flags="${CLAUDE_FLAGS:-}"

# Create JSON payload
payload=$(cat <<EOF
{
    "source_app": "$project_name",
    "session_id": "$session_id",
    "hook_event_type": "Notification",
    "payload": {
        "message": "$escaped_message",
        "timestamp": "$timestamp",
        "cwd": "$escaped_cwd",
        "transcript_path": "$escaped_transcript_path",
        "notification_type": "$notification_type",
        "notification_level": "$notification_level",
        "is_agent_needs_input": $is_agent_needs_input,
        "raw_notification_data": "$raw_notification_data",
        "claude_args": "$claude_args",
        "claude_flags": "$claude_flags"
    }
}
EOF
)

# Send to observability server (non-blocking with timeout)
(
    curl -s -m 2 -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "http://localhost:4000/events" >/dev/null 2>&1 &
    
    # Wait for background process with timeout
    sleep 2
    jobs -p | xargs -r kill 2>/dev/null
) 2>/dev/null &

exit 0