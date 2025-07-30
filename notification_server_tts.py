#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "python-dotenv",
#     "requests",
# ]
# ///

import argparse
import json
import os
import sys
import requests
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # dotenv is optional


def ensure_session_log_dir(session_id):
    """Ensure session log directory exists and return path."""
    log_dir = Path("logs") / session_id
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir


def trigger_server_tts(message):
    """Send TTS request to observability server."""
    try:
        # Default server URL (can be overridden with environment variable)
        server_url = os.getenv('OBSERVABILITY_SERVER_URL', 'http://localhost:4000')
        tts_endpoint = f"{server_url}/api/tts/notification"
        
        # Send TTS request to server
        response = requests.post(
            tts_endpoint,
            json={
                "engineer_name": os.getenv('ENGINEER_NAME', '')
            },
            timeout=2  # Quick timeout to avoid blocking
        )
        
        if response.status_code == 200:
            # TTS request successful
            pass
        else:
            # TTS failed, but don't block the notification logging
            pass
            
    except (requests.exceptions.RequestException, requests.exceptions.Timeout):
        # Server not available or timeout - fail silently
        # This ensures the hook doesn't break if server is down
        pass
    except Exception:
        # Any other error - fail silently
        pass


def main():
    try:
        # Parse command line arguments
        parser = argparse.ArgumentParser()
        parser.add_argument('--notify', action='store_true', help='Enable TTS notifications via server')
        args = parser.parse_args()
        
        # Read JSON input from stdin
        input_data = json.loads(sys.stdin.read())
        
        # Extract session_id
        session_id = input_data.get('session_id', 'unknown')
        
        # Ensure session log directory exists
        log_dir = ensure_session_log_dir(session_id)
        log_file = log_dir / 'notification.json'
        
        # Read existing log data or initialize empty list
        if log_file.exists():
            with open(log_file, 'r') as f:
                try:
                    log_data = json.load(f)
                except (json.JSONDecodeError, ValueError):
                    log_data = []
        else:
            log_data = []
        
        # Append new data
        log_data.append(input_data)
        
        # Write back to file with formatting
        with open(log_file, 'w') as f:
            json.dump(log_data, f, indent=2)
        
        # Trigger server-side TTS if --notify flag is set
        # Skip TTS for the generic "Claude is waiting for your input" message
        if args.notify and input_data.get('message') != 'Claude is waiting for your input':
            trigger_server_tts(input_data.get('message'))
        
        sys.exit(0)
        
    except json.JSONDecodeError:
        # Handle JSON decode errors gracefully
        sys.exit(0)
    except Exception:
        # Handle any other errors gracefully
        sys.exit(0)

if __name__ == '__main__':
    main()