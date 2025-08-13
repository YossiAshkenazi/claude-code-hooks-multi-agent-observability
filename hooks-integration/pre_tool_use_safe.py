#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///

"""
Subagent-safe version of pre_tool_use.py that handles missing dependencies gracefully.
"""

import json
import sys
import re

def is_dangerous_rm_command(command):
    """Basic dangerous rm command detection."""
    normalized = ' '.join(command.lower().split())
    patterns = [
        r'\brm\s+.*-[a-z]*r[a-z]*f',
        r'\brm\s+.*-[a-z]*f[a-z]*r',
    ]
    for pattern in patterns:
        if re.search(pattern, normalized):
            return True
    return False

def main():
    try:
        # Read input
        input_data = json.load(sys.stdin)
        
        # Basic validation only - no dependency on utils
        if input_data.get('tool') == 'Bash':
            command = input_data.get('arguments', {}).get('command', '')
            if is_dangerous_rm_command(command):
                print(f"Blocked dangerous command: {command}", file=sys.stderr)
                sys.exit(1)
        
        # Pass through
        print(json.dumps(input_data))
        sys.exit(0)
        
    except Exception:
        # Fail silently in subagent contexts
        if sys.stdin.isatty():
            sys.exit(0)
        # Try to pass through input even if we can't process it
        try:
            sys.stdin.seek(0)
            print(sys.stdin.read())
        except:
            pass
        sys.exit(0)

if __name__ == "__main__":
    main()