#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "python-dotenv",
# ]
# ///

"""
Multi-Agent Observability Hook Script
Sends Claude Code hook events to the observability server.
Uses configuration file for project-specific settings.
"""

import json
import sys
import os
import argparse
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

def load_config():
    """Load configuration from hooks-config.json in the .claude directory."""
    config_path = Path('.claude/hooks-config.json')
    
    if not config_path.exists():
        # Fallback to default values if config doesn't exist
        return {
            'source_app': 'unknown-project',
            'server_url': 'http://host.docker.internal:4000/events',
            'features': {
                'summarize': True,
                'tts_notifications': True,
                'chat_transcript': True,
                'completion_announcements': True
            }
        }
    
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"Warning: Failed to load config file: {e}", file=sys.stderr)
        # Return default config on error
        return {
            'source_app': 'unknown-project',
            'server_url': 'http://host.docker.internal:4000/events',
            'features': {
                'summarize': True,
                'tts_notifications': True,
                'chat_transcript': True,
                'completion_announcements': True
            }
        }

def send_event_to_server(event_data, server_url='http://host.docker.internal:4000/events', summarize=False, notify=False, announce=False):
    """Send event data to the observability server."""
    try:
        # Add query parameters based on options
        params = []
        if summarize:
            params.append('summarize=true')
        if notify:
            params.append('notify=true')
        if announce:
            params.append('announce=true')
        
        if params:
            server_url += '?' + '&'.join(params)
        
        # Prepare the request
        req = urllib.request.Request(
            server_url,
            data=json.dumps(event_data).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'Claude-Code-Hook/2.0'
            }
        )
        
        # Send the request
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                return True
            else:
                print(f"Server returned status: {response.status}", file=sys.stderr)
                return False
                
    except urllib.error.URLError as e:
        print(f"Failed to send event: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return False

def main():
    # Load configuration
    config = load_config()
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Send Claude Code hook events to observability server')
    parser.add_argument('--source-app', default=config['source_app'], help='Source application name (overrides config)')
    parser.add_argument('--event-type', required=True, help='Hook event type (PreToolUse, PostToolUse, etc.)')
    parser.add_argument('--server-url', default=config['server_url'], help='Server URL (overrides config)')
    parser.add_argument('--add-chat', action='store_true', help='Include chat transcript if available')
    parser.add_argument('--summarize', action='store_true', help='Generate AI summary of the event')
    parser.add_argument('--notify', action='store_true', help='Send TTS notification')
    parser.add_argument('--announce', action='store_true', help='Send completion announcement')
    
    args = parser.parse_args()
    
    try:
        # Read hook data from stdin
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Failed to parse JSON input: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Prepare event data for server
    event_data = {
        'source_app': args.source_app,
        'session_id': input_data.get('session_id', 'unknown'),
        'hook_event_type': args.event_type,
        'payload': input_data,
        'timestamp': int(datetime.now().timestamp() * 1000)
    }
    
    # Handle --add-chat option
    if args.add_chat and 'transcript_path' in input_data:
        transcript_path = input_data['transcript_path']
        if os.path.exists(transcript_path):
            # Read .jsonl file and convert to JSON array
            chat_data = []
            try:
                with open(transcript_path, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if line:
                            try:
                                chat_data.append(json.loads(line))
                            except json.JSONDecodeError:
                                pass  # Skip invalid lines
                
                # Add chat to event data
                event_data['chat'] = chat_data
            except Exception as e:
                print(f"Failed to read transcript: {e}", file=sys.stderr)
    
    # Send to server with feature flags from config
    features = config.get('features', {})
    summarize = args.summarize and features.get('summarize', True)
    notify = args.notify and features.get('tts_notifications', True)
    announce = args.announce and features.get('completion_announcements', True)
    
    success = send_event_to_server(event_data, args.server_url, summarize, notify, announce)
    
    # Always exit with 0 to not block Claude Code operations
    sys.exit(0)

if __name__ == '__main__':
    main()