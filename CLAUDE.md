# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-Agent Observability System for Claude Code - a real-time monitoring and visualization platform that captures, stores, and displays Claude Code hook events through a full-stack TypeScript/Vue application with Python hooks.

## Architecture

```
Claude Agents � Hook Scripts (Python/uv) � HTTP POST � Bun Server � SQLite � WebSocket � Vue Client
```

The system consists of:
- **Python Hook Scripts** (`.claude/hooks/`) - Capture Claude Code lifecycle events using `uv` package manager
- **Bun Server** (`apps/server/`) - TypeScript server with HTTP/WebSocket endpoints and SQLite storage
- **Vue Client** (`apps/client/`) - Real-time dashboard with filtering and visualization
- **SQLite Database** - Event storage with session tracking

## Development Commands

### System Management

**PowerShell (Windows)**:
```powershell
# Start entire system (server + client) - non-interactive
powershell -File scripts/start-services.ps1

# Stop all processes - no key prompts
powershell -File scripts/stop-services.ps1

# Check system status
powershell -File scripts/check-status.ps1

# Interactive system management
powershell -File manage-system.ps1
```

**Bash (Linux/Mac)**:
```bash
# Start entire system (server + client)
./scripts/start-system.sh

# Stop all processes
./scripts/reset-system.sh

# Test system functionality
./scripts/test-system.sh
```

### Server (apps/server/)
```bash
cd apps/server
bun install              # Install dependencies
bun run dev             # Development mode with hot reload
bun run start           # Production mode
bun run typecheck       # TypeScript checking
```

### Client (apps/client/)
```bash
cd apps/client
bun install              # Install dependencies
bun run dev             # Development server (Vite)
bun run build           # Production build
bun run preview         # Preview production build
```

### Hook Scripts
```bash
# All hook scripts use uv (Python package manager)
uv run .claude/hooks/send_event.py --source-app <app-name> --event-type <type>
```

## Key Technologies

- **Runtime**: Bun (preferred over Node.js - see apps/server/CLAUDE.md)
- **Server**: Bun.serve() with native WebSocket support, no Express needed
- **Database**: SQLite with `bun:sqlite` (not better-sqlite3)
- **Client**: Vue 3 + TypeScript + Vite + Tailwind CSS
- **Hook Scripts**: Python 3.8+ with Astral uv package manager

## Database Schema

Events table with columns:
- `id`, `source_app`, `session_id`, `hook_event_type`, `timestamp`
- `payload` (JSON), `summary` (AI-generated), `chat_transcript`

## Hook System Integration

The `.claude/settings.json` configures hook events:
- **PreToolUse/PostToolUse**: Tool execution monitoring
- **UserPromptSubmit**: User input capture
- **Notification**: User interaction events
- **Stop/SubagentStop**: Session completion tracking with AI-powered TTS summaries

Each hook runs both validation logic and sends observability data to the server.

### AI-Powered TTS Integration

The `stop.py` hook now features intelligent session summarization:
- **AI Analysis**: Chat transcripts are analyzed by Claude/OpenAI to generate concise summaries
- **Smart TTS**: Instead of generic completion messages, TTS speaks AI-generated session summaries
- **Fallback Support**: Falls back to simple completion messages if AI services are unavailable
- **Example**: "Session complete: User restored TTS files and fixed integration issues"

## Event Types & Visualization

| Event Type | Emoji | Purpose | Display |
|------------|--------|---------|---------|
| PreToolUse | =' | Before tool execution | Tool name & inputs |
| PostToolUse |  | After tool completion | Results & outputs |
| UserPromptSubmit | =� | User prompt | Prompt text (italic) |
| Notification | = | User interactions | Notification message |
| Stop | =� | Response completion | Chat transcript |
| SubagentStop | =e | Subagent finished | Subagent details |

## Configuration

### Environment Variables
Create `.env` in project root:
```bash
ANTHROPIC_API_KEY=your_key_here
ENGINEER_NAME=your_name
OPENAI_API_KEY=optional
ELEVEN_API_KEY=optional
GEMINI_API_KEY=optional
```

Create `apps/client/.env`:
```bash
VITE_MAX_EVENTS_TO_DISPLAY=100
```

