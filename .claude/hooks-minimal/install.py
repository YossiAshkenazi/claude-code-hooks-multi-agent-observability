#!/usr/bin/env python3
"""
Install script for minimal Claude Code hooks.
Copies hooks to target project and configures them.
"""

import os
import sys
import json
import shutil
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        print("Usage: python install.py <target_project_path> [project_name]")
        print("Example: python install.py ~/my-project my-project")
        sys.exit(1)
    
    target_path = Path(sys.argv[1]).resolve()
    project_name = sys.argv[2] if len(sys.argv) > 2 else target_path.name
    
    # Validate target path
    if not target_path.exists():
        print(f"Error: Target path {target_path} does not exist")
        sys.exit(1)
    
    # Create .claude directory if it doesn't exist
    claude_dir = target_path / '.claude'
    claude_dir.mkdir(exist_ok=True)
    
    # Get the source directory (where this script is located)
    source_dir = Path(__file__).parent
    
    # Copy send_event.py
    print(f"Installing hooks to {claude_dir}...")
    shutil.copy2(source_dir / 'send_event.py', claude_dir / 'send_event.py')
    
    # Read and modify settings.json
    with open(source_dir / 'settings.json', 'r') as f:
        settings = json.load(f)
    
    # Replace PROJECT_NAME with actual project name
    settings_str = json.dumps(settings, indent=2)
    settings_str = settings_str.replace('PROJECT_NAME', project_name)
    settings = json.loads(settings_str)
    
    # Check if settings.json already exists
    settings_path = claude_dir / 'settings.json'
    if settings_path.exists():
        print(f"Warning: {settings_path} already exists.")
        response = input("Do you want to overwrite it? (y/n): ")
        if response.lower() != 'y':
            print("Keeping existing settings.json")
        else:
            with open(settings_path, 'w') as f:
                json.dump(settings, f, indent=2)
            print(f"Updated settings.json with project name: {project_name}")
    else:
        with open(settings_path, 'w') as f:
            json.dump(settings, f, indent=2)
        print(f"Created settings.json with project name: {project_name}")
    
    # Copy README for reference
    shutil.copy2(source_dir / 'README.md', claude_dir / 'HOOKS_README.md')
    
    print("\n✅ Installation complete!")
    print("\nNext steps:")
    print("1. Ensure the observability server is running at http://localhost:4000")
    print("2. Set up environment variables on the server (ANTHROPIC_API_KEY, etc.)")
    print("3. The hooks will now send events to the centralized server")
    print(f"\nProject configured as: {project_name}")
    print(f"Hooks installed to: {claude_dir}")

if __name__ == '__main__':
    main()