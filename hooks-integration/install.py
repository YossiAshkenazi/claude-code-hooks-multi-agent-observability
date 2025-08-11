#!/usr/bin/env python3
"""
Enhanced install script for Claude Code observability hooks.
Uses configuration-based approach for easy project integration.
"""

import os
import sys
import json
import shutil
import subprocess
from pathlib import Path

def detect_project_name(target_path):
    """Try to detect project name from various sources."""
    target_path = Path(target_path)
    
    # Try git repo name first
    if (target_path / '.git').exists():
        try:
            result = subprocess.run(
                ['git', 'remote', 'get-url', 'origin'], 
                cwd=target_path, 
                capture_output=True, 
                text=True
            )
            if result.returncode == 0:
                # Extract repo name from git URL
                url = result.stdout.strip()
                if url:
                    repo_name = url.split('/')[-1].replace('.git', '')
                    if repo_name:
                        return repo_name
        except:
            pass
    
    # Try package.json
    package_json = target_path / 'package.json'
    if package_json.exists():
        try:
            with open(package_json, 'r') as f:
                data = json.load(f)
                name = data.get('name', '')
                if name:
                    return name
        except:
            pass
    
    # Try Cargo.toml
    cargo_toml = target_path / 'Cargo.toml'
    if cargo_toml.exists():
        try:
            with open(cargo_toml, 'r') as f:
                for line in f:
                    if line.strip().startswith('name = '):
                        name = line.split('=')[1].strip().strip('"\'')
                        if name:
                            return name
        except:
            pass
    
    # Fallback to directory name
    return target_path.name

def create_config_from_template(target_dir, project_name, server_url, features):
    """Create hooks-config.json from template."""
    config = {
        "source_app": project_name,
        "server_url": server_url,
        "features": features,
        "hooks": {
            "PreToolUse": {
                "enabled": True,
                "options": ["summarize"] if features.get("summarize") else []
            },
            "PostToolUse": {
                "enabled": True,
                "options": ["summarize"] if features.get("summarize") else []
            },
            "UserPromptSubmit": {
                "enabled": True,
                "options": ["summarize"] if features.get("summarize") else []
            },
            "Notification": {
                "enabled": features.get("tts_notifications", True),
                "options": ["notify"] if features.get("tts_notifications") else []
            },
            "Stop": {
                "enabled": True,
                "options": [
                    opt for opt in ["add-chat", "announce"] 
                    if features.get("chat_transcript" if opt == "add-chat" else "completion_announcements")
                ]
            },
            "SubagentStop": {
                "enabled": True,
                "options": []
            },
            "PreCompact": {
                "enabled": False,
                "options": []
            }
        }
    }
    
    config_path = target_dir / 'hooks-config.json'
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    return config_path

def create_settings_from_config(target_dir, config):
    """Create settings.json based on configuration."""
    settings = {"hooks": {}}
    
    for hook_type, hook_config in config["hooks"].items():
        if not hook_config.get("enabled", False):
            continue
            
        options = hook_config.get("options", [])
        command_parts = [
            "uv run .claude/send_event.py",
            f"--event-type {hook_type}"
        ] + [f"--{opt}" for opt in options]
        
        settings["hooks"][hook_type] = [{
            "matcher": "" if hook_type != "UserPromptSubmit" else None,
            "hooks": [{
                "type": "command",
                "command": " ".join(command_parts)
            }]
        }]
        
        # Remove None matcher for UserPromptSubmit
        if hook_type == "UserPromptSubmit":
            del settings["hooks"][hook_type][0]["matcher"]
    
    settings_path = target_dir / 'settings.json'
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
    
    return settings_path

