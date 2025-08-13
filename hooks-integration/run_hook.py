#!/usr/bin/env python3
"""
Universal hook runner that works across all environments.
This is the ONLY script that needs to handle environment detection.
"""

import os
import sys
import subprocess
import shutil

def find_python():
    """Find the best Python executable for this environment."""
    # On Windows, python is the standard command (python3 usually doesn't exist)
    if sys.platform == 'win32':
        for cmd in ['python', sys.executable, 'python3']:
            if shutil.which(cmd):
                return cmd
    else:
        # On Unix-like systems, prefer python3
        for cmd in ['python3', 'python', sys.executable]:
            if shutil.which(cmd):
                return cmd
    return 'python'  # Fallback

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    
    hook_script = sys.argv[1]
    args = sys.argv[2:]
    
    # Get the directory where this script lives
    script_dir = os.path.dirname(os.path.abspath(__file__))
    hook_path = os.path.join(script_dir, hook_script)
    
    # Check if hook exists
    if not os.path.exists(hook_path):
        # Silently exit for missing hooks (subagent safety)
        sys.exit(0)
    
    # Find Python
    python = find_python()
    
    # Build command
    cmd = [python, hook_path] + args
    
    try:
        # Run the hook, passing through stdin/stdout
        result = subprocess.run(cmd, stdin=sys.stdin)
        sys.exit(result.returncode)
    except Exception:
        # Fail silently
        sys.exit(0)

if __name__ == '__main__':
    main()