### Ports
- Server: 4000 (HTTP/WebSocket)
- Client: 5173 (Vite dev server)

### API Endpoints

**Core Events**:
- `POST /events` - Receive hook events
- `GET /events/recent` - Get recent events
- `GET /events/filter-options` - Get filter options
- `WS /stream` - WebSocket for real-time updates

**AI Services**:
- `POST /api/ai/summarize` - Generate AI summaries of events
- `POST /api/ai/completion` - Generate completion messages

**Text-to-Speech**:
- `POST /api/tts` - Execute TTS with custom text
- `POST /api/tts/notification` - Quick notification TTS

**Development**:
- `GET /api/debug/env` - Check environment variables status

## Integration with Other Projects

### Easy Installation (Recommended)

Use the integrated installation system in `hooks-integration/`:

```bash
# Basic installation with auto-detection
python hooks-integration/install.py ~/target-project

# For Docker containers (disables AI summarization)
python hooks-integration/install.py /app --container

# Custom configuration
python hooks-integration/install.py ~/target-project \
  --project-name "My App" \
  --server-url "http://host.docker.internal:4000/events" \
  --no-tts --minimal
```

### What Gets Installed

The installer copies all necessary components:
- **All hook scripts** (`pre_tool_use.py`, `post_tool_use.py`, etc.) with security validation
- **Utility functions** (`utils/constants.py`, TTS scripts)  
- **Configuration file** (`hooks-config.json`) for project-specific settings
- **Settings file** (`settings.json`) with complete hook configuration

### Manual Installation (Legacy)

For manual setup:
1. Copy `hooks-integration/` contents to target project's `.claude/` directory
2. Edit `hooks-config.json` with project-specific settings
3. Ensure observability server is running

### Installation Features

- **Auto-detection**: Project names from git repos, package.json, or directory names
- **Configuration-driven**: Single `hooks-config.json` controls all behavior
- **Security preservation**: Dangerous command blocking and .env protection
- **Local fallbacks**: TTS and logging work even when server is unavailable
- **Minimal options**: Lightweight installations for CI/CD environments

## Security Features

Hook scripts include validation to:
- Block dangerous commands (`rm -rf`, etc.)
- Prevent access to sensitive files (`.env`, keys)
- Validate inputs before execution

## Architecture Notes

- **Real-time Updates**: WebSocket broadcasts events to all connected clients
- **Session Tracking**: Each Claude session gets unique ID for filtering
- **Dual Color System**: Apps have distinct colors, sessions have secondary colors
- **Auto-scroll**: Timeline auto-scrolls with manual override capability
- **Chart Visualization**: Live pulse chart shows event activity over time
- **Chat Transcript Storage**: Full conversation history available for Stop events

## Important File Locations

### Server & Client
- Main server: `apps/server/src/index.ts`
- Database operations: `apps/server/src/db.ts`
- AI services: `apps/server/src/ai.ts` (Claude/OpenAI integration)
- TTS services: `apps/server/src/tts.ts` (Text-to-Speech with UV path handling)
- Main client: `apps/client/src/App.vue`
- WebSocket logic: `apps/client/src/composables/useWebSocket.ts`

### Integration System
- Installation script: `hooks-integration/install.py`
- Hook templates: `hooks-integration/` (all hook scripts and utilities)
- Configuration template: `hooks-integration/hooks-config.template.json`

### Development Hooks (This Project)
- Core event sender: `.claude/hooks/send_event.py`
- AI-powered completion: `.claude/hooks/stop.py` (with session summarization)
- Hook configuration: `.claude/settings.json`
- Security validation: `.claude/hooks/pre_tool_use.py`
- TTS scripts: `.claude/hooks/utils/tts/` (ElevenLabs, OpenAI, pyttsx3)

### System Scripts
- PowerShell services: `scripts/` (start-services.ps1, stop-services.ps1, check-status.ps1)
- Interactive management: `manage-system.ps1`

### Installed Project Structure
After installation, target projects will have:
- Configuration: `.claude/hooks-config.json`
- Hook settings: `.claude/settings.json`  
- All hook scripts: `.claude/*.py`
- Utilities: `.claude/utils/`