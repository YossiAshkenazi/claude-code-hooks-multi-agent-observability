#!/usr/bin/env python3
"""
Universal hook wrapper that auto-detects environment and runs hooks appropriately.
Works in both Windows (with uv) and Docker containers (with python3).
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path

def detect_environment():
    """Detect if we're in a container or on host system."""
    # Check for Docker/container indicators
    if os.path.exists('/.dockerenv'):
        return 'docker'
    if os.path.exists('/run/.containerenv'):
        return 'container'
    if os.environ.get('KUBERNETES_SERVICE_HOST'):
        return 'kubernetes'
    
    # Check if we're in WSL
    try:
        with open('/proc/version', 'r') as f:
            if 'microsoft' in f.read().lower():
                # In WSL, check if we're in a container
                if os.path.exists('/workspace') or os.path.exists('/workspaces'):
                    return 'devcontainer'
                return 'wsl'
    except:
        pass
    
    # Check for Windows
    if sys.platform == 'win32':
        return 'windows'
    
    return 'unknown'

def has_command(cmd):
    """Check if a command exists in PATH."""
    return shutil.which(cmd) is not None

def run_hook(hook_script, args):
    """Run a hook script with the appropriate Python runner."""
    env = detect_environment()
    hook_path = Path(__file__).parent / hook_script
    
    if not hook_path.exists():
        # Silently exit if hook doesn't exist (subagent safety)
        sys.exit(0)
    
    # Determine the best Python runner
    if env in ['docker', 'container', 'devcontainer', 'kubernetes']:
        # In containers, use python3 directly
        runner = ['python3', str(hook_path)]
    elif env == 'windows' and has_command('uv'):
        # On Windows with uv available, use it
        runner = ['uv', 'run', str(hook_path)]
    elif has_command('python3'):
        # Fallback to python3 if available
        runner = ['python3', str(hook_path)]
    elif has_command('python'):
        # Last resort: plain python
        runner = ['python', str(hook_path)]
    else:
        # No Python found - fail silently
        sys.exit(0)
    
    # Add any arguments passed to this wrapper
    if args:
        runner.extend(args)
    
    try:
        # Run the actual hook
        result = subprocess.run(
            runner,
            stdin=sys.stdin,
            capture_output=False,
            text=True
        )
        sys.exit(result.returncode)
    except FileNotFoundError:
        # Runner not found - fail silently
        sys.exit(0)
    except Exception:
        # Any other error - fail silently
        sys.exit(0)

if __name__ == "__main__":
    # Get the hook name from the first argument
    if len(sys.argv) < 2:
        print("Usage: universal_hook_wrapper.py <hook_name> [args...]", file=sys.stderr)
        sys.exit(1)
    
    hook_name = sys.argv[1]
    args = sys.argv[2:] if len(sys.argv) > 2 else []
    
    run_hook(hook_name, args)