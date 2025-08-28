#!/bin/bash
# Stop Hook for Agents Observability
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

# Try to extract the last assistant message from the transcript
assistant_message=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    # Read last 50 lines and look for assistant messages (reverse order)
    if command -v jq >/dev/null 2>&1; then
        # Use jq to parse JSONL format
        assistant_message=$(tail -50 "$transcript_path" | tac | while IFS= read -r line; do
            if [ -n "$line" ]; then
                # Try array format first
                msg=$(echo "$line" | jq -r 'select(.message.role == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null)
                if [ -n "$msg" ]; then
                    echo "$msg"
                    break
                fi
                # Try string format as fallback
                msg=$(echo "$line" | jq -r 'select(.message.role == "assistant") | .message.content // empty' 2>/dev/null)
                if [ -n "$msg" ] && [ "$msg" != "null" ]; then
                    echo "$msg"
                    break
                fi
            fi
        done)
    fi
fi

# Escape JSON strings properly
escaped_stop_hook_active=$(echo "$stop_hook_active" | sed 's/\\/\\\\/g; s/"/\\"/g')
escaped_cwd=$(echo "$cwd" | sed 's/\\/\\\\/g; s/"/\\"/g')
escaped_transcript_path=$(echo "$transcript_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
escaped_assistant_message=$(echo "$assistant_message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g; s/\r/\\r/g; s/\n/\\n/g')

# Create Stop event JSON payload
stop_payload=$(cat <<EOF
{
    "source_app": "$project_name",
    "session_id": "$session_id",
    "hook_event_type": "Stop",
    "payload": {
        "stop_hook_active": "$escaped_stop_hook_active",
        "timestamp": "$timestamp",
        "cwd": "$escaped_cwd",
        "transcript_path": "$escaped_transcript_path"
    }
}
EOF
)

# Send Stop event to observability server (non-blocking with timeout)
(
    curl -s -m 2 -X POST \
        -H "Content-Type: application/json" \
        -d "$stop_payload" \
        "http://localhost:4000/events" >/dev/null 2>&1 &
    
    # Wait for background process with timeout
    sleep 2
    jobs -p | xargs -r kill 2>/dev/null
) 2>/dev/null &

# If we found an assistant message, also send it as assistant-message event
if [ -n "$assistant_message" ]; then
    assistant_payload=$(cat <<EOF
{
    "source_app": "$project_name",
    "session_id": "$session_id",
    "hook_event_type": "assistant-message",
    "payload": {
        "message": "$escaped_assistant_message",
        "timestamp": "$timestamp",
        "cwd": "$escaped_cwd",
        "transcript_path": "$escaped_transcript_path"
    }
}
EOF
    )
    
    # Send assistant-message event with summarization (non-blocking with timeout)
    (
        curl -s -m 2 -X POST \
            -H "Content-Type: application/json" \
            -d "$assistant_payload" \
            "http://localhost:4000/events?summarize=true" >/dev/null 2>&1 &
        
        # Wait for background process with timeout
        sleep 2
        jobs -p | xargs -r kill 2>/dev/null
    ) 2>/dev/null &
fi

exit 0