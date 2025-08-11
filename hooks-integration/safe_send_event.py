#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///

"""
Resilient event sender that handles missing dependencies gracefully.
Designed to work in subagent contexts where main hook files may be missing.
"""

import sys
import os
import json
from pathlib import Path

def main():
    """
    Minimal event handler that fails silently when dependencies are missing.
    This prevents subagents from crashing due to missing hook files.
    """
    try:
        # Check if we're in a subagent context (no .claude directory)
        claude_dir = Path(__file__).parent
        if not claude_dir.exists():
            # Silently exit - we're likely in a subagent
            sys.exit(0)
        
        # Try to import the actual send_event module
        send_event_path = claude_dir / "send_event.py"
        if not send_event_path.exists():
            # Missing send_event.py - fail silently
            sys.exit(0)
        
        # If we get here, try to execute the actual send_event
        import subprocess
        args = ["uv", "run", str(send_event_path)] + sys.argv[1:]
        
        # Run the actual send_event.py
        result = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=5  # Prevent hanging
        )
        
        # Pass through the exit code
        sys.exit(result.returncode)
        
    except FileNotFoundError:
        # uv or send_event.py not found - fail silently
        sys.exit(0)
    except subprocess.TimeoutExpired:
        # Timeout - fail silently
        sys.exit(0)
    except Exception:
        # Any other error - fail silently
        sys.exit(0)

if __name__ == "__main__":
    main()