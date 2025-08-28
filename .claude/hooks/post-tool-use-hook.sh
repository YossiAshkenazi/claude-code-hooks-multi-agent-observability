#!/bin/bash
# Post-Tool-Use Hook for Agents Observability

SERVER_URL="http://localhost:4000"

# Auto-detect project name and branch
get_project_name() {
    # Try to get project name from git remote origin URL
    local origin_url
    origin_url=$(git config --get remote.origin.url 2>/dev/null)
    if [[ -n "$origin_url" ]]; then
        # Extract repo name from URL (handle both HTTPS and SSH formats)
        if [[ "$origin_url" =~ ([^/]+)\.git$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return
        elif [[ "$origin_url" =~ /([^/]+)/?$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return
        fi
    fi
    
    # Fallback to current folder name
    basename "$(pwd)" 2>/dev/null || echo "unknown-project"
}

get_git_branch() {
    git branch --show-current 2>/dev/null || echo "unknown"
}

# Extract execution metrics from tool response
get_execution_metrics() {
    local tool_response="$1"
    
    local success="false"
    local error_message=""
    local files_affected="[]"
    local bytes_processed=0
    
    if command -v jq >/dev/null 2>&1; then
        # Use jq for parsing if available
        success=$(echo "$tool_response" | jq -r '.success // false' 2>/dev/null)
        error_message=$(echo "$tool_response" | jq -r '.error // ""' 2>/dev/null)
        
        # Extract file information
        local file_path=$(echo "$tool_response" | jq -r '.filePath // .file_path // ""' 2>/dev/null)
        if [[ -n "$file_path" && "$file_path" != "null" ]]; then
            files_affected="[\"$file_path\"]"
        fi
        
        # Calculate bytes processed (approximate)
        local content=$(echo "$tool_response" | jq -r '.content // ""' 2>/dev/null)
        if [[ -n "$content" && "$content" != "null" ]]; then
            bytes_processed=${#content}
        fi
    else
        # Fallback parsing without jq
        if echo "$tool_response" | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
            success="true"
        fi
        error_message=$(echo "$tool_response" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    fi
    
    # If success is not explicitly false and there's no error, assume success
    if [[ "$success" != "false" && -z "$error_message" ]]; then
        success="true"
    fi
    
    cat <<EOF
{
    "success": $success,
    "error_message": "$error_message",
    "files_affected": $files_affected,
    "bytes_processed": $bytes_processed
}
EOF
}

# Read JSON input from stdin
input_json=$(cat)
if [[ -z "$input_json" ]]; then
    exit 0
fi

# Extract values using jq (with fallbacks if jq is not available)
if command -v jq >/dev/null 2>&1; then
    tool_name=$(echo "$input_json" | jq -r '.tool_name // ""')
    tool_input=$(echo "$input_json" | jq -c '.tool_input // {}')
    tool_response=$(echo "$input_json" | jq -c '.tool_response // {}')
    session_id=$(echo "$input_json" | jq -r '.session_id // ""')
    cwd_path=$(echo "$input_json" | jq -r '.cwd // ""')
else
    # Fallback parsing without jq (basic extraction)
    tool_name=$(echo "$input_json" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    session_id=$(echo "$input_json" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    cwd_path=$(echo "$input_json" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    tool_input="{}"
    tool_response="{}"
fi

project_name=$(get_project_name)
git_branch=$(get_git_branch)
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
user="${USER:-unknown}"
hostname="${HOSTNAME:-$(hostname 2>/dev/null || echo unknown)}"

# Calculate execution metrics
execution_metrics=$(get_execution_metrics "$tool_response")

# Create event payload
event_payload=$(cat <<EOF
{
    "source_app": "$project_name",
    "session_id": "${session_id:-$user-$(date +%Y%m%d-%H%M%S)}",
    "hook_event_type": "PostToolUse",
    "payload": {
        "tool_name": "$tool_name",
        "tool_input": $tool_input,
        "tool_response": $tool_response,
        "cwd": "$cwd_path",
        "execution_metrics": $execution_metrics,
        "git_branch": "$git_branch",
        "timestamp": "$timestamp",
        "user": "$user",
        "hostname": "$hostname"
    }
}
EOF
)

# Send event to observability server (non-blocking)
(
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$event_payload" \
        --connect-timeout 2 \
        --max-time 2 \
        "$SERVER_URL/events" >/dev/null 2>&1 &
) 2>/dev/null

# For failed operations, could provide feedback to Claude
# Example feedback response:
# if echo "$execution_metrics" | grep -q '"success": false'; then
#     error_msg=$(echo "$execution_metrics" | jq -r '.error_message // "Unknown error"')
#     echo "{\"decision\": \"block\", \"reason\": \"Tool execution failed: $error_msg. Please review and retry.\"}"
#     exit 0
# fi

exit 0