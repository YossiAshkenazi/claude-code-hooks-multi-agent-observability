# Integration Guide: Centralized Multi-Agent Observability

This guide explains how to integrate other projects with the centralized observability system without needing to configure API keys in each project.

## 🎯 Overview

The new centralized approach means:
- **API keys stay centralized** in the observability server
- **Other projects** only need to copy `.claude` folder and set `APP_NAME` 
- **All AI API calls** are proxied through the observability server
- **No sensitive data** needs to be distributed across projects

## 🚀 Quick Integration

### Step 1: Start Observability Server

```bash
# Linux/macOS
./scripts/start-system.sh

# Windows  
.\scripts\start-services.ps1
```

### Step 2: Copy Integration Template to Your Project

```bash
# Linux/macOS
cp -R integration/.claude /path/to/your/project/
cp integration/.env.sample /path/to/your/project/

# Windows
Copy-Item -Recurse integration\.claude C:\path\to\your\project\
Copy-Item integration\.env.sample C:\path\to\your\project\
```

### Step 3: Configure Your Project

Rename `.env.sample` to `.env` and edit it:

```bash
# Application Configuration
APP_NAME=your-project-name

# Observability Server Configuration
# Leave blank for automatic discovery (tries localhost, then Docker fallback)
OBSERVABILITY_SERVER_URL=

# Engineer Name (optional)
ENGINEER_NAME=YourName
```

**For Docker containers**, the system automatically tries `host.docker.internal:4000` when `localhost:4000` fails.

### Step 4: Done! 

Your project now sends events to the centralized observability dashboard with AI summarization and TTS notifications.

## 📁 What Gets Copied

The `integration/.claude` folder contains:

```
integration/
├── .env.sample              # Environment template
└── .claude/                 # Claude Code hooks folder
    ├── settings.json        # Hook configuration (no app name hardcoded)
    └── hooks/               # Hook scripts
        ├── send_event.py    # Centralized event sender
        └── utils/           # Utility modules
            ├── summarizer.py    # AI event summarization
            ├── server_discovery.py # Server URL discovery
            └── llm/         # Centralized LLM clients
                ├── anth.py  # Anthropic proxy client
                └── oai.py   # OpenAI proxy client
```

## 🔧 Configuration Details

### Environment Variables

**Required:**
- `APP_NAME` - Unique identifier for your project

**Optional:**
- `OBSERVABILITY_SERVER_URL` - Server URL (auto-discovery if blank)
- `ENGINEER_NAME` - Your name for personalized notifications

### Docker Support 🐳

The system automatically handles Docker networking:

1. **Auto-discovery**: Leave `OBSERVABILITY_SERVER_URL` blank
2. **Fallback chain**: 
   - Tries `localhost:4000` first (for local development)
   - Falls back to `host.docker.internal:4000` (for Docker containers)
3. **Manual override**: Set explicit URL if needed

**Docker Compose Example:**
```yaml
services:
  your-app:
    image: your-app:latest
    environment:
      - APP_NAME=your-docker-app
      - ENGINEER_NAME=YourName
      # OBSERVABILITY_SERVER_URL left blank for auto-discovery
    volumes:
      - ./.claude:/app/.claude
```

### settings.json Changes

The `settings.json` now uses environment variables instead of hardcoded app names:

```json
{
  "hooks": {
    "PreToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "uv run .claude/hooks/send_event.py --event-type PreToolUse --summarize"
      }]
    }]
  }
}
```

The `--source-app` argument is automatically resolved from `APP_NAME` environment variable.

## 🔗 Centralized API Endpoints

The observability server provides these proxy endpoints:

### Anthropic API Proxy
```
POST http://localhost:4000/api/llm/anthropic

Request Body: Standard Anthropic API request
Response: { "success": boolean, "data": anthropic_response }
```

### OpenAI API Proxy  
```
POST http://localhost:4000/api/llm/openai

Request Body: Standard OpenAI API request
Response: { "success": boolean, "data": openai_response }
```

### TTS Notifications
```
POST http://localhost:4000/api/tts/notification

Request Body: { "engineer_name": "optional" }
Response: { "success": boolean, "message": string }
```

## 🧪 Testing Integration

### Test Server Discovery

```bash
# Test server discovery utility
uv run .claude/hooks/utils/server_discovery.py

# Test specific URL
uv run .claude/hooks/utils/server_discovery.py http://localhost:4000
```

### Test Event Sending

```bash
# Test event sending (from your project directory)
echo '{"session_id":"test-123","test":"data"}' | uv run .claude/hooks/send_event.py --event-type PreToolUse

# Check observability dashboard
open http://localhost:5173
```

### Docker Testing

```bash
# Test from Docker container
docker run --rm -v $(pwd)/.claude:/app/.claude \
  -e APP_NAME=docker-test \
  python:3.9 \
  bash -c "cd /app && echo '{\"session_id\":\"docker-test\"}' | uv run .claude/hooks/send_event.py --event-type PreToolUse"
```

## 🔒 Security Benefits

- **API keys centralized** - Only the observability server needs API keys
- **No key distribution** - Projects never handle sensitive credentials  
- **Single point of configuration** - Update API keys in one place
- **Access control** - Server can implement rate limiting, logging, etc.

## 📊 Features Available

All standard observability features work with the centralized approach:

- ✅ Real-time event monitoring
- ✅ AI-powered event summarization  
- ✅ TTS notifications
- ✅ Session tracking and filtering
- ✅ Chat transcript storage
- ✅ Multi-project support with color coding

## 🚨 Troubleshooting

**"APP_NAME environment variable is required"**
- Create `.env` file with `APP_NAME=your-project-name`

**"Could not discover observability server"**
- Ensure observability server is running on port 4000
- For Docker: Check that `host.docker.internal` resolves
- Test manually: `uv run .claude/hooks/utils/server_discovery.py`

**"Failed to proxy Anthropic/OpenAI API request"**  
- Ensure observability server is running
- Check API keys are configured in observability server's `.env`

**Events not appearing in dashboard**
- Test server discovery: `uv run .claude/hooks/utils/server_discovery.py`
- Check server logs: `logs/server.log`
- Verify Docker networking if running in container

**Docker containers can't reach server**
- Ensure observability server is accessible from container network
- Try explicit URL: `OBSERVABILITY_SERVER_URL=http://host.docker.internal:4000`
- For Docker Compose: Use service name or `host.docker.internal`

**AI summarization not working**
- Ensure `ANTHROPIC_API_KEY` is set in observability server
- Check server proxy endpoints are accessible
- Test: `curl http://localhost:4000/api/llm/anthropic`