def main():
    if len(sys.argv) < 2:
        print("Usage: python install.py <target_project_path> [options]")
        print("\nOptions:")
        print("  --project-name NAME    Override detected project name")
        print("  --server-url URL       Server URL (default: http://host.docker.internal:4000/events)")
        print("  --no-summarize         Disable AI summarization")
        print("  --no-tts               Disable TTS notifications")
        print("  --no-chat              Disable chat transcript capture")
        print("  --no-announce          Disable completion announcements")
        print("  --minimal              Install minimal hooks only (PreToolUse, PostToolUse, UserPromptSubmit)")
        print("  --container            Configure for Docker container (disables summarization)")
        print("\nExample: python install.py ~/my-project --project-name my-app")
        print("\nFor Docker containers: python install.py /app --container")
        sys.exit(1)
    
    # Parse arguments
    target_path = Path(sys.argv[1]).resolve()
    project_name = None
    server_url = "http://host.docker.internal:4000/events"
    features = {
        "summarize": True,
        "tts_notifications": True,
        "chat_transcript": True,
        "completion_announcements": True
    }
    minimal = False
    container_mode = False
    
    i = 2
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == "--project-name" and i + 1 < len(sys.argv):
            project_name = sys.argv[i + 1]
            i += 2
        elif arg == "--server-url" and i + 1 < len(sys.argv):
            server_url = sys.argv[i + 1]
            i += 2
        elif arg == "--no-summarize":
            features["summarize"] = False
            i += 1
        elif arg == "--no-tts":
            features["tts_notifications"] = False
            i += 1
        elif arg == "--no-chat":
            features["chat_transcript"] = False
            i += 1
        elif arg == "--no-announce":
            features["completion_announcements"] = False
            i += 1
        elif arg == "--minimal":
            minimal = True
            features = {"summarize": True, "tts_notifications": False, "chat_transcript": False, "completion_announcements": False}
            i += 1
        elif arg == "--container":
            container_mode = True
            # Containers should not do AI summarization (server-side only)
            features["summarize"] = False
            i += 1
        else:
            print(f"Unknown argument: {arg}")
            sys.exit(1)
    
    # Validate target path
    if not target_path.exists():
        print(f"Error: Target path {target_path} does not exist")
        sys.exit(1)
    
    # Detect or use provided project name
    if not project_name:
        project_name = detect_project_name(target_path)
        print(f"Detected project name: {project_name}")
    
    # Create .claude directory
    claude_dir = target_path / '.claude'
    claude_dir.mkdir(exist_ok=True)
    
    # Get source directory (where this script is located)
    source_dir = Path(__file__).parent
    
    # Copy all hook files
    print(f"Installing hooks to {claude_dir}...")
    
    # Core hook scripts
    hook_files = [
        'send_event.py',
        'pre_tool_use.py', 
        'post_tool_use.py',
        'user_prompt_submit.py',
        'notification.py',
        'stop.py',
        'subagent_stop.py'
    ]
    
    for hook_file in hook_files:
        src_file = source_dir / hook_file
        if src_file.exists():
            shutil.copy2(src_file, claude_dir / hook_file)
            print(f"  ✅ {hook_file}")
        else:
            print(f"  ⚠️  Warning: {hook_file} not found in source")
    
    # Copy utils directory
    utils_src = source_dir / 'utils'
    utils_dst = claude_dir / 'utils'
    if utils_src.exists():
        if utils_dst.exists():
            shutil.rmtree(utils_dst)
        shutil.copytree(utils_src, utils_dst)
        print(f"  ✅ utils/ directory")
    
    # Create configuration file
    config_path = create_config_from_template(claude_dir, project_name, server_url, features)
    print(f"Created configuration: {config_path}")
    
    # Load the created config
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    # Create settings.json from config
    settings_path = claude_dir / 'settings.json'
    if settings_path.exists():
        print(f"Warning: {settings_path} already exists.")
        response = input("Do you want to overwrite it? (y/n): ")
        if response.lower() != 'y':
            print("Keeping existing settings.json")
        else:
            create_settings_from_config(claude_dir, config)
            print(f"Updated settings.json for project: {project_name}")
    else:
        create_settings_from_config(claude_dir, config)
        print(f"Created settings.json for project: {project_name}")
    
    print("\n✅ Installation complete!")
    print("\nFiles installed:")
    print(f"  🔗 {claude_dir}/settings.json")
    print(f"  ⚙️  {claude_dir}/hooks-config.json")
    print(f"  📡 {claude_dir}/send_event.py")
    print(f"  🛡️  {claude_dir}/pre_tool_use.py (security validation)")
    print(f"  📄 {claude_dir}/post_tool_use.py")
    print(f"  💬 {claude_dir}/user_prompt_submit.py")
    print(f"  🔔 {claude_dir}/notification.py (TTS support)")
    print(f"  🏁 {claude_dir}/stop.py")
    print(f"  🤖 {claude_dir}/subagent_stop.py")
    print(f"  📁 {claude_dir}/utils/ (helper functions and TTS)")    
    
    print(f"\nProject configured as: {project_name}")
    print(f"Server URL: {server_url}")
    print(f"Features enabled:")
    for feature, enabled in features.items():
        status = "✅" if enabled else "❌"
        print(f"  {status} {feature.replace('_', ' ').title()}")
    
    if minimal:
        print("\n📦 Minimal installation - only core hooks enabled")
    
    if container_mode:
        print("\n🐳 Container mode - AI summarization disabled (handled server-side)")
    
    print("\nNext steps:")
    print("1. Ensure the observability server is running at the configured URL")
    print("2. Set up environment variables on the server (ANTHROPIC_API_KEY, etc.)")
    print("3. Customize hooks-config.json if needed")
    print("4. The hooks will now send events to the centralized server")
    
    print(f"\n💡 To modify settings later, edit: {claude_dir}/hooks-config.json")

if __name__ == '__main__':
    main()