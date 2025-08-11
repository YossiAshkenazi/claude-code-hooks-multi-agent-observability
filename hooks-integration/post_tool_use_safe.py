#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///

"""
Subagent-safe version of post_tool_use.py that handles missing dependencies gracefully.
"""

import json
import sys

def main():
    try:
        # Read input
        input_data = json.load(sys.stdin)
        
        # Basic validation only - no dependency on utils
        tool_name = input_data.get('tool', '')
        result = input_data.get('result', '')
        
        # Check for sensitive data patterns (basic)
        sensitive_patterns = ['api_key', 'secret', 'password', 'token']
        result_lower = str(result).lower()
        
        for pattern in sensitive_patterns:
            if pattern in result_lower:
                # Don't log the actual sensitive data
                print(f"Warning: Potential sensitive data in {tool_name} output", file=sys.stderr)
                break
        
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