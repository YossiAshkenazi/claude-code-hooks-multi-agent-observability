# Minimal Claude Code Hooks for Multi-Agent Observability

This is a minimal hooks package that sends events to the centralized observability server.
All AI processing (summarization, TTS, completions) happens on the server side.

## Installation

1. Copy this entire `hooks-minimal` folder to your project's `.claude/` directory
2. Edit `.claude/settings.json` and replace `PROJECT_NAME` with your actual project name
3. Ensure the observability server is running at `http://localhost:4000`

## Requirements

- Python 3.8+
- `uv` package manager (installed automatically by Claude Code)
- Observability server running at localhost:4000

## Features

- **Minimal dependencies**: No AI libraries needed locally
- **Server-side processing**: All AI operations happen on the server
- **Silent failures**: Never interrupts Claude Code workflow
- **TTS support**: Notifications and completion announcements via server
- **Chat transcript capture**: Automatically sends conversation history

## Configuration

The observability server must have these environment variables set:
- `ANTHROPIC_API_KEY` - For summarization and completion messages
- `OPENAI_API_KEY` (optional) - Fallback for AI operations
- `ELEVENLABS_API_KEY` (optional) - For high-quality TTS
- `ENGINEER_NAME` (optional) - For personalized messages

## Server Endpoints Used

- `POST /events` - Main event submission
- `POST /api/ai/summarize` - Event summarization
- `POST /api/ai/completion` - Completion messages
- `POST /api/tts` - Text-to-speech
- `POST /api/tts/notification` - Notification sounds

## Customization

Edit `settings.json` to:
- Change which events are captured
- Modify the source app name
- Add or remove hook types