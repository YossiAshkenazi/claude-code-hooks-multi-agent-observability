# Claude Code Observability Hooks

Easy integration package for adding observability to any Claude Code project. This system captures hook events and sends them to a centralized monitoring server.

## Quick Start

1. **Install to your project:**
   ```bash
   # From this repository's hooks-integration/ directory
   python install.py /path/to/your/project
   ```

2. **Start the observability server** (in this repository):
   ```bash
   ./scripts/start-system.sh
   ```

3. **Use Claude Code in your project** - events will automatically appear in the dashboard at http://host.docker.internal:5173

## Installation Options

### Basic Installation
```bash
python install.py ~/my-project
```
Auto-detects project name from git repo, package.json, or directory name.

### Custom Configuration
```bash
python install.py ~/my-project \
  --project-name "My App" \
  --server-url "http://host.docker.internal:4000/events" \
  --no-tts \
  --minimal
```

### Available Options
- `--project-name NAME` - Override detected project name
- `--server-url URL` - Custom server URL (default: http://host.docker.internal:4000/events)
- `--no-summarize` - Disable AI summarization of events
- `--no-tts` - Disable text-to-speech notifications  
- `--no-chat` - Disable chat transcript capture
- `--no-announce` - Disable completion announcements
- `--minimal` - Install only core hooks (PreToolUse, PostToolUse, UserPromptSubmit)

## Architecture

```
Claude Code → Python Hooks → HTTP POST → Bun Server → SQLite → WebSocket → Vue Dashboard
```

### Files Created
When you install hooks to a project, these files are created:

- **`.claude/send_event.py`** - Main hook script that sends events to server
- **`.claude/hooks-config.json`** - Project configuration file
- **`.claude/settings.json`** - Claude Code hook settings

## Configuration

The `hooks-config.json` file controls all behavior:

```json
{
  "source_app": "my-project",
  "server_url": "http://host.docker.internal:4000/events",
  "features": {
    "summarize": true,
    "tts_notifications": true,
    "chat_transcript": true,
    "completion_announcements": true
  },
  "hooks": {
    "PreToolUse": { "enabled": true, "options": ["summarize"] },
    "PostToolUse": { "enabled": true, "options": ["summarize"] },
    "UserPromptSubmit": { "enabled": true, "options": ["summarize"] },
    "Notification": { "enabled": true, "options": ["notify"] },
    "Stop": { "enabled": true, "options": ["add-chat", "announce"] },
    "SubagentStop": { "enabled": true, "options": [] },
    "PreCompact": { "enabled": false, "options": [] }
  }
}
```

## Event Types Captured

| Event Type | Description | Features |
|------------|-------------|----------|
| **PreToolUse** | Before Claude runs a tool | AI summarization |
| **PostToolUse** | After tool execution | AI summarization, result capture |
| **UserPromptSubmit** | User sends message | AI summarization |
| **Notification** | User interactions | TTS notifications |
| **Stop** | Claude response complete | Chat transcript, completion announcement |
| **SubagentStop** | Subagent finishes task | Subagent tracking |

## Server Features

The observability server provides:

- **Real-time Dashboard** - Live event monitoring with filtering
- **AI Summarization** - Automatic event summaries using Anthropic/OpenAI APIs
- **Text-to-Speech** - Audio notifications using ElevenLabs or system TTS
- **Chat Transcripts** - Full conversation history storage
- **Session Tracking** - Events grouped by Claude sessions
- **Multi-Project Support** - Monitor multiple projects simultaneously

## Server Requirements

Environment variables for the server:
```bash
ANTHROPIC_API_KEY=your_key_here     # Required for AI features
OPENAI_API_KEY=optional             # Fallback for AI operations  
ELEVENLABS_API_KEY=optional         # High-quality TTS
ENGINEER_NAME=optional              # Personalized messages
```

## Troubleshooting

### Events Not Appearing
1. Check server is running: `curl http://host.docker.internal:4000/health`
2. Verify config file: `cat .claude/hooks-config.json`  
3. Test hook manually: `echo '{"session_id":"test"}' | uv run .claude/send_event.py --event-type Test`

### Performance Issues
- Use `--minimal` for lightweight installation
- Disable features you don't need in `hooks-config.json`
- Check server logs for errors

### Customization
- Edit `hooks-config.json` to enable/disable specific hooks
- Modify `server_url` to point to different observability servers
- Add custom hook logic by extending `send_event.py`

## Integration Examples

### Minimal Setup (CI/CD friendly)
```bash
python install.py ~/my-project --minimal --no-tts --no-announce
```

### Full Featured Setup
```bash  
python install.py ~/my-project --project-name "My App"
# All features enabled by default
```

### Custom Server
```bash
python install.py ~/my-project --server-url "https://my-domain.com/hooks"
```

## Security

- Hook scripts include input validation
- No sensitive data is logged by default
- All network requests have timeouts
- Failed hooks don't block Claude Code operations
- Server validates all incoming events

## Contributing

To modify the hooks system:
1. Update templates in `hooks-integration/`  
2. Test with `python install.py /tmp/test-project`
3. Verify events appear in dashboard
4. Update documentation

## License

Same as parent project - see main repository LICENSE file.