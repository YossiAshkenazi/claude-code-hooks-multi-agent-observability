# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-Agent Observability System for Claude Code - a real-time monitoring and visualization platform that captures, stores, and displays Claude Code hook events through a full-stack TypeScript/Vue application with Python hooks.

## Architecture

```
Claude Agents ’ Hook Scripts (Python/uv) ’ HTTP POST ’ Bun Server ’ SQLite ’ WebSocket ’ Vue Client
```

The system consists of:
- **Python Hook Scripts** (`.claude/hooks/`) - Capture Claude Code lifecycle events using `uv` package manager
- **Bun Server** (`apps/server/`) - TypeScript server with HTTP/WebSocket endpoints and SQLite storage
- **Vue Client** (`apps/client/`) - Real-time dashboard with filtering and visualization
- **SQLite Database** - Event storage with session tracking

## Development Commands

### System Management
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
- **Stop/SubagentStop**: Session completion tracking

Each hook runs both validation logic and sends observability data to the server.

## Event Types & Visualization

| Event Type | Emoji | Purpose | Display |
|------------|--------|---------|---------|
| PreToolUse | =' | Before tool execution | Tool name & inputs |
| PostToolUse |  | After tool completion | Results & outputs |
| UserPromptSubmit | =¬ | User prompt | Prompt text (italic) |
| Notification | = | User interactions | Notification message |
| Stop | =Ñ | Response completion | Chat transcript |
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

## Integration with Other Projects

To add observability to other Claude Code projects:

1. Copy `.claude/` directory to target project
2. Update `source-app` parameter in `.claude/settings.json`
3. Ensure observability server is running

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

- Main server: `apps/server/src/index.ts`
- Database operations: `apps/server/src/db.ts`
- Main client: `apps/client/src/App.vue`
- WebSocket logic: `apps/client/src/composables/useWebSocket.ts`
- Core event sender: `.claude/hooks/send_event.py`
- Hook configuration: `.claude/settings.json`