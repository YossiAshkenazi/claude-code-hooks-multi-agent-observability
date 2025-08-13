#!/usr/bin/env python3
"""
Universal send_event.py that works in both Windows (with uv) and containers.
Auto-detects environment and handles dependencies appropriately.
"""

import json
import sys
import os
import argparse
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

def detect_environment():
    """Detect if we're in a container or on host system."""
    # Docker container indicators
    if os.path.exists('/.dockerenv') or os.path.exists('/run/.containerenv'):
        return 'container'
    
    # Check for workspace directories (devcontainer)
    if os.path.exists('/workspace') or os.path.exists('/workspaces'):
        return 'container'
    
    # Windows detection
    if sys.platform == 'win32':
        return 'windows'
    
    # WSL detection
    try:
        with open('/proc/version', 'r') as f:
            if 'microsoft' in f.read().lower():
                return 'wsl'
    except:
        pass
    
    return 'unix'

def get_server_url():
    """Get the appropriate server URL based on environment."""
    env = detect_environment()
    
    # Try environment variable first
    if os.environ.get('OBSERVABILITY_SERVER_URL'):
        return os.environ.get('OBSERVABILITY_SERVER_URL')
    
    # Default URLs based on environment
    if env == 'container':
        # In Docker, use host.docker.internal
        return 'http://host.docker.internal:4000/events'
    elif env == 'wsl':
        # In WSL, might need to use Windows host IP
        # Try to get it from /etc/resolv.conf
        try:
            with open('/etc/resolv.conf', 'r') as f:
                for line in f:
                    if line.startswith('nameserver'):
                        ip = line.split()[1]
                        if not ip.startswith('127.'):
                            return f'http://{ip}:4000/events'
        except:
            pass
        return 'http://host.docker.internal:4000/events'
    else:
        # Windows or Unix - use localhost
        return 'http://localhost:4000/events'

def load_config():
    """Load configuration from hooks-config.json if it exists."""
    config_path = Path(__file__).parent / 'hooks-config.json'
    if config_path.exists():
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except:
            pass
    return {}

def get_session_id():
    """Get or create a session ID."""
    session_file = Path(__file__).parent / '.session_id'
    
    # Try environment variable first
    if os.environ.get('CLAUDE_SESSION_ID'):
        return os.environ.get('CLAUDE_SESSION_ID')
    
    # Try to read from file
    if session_file.exists():
        try:
            return session_file.read_text().strip()
        except:
            pass
    
    # Generate new session ID
    from datetime import datetime
    session_id = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    # Try to save it
    try:
        session_file.write_text(session_id)
    except:
        pass
    
    return session_id

def send_event_to_server(event_data, server_url=None, summarize=False, notify=False, announce=False):
    """Send event to the observability server."""
    if not server_url:
        server_url = get_server_url()
    
    config = load_config()
    
    # Build the event
    event = {
        'source_app': config.get('project_name', 'unknown'),
        'session_id': get_session_id(),
        'hook_event_type': event_data.get('hook_event_type', 'unknown'),
        'timestamp': datetime.now().isoformat(),
        'payload': event_data
    }
    
    # Add optional fields
    if summarize and config.get('features', {}).get('summarize'):
        event['request_summary'] = True
    if notify and config.get('features', {}).get('tts_notifications'):
        event['notify'] = True
    if announce and config.get('features', {}).get('completion_announcements'):
        event['announce'] = True
    
    # Try to send the event
    try:
        req = urllib.request.Request(
            server_url,
            data=json.dumps(event).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=2) as response:
            if response.status == 200:
                return True
    except urllib.error.URLError:
        # Server not reachable - fail silently
        pass
    except Exception:
        # Any other error - fail silently
        pass
    
    return False

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='Send event to observability server')
    parser.add_argument('--event-type', required=True, help='Type of event')
    parser.add_argument('--source-app', help='Source application name')
    parser.add_argument('--server-url', help='Override server URL')
    parser.add_argument('--summarize', action='store_true', help='Request AI summary')
    parser.add_argument('--notify', action='store_true', help='Send notification')
    parser.add_argument('--announce', action='store_true', help='Announce completion')
    parser.add_argument('--add-chat', action='store_true', help='Include chat transcript')
    
    args = parser.parse_args()
    
    # Read event data from stdin
    try:
        event_data = json.load(sys.stdin)
    except:
        event_data = {}
    
    # Add event type
    event_data['hook_event_type'] = args.event_type
    
    # Override source app if provided
    if args.source_app:
        event_data['source_app'] = args.source_app
    
    # Send the event
    success = send_event_to_server(
        event_data, 
        args.server_url,
        args.summarize,
        args.notify,
        args.announce
    )
    
    # Always pass through the input (for hook chaining)
    print(json.dumps(event_data))
    
    # Exit with success (never block the pipeline)
    sys.exit(0)

if __name__ == '__main__':
    main()