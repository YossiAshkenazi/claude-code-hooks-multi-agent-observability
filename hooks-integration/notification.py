#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "python-dotenv",
# ]
# ///

import argparse
import json
import os
import sys
import subprocess
import random
import urllib.request
import urllib.error
from pathlib import Path
from utils.constants import ensure_session_log_dir

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # dotenv is optional


def announce_notification():
    """Announce that the agent needs user input using server TTS."""
    try:
        # Get engineer name if available
        engineer_name = os.getenv('ENGINEER_NAME', '').strip()
        
        # Try server-side TTS first
        data = json.dumps({'notification': True, 'engineer_name': engineer_name}).encode('utf-8')
        req = urllib.request.Request(
            'http://localhost:4000/api/tts/notification',
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                return  # Success
    except (urllib.error.URLError, Exception):
        # Fall back to local TTS if server is unavailable
        announce_notification_local()


def announce_notification_local():
    """[Fallback] Announce using local TTS scripts."""
    try:
        # Get current script directory and construct utils/tts path
        script_dir = Path(__file__).parent
        tts_dir = script_dir / "utils" / "tts"
        
        # Try to find a TTS script
        tts_script = None
        if os.getenv('ELEVENLABS_API_KEY'):
            elevenlabs_script = tts_dir / "elevenlabs_tts.py"
            if elevenlabs_script.exists():
                tts_script = str(elevenlabs_script)
        elif os.getenv('OPENAI_API_KEY'):
            openai_script = tts_dir / "openai_tts.py"
            if openai_script.exists():
                tts_script = str(openai_script)
        else:
            pyttsx3_script = tts_dir / "pyttsx3_tts.py"
            if pyttsx3_script.exists():
                tts_script = str(pyttsx3_script)
        
        if not tts_script:
            return  # No TTS scripts available
        
        # Get engineer name if available
        engineer_name = os.getenv('ENGINEER_NAME', '').strip()
        
        # Create notification message with 30% chance to include name
        if engineer_name and random.random() < 0.3:
            notification_message = f"{engineer_name}, your agent needs your input"
        else:
            notification_message = "Your agent needs your input"
        
        # Call the TTS script with the notification message
        subprocess.run([
            "uv", "run", tts_script, notification_message
        ], 
        capture_output=True,  # Suppress output
        timeout=10  # 10-second timeout
        )
        
    except (subprocess.TimeoutExpired, subprocess.SubprocessError, FileNotFoundError):
        # Fail silently if TTS encounters issues
        pass
    except Exception:
        # Fail silently for any other errors
        pass


def main():
    try:
        # Parse command line arguments
        parser = argparse.ArgumentParser()
        parser.add_argument('--notify', action='store_true', help='Enable TTS notifications')
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
        
        # Announce notification via TTS only if --notify flag is set
        # Skip TTS for the generic "Claude is waiting for your input" message
        if args.notify and input_data.get('message') != 'Claude is waiting for your input':
            announce_notification()
        
        sys.exit(0)
        
    except json.JSONDecodeError:
        # Handle JSON decode errors gracefully
        sys.exit(0)
    except Exception:
        # Handle any other errors gracefully
        sys.exit(0)

if __name__ == '__main__':
    main()