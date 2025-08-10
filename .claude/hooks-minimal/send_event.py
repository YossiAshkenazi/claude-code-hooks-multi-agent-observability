#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///

"""
Minimal Hook Script for Multi-Agent Observability
Sends Claude Code hook events to the centralized observability server.
All AI processing happens server-side.
"""

import json
import sys
import os
import argparse
import urllib.request
import urllib.error
from datetime import datetime

def send_event_to_server(event_data, server_url='http://localhost:4000/events', summarize=False):
    """Send event data to the observability server."""
    try:
        # Add summarize parameter to URL if requested
        if summarize:
            server_url += '?summarize=true'
        
        # Prepare the request
        req = urllib.request.Request(
            server_url,
            data=json.dumps(event_data).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'Claude-Code-Hook-Minimal/1.0'
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
        # Fail silently - don't interrupt Claude Code
        return False
    except Exception as e:
        # Fail silently - don't interrupt Claude Code
        return False

def request_tts(message_type='notification', text=None):
    """Request TTS from server."""
    try:
        if message_type == 'notification':
            url = 'http://localhost:4000/api/tts/notification'
            data = json.dumps({}).encode('utf-8')
        elif message_type == 'completion':
            url = 'http://localhost:4000/api/ai/completion'
            # Get completion message first
            req = urllib.request.Request(
                url,
                data=json.dumps({}).encode('utf-8'),
                headers={'Content-Type': 'application/json'}
            )
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    result = json.loads(response.read().decode('utf-8'))
                    if result.get('success') and result.get('message'):
                        text = result['message']
            
            # Then request TTS with the message
            url = 'http://localhost:4000/api/tts'
            data = json.dumps({'text': text}).encode('utf-8') if text else None
            if not data:
                return False
        else:
            return False
        
        req = urllib.request.Request(
            url,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.status == 200
            
    except (urllib.error.URLError, Exception):
        # Fail silently
        return False

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Send Claude Code hook events to observability server')
    parser.add_argument('--source-app', required=True, help='Source application name')
    parser.add_argument('--event-type', required=True, help='Hook event type')
    parser.add_argument('--server-url', default='http://localhost:4000/events', help='Server URL')
    parser.add_argument('--add-chat', action='store_true', help='Include chat transcript if available')
    parser.add_argument('--summarize', action='store_true', help='Request server-side AI summary')
    parser.add_argument('--notify', action='store_true', help='Request notification TTS')
    parser.add_argument('--announce', action='store_true', help='Request completion announcement')
    
    args = parser.parse_args()
    
    try:
        # Read hook data from stdin
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        # Exit silently on JSON errors
        sys.exit(0)
    
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
            except Exception:
                pass  # Fail silently
    
    # Send to server (with summarization handled server-side if requested)
    send_event_to_server(event_data, args.server_url, args.summarize)
    
    # Handle TTS requests
    if args.notify:
        # Skip TTS for the generic "Claude is waiting for your input" message
        if input_data.get('message') != 'Claude is waiting for your input':
            request_tts('notification')
    elif args.announce:
        request_tts('completion')
    
    # Always exit with 0 to not block Claude Code operations
    sys.exit(0)

if __name__ == '__main__':
    main()