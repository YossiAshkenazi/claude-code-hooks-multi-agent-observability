#!/bin/bash
# Subagent Stop Hook for Agents Observability
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
    stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // empty')
    cwd=$(echo "$input" | jq -r '.cwd // empty')
    transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
else
    # Fallback using grep/sed for basic extraction
    session_id=$(echo "$input" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"\([^"]*\)"/\1/')
    stop_hook_active=$(echo "$input" | grep -o '"stop_hook_active":"[^"]*"' | sed 's/"stop_hook_active":"\([^"]*\)"/\1/')
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

# Escape JSON strings properly
escaped_stop_hook_active=$(echo "$stop_hook_active" | sed 's/\\/\\\\/g; s/"/\\"/g')
escaped_cwd=$(echo "$cwd" | sed 's/\\/\\\\/g; s/"/\\"/g')
escaped_transcript_path=$(echo "$transcript_path" | sed 's/\\/\\\\/g; s/"/\\"/g')

# Create JSON payload
payload=$(cat <<EOF
{
    "source_app": "$project_name",
    "session_id": "$session_id",
    "hook_event_type": "SubagentStop",
    "payload": {
        "stop_hook_active": "$escaped_stop_hook_active",
        "timestamp": "$timestamp",
        "cwd": "$escaped_cwd",
        "transcript_path": "$escaped_transcript_path"
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