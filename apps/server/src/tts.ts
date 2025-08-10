import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

interface TTSRequest {
  text: string;
  engineer_name?: string;
}

interface TTSResponse {
  success: boolean;
  message: string;
  method_used?: string;
  error?: string;
}

/**
 * Find UV executable path
 */
function getUVPath(): string {
  // Check environment variable first
  if (process.env.UV_PATH) {
    return process.env.UV_PATH;
  }
  
  // For Windows, use the known working path
  if (process.platform === 'win32') {
    // Try the common installation path directly
    const commonPath = 'C:\\Users\\יוסי\\.local\\bin\\uv.exe';
    if (existsSync(commonPath)) {
      return commonPath;
    }
    
    // Fallback to PATH resolution
    return 'uv';
  }
  
  // Check common installation paths for non-Windows
  const commonPaths = [
    'uv', // Try PATH first
    join(homedir(), '.local', 'bin', 'uv'),
    '/usr/local/bin/uv',
    '/opt/homebrew/bin/uv',
  ];
  
  for (const path of commonPaths) {
    try {
      if (path === 'uv') {
        return path;
      }
      if (existsSync(path)) {
        return path;
      }
    } catch (error) {
      continue;
    }
  }
  
  return 'uv'; // Fallback to hoping it's in PATH
}

/**
 * Get the path to the best available TTS script
 * Priority: ElevenLabs > OpenAI > pyttsx3
 */
function getTTSScriptPath(): string | null {
  // Get the project root (two levels up from apps/server/src)
  const projectRoot = join(import.meta.dir, '..', '..', '..');
  const ttsDir = join(projectRoot, '.claude', 'hooks', 'utils', 'tts');
  
  // Check for ElevenLabs (highest priority)
  if (process.env.ELEVENLABS_API_KEY) {
    const elevenlabsScript = join(ttsDir, 'elevenlabs_tts.py');
    if (existsSync(elevenlabsScript)) {
      return elevenlabsScript;
    }
  }
  
  // Check for OpenAI (second priority)
  if (process.env.OPENAI_API_KEY) {
    const openaiScript = join(ttsDir, 'openai_tts.py');
    if (existsSync(openaiScript)) {
      return openaiScript;
    }
  }
  
  // Fall back to pyttsx3 (no API key required)
  const pyttsx3Script = join(ttsDir, 'pyttsx3_tts.py');
  if (existsSync(pyttsx3Script)) {
    return pyttsx3Script;
  }
  
  return null;
}

/**
 * Generate notification message with optional engineer name
 */
function generateNotificationMessage(engineerName?: string): string {
  if (engineerName && Math.random() < 0.3) {
    return `${engineerName}, your agent needs your input`;
  }
  return "Your agent needs your input";
}

/**
 * Execute TTS using the best available method
 */
export async function executeTTS(request: TTSRequest): Promise<TTSResponse> {
  const ttsScript = getTTSScriptPath();
  
  if (!ttsScript) {
    return {
      success: false,
      message: "No TTS scripts available",
      error: "No TTS scripts found and no API keys configured"
    };
  }
  
  const text = request.text || generateNotificationMessage(request.engineer_name);
  
  return new Promise((resolve) => {
    try {
      // Execute TTS script using uv with full path
      const uvPath = getUVPath();
      // Set up clean environment for UV
      const env = { ...process.env };
      if (process.platform === 'win32') {
        // Set a clean temp directory to avoid encoding issues
        env.TEMP = 'C:\\Windows\\Temp';
        env.TMP = 'C:\\Windows\\Temp';
        // Use safe UV directories to avoid encoding issues
        env.UV_CACHE_DIR = 'C:\\Windows\\Temp\\uv-cache';
        env.UV_PYTHON_INSTALL_DIR = 'C:\\Windows\\Temp\\uv-python';
        env.UV_TOOL_DIR = 'C:\\Windows\\Temp\\uv-tools';
        // Disable UV config file to avoid path issues
        env.UV_NO_CONFIG = '1';
        // Override user profile to safe location
        env.APPDATA = 'C:\\Windows\\Temp';
      }
      
      const childProcess = spawn(uvPath, ['run', ttsScript, text], {
        stdio: ['ignore', 'pipe', 'pipe'],
        shell: true, // Enable shell to resolve PATH on Windows
        env: env, // Use modified environment
        timeout: 15000 // 15 second timeout
      });
      
      let stdout = '';
      let stderr = '';
      
      childProcess.stdout?.on('data', (data: Buffer) => {
        stdout += data.toString();
      });
      
      childProcess.stderr?.on('data', (data: Buffer) => {
        stderr += data.toString();
      });
      
      childProcess.on('close', (code: number | null) => {
        const methodUsed = ttsScript.includes('elevenlabs') ? 'ElevenLabs' :
                          ttsScript.includes('openai') ? 'OpenAI' :
                          ttsScript.includes('pyttsx3') ? 'pyttsx3' : 'Unknown';
        
        if (code === 0) {
          resolve({
            success: true,
            message: `TTS completed successfully using ${methodUsed}`,
            method_used: methodUsed
          });
        } else {
          resolve({
            success: false,
            message: `TTS failed with exit code ${code}`,
            method_used: methodUsed,
            error: stderr || stdout || 'Unknown error'
          });
        }
      });
      
      childProcess.on('error', (error: Error) => {
        resolve({
          success: false,
          message: "Failed to execute TTS script",
          error: error.message
        });
      });
      
    } catch (error) {
      resolve({
        success: false,
        message: "TTS execution failed",
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
}

/**
 * Quick TTS for notifications - uses default message
 */
export async function speakNotification(engineerName?: string): Promise<TTSResponse> {
  return executeTTS({
    text: generateNotificationMessage(engineerName)
  });
}