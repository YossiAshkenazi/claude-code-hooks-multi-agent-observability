const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const platformDetection = require('./platform-detection.js');

/**
 * Universal Hook Wrapper - Routes hook calls to appropriate platform-specific implementations
 */
class UniversalHookWrapper {
  constructor(options = {}) {
    this.debug = options.debug || process.env.DEBUG === 'true';
    this.timeout = options.timeout || 30000; // 30 second default timeout
    this.hookDir = options.hookDir || path.join(__dirname, '..', 'hooks');
  }

  /**
   * Log debug messages if debug mode is enabled
   * @param {string} message - Debug message
   */
  _debug(message) {
    if (this.debug) {
      console.log(`[DEBUG] UniversalHookWrapper: ${message}`);
    }
  }

  /**
   * Get the appropriate script path for the current platform
   * @param {string} hookName - Name of the hook (e.g., 'user-prompt-submit-hook')
   * @param {string} platform - Platform identifier from platformDetection
   * @returns {string} - Absolute path to the platform-specific script
   */
  getScriptPath(hookName, platform) {
    const extension = this._getScriptExtension(platform);
    const scriptName = `${hookName}${extension}`;
    const scriptPath = path.resolve(this.hookDir, scriptName);
    
    this._debug(`Resolved script path: ${scriptPath} for platform: ${platform}`);
    return scriptPath;
  }

  /**
   * Get the appropriate script extension for the platform
   * @param {string} platform - Platform identifier
   * @returns {string} - File extension (.ps1, .sh)
   */
  _getScriptExtension(platform) {
    switch (platform) {
      case 'windows':
      case 'cygwin':
        return '.ps1';
      case 'wsl':
      case 'linux':
      case 'macos':
      case 'mingw':
        return '.sh';
      default:
        this._debug(`Unknown platform: ${platform}, defaulting to .sh`);
        return '.sh';
    }
  }

  /**
   * Get the appropriate command executor for the platform
   * @param {string} platform - Platform identifier
   * @param {string} scriptPath - Path to the script
   * @returns {object} - Command and arguments for execution
   */
  _getExecutionCommand(platform, scriptPath) {
    switch (platform) {
      case 'windows':
        return {
          command: 'powershell.exe',
          args: ['-ExecutionPolicy', 'Bypass', '-File', scriptPath]
        };
      case 'cygwin':
        // Cygwin can run PowerShell scripts if available
        return {
          command: 'powershell.exe',
          args: ['-ExecutionPolicy', 'Bypass', '-File', scriptPath]
        };
      case 'wsl':
      case 'linux':
      case 'macos':
        return {
          command: 'bash',
          args: [scriptPath]
        };
      case 'mingw':
        // Git Bash environment
        return {
          command: 'bash',
          args: [scriptPath]
        };
      default:
        this._debug(`Unknown platform: ${platform}, defaulting to bash`);
        return {
          command: 'bash',
          args: [scriptPath]
        };
    }
  }

  /**
   * Validate that the platform-specific script exists
   * @param {string} scriptPath - Path to the script
   * @returns {Promise<boolean>} - True if script exists and is accessible
   */
  async validateScript(scriptPath) {
    try {
      await fs.promises.access(scriptPath, fs.constants.F_OK | fs.constants.R_OK);
      this._debug(`Script validation passed: ${scriptPath}`);
      return true;
    } catch (error) {
      this._debug(`Script validation failed: ${scriptPath} - ${error.message}`);
      return false;
    }
  }

  /**
   * Create JSON data from Claude environment variables
   * @returns {string|null} - JSON string or null if no data available
   */
  _createClaudeJSON() {
    const env = process.env;
    
    // Check if we have any Claude environment variables
    const claudeVars = Object.keys(env).filter(key => key.startsWith('CLAUDE_'));
    if (claudeVars.length === 0) {
      this._debug('No Claude environment variables found');
      return null;
    }

    // Create JSON object from Claude environment variables
    const claudeData = {
      session_id: env.CLAUDE_SESSION_ID || '',
      cwd: env.CLAUDE_PROJECT_PATH || env.PWD || process.cwd(),
      transcript_path: env.CLAUDE_TRANSCRIPT_PATH || '',
      // Hook-specific data
      prompt: env.CLAUDE_USER_PROMPT || env.CLAUDE_MESSAGE || '',
      message: env.CLAUDE_NOTIFICATION_MESSAGE || env.CLAUDE_MESSAGE || '',
      tool_name: env.CLAUDE_TOOL_NAME || '',
      tool_args: env.CLAUDE_TOOL_ARGS || '',
      tool_result: env.CLAUDE_TOOL_RESULT || '',
      // Additional context
      user: env.USERNAME || env.USER || '',
      platform: platformDetection.detectPlatform(),
      timestamp: new Date().toISOString()
    };

    // Remove empty values
    Object.keys(claudeData).forEach(key => {
      if (!claudeData[key]) {
        delete claudeData[key];
      }
    });

    const jsonString = JSON.stringify(claudeData);
    this._debug(`Created Claude JSON data: ${jsonString}`);
    return jsonString;
  }

  /**
   * Execute a hook with the given arguments
   * @param {string} hookName - Name of the hook
   * @param {Array<string>} args - Arguments to pass to the hook
   * @param {object} options - Execution options
   * @returns {Promise<object>} - Execution result with stdout, stderr, exitCode
   */
  async executeHook(hookName, args = [], options = {}) {
    const startTime = Date.now();
    
    // Detect platform
    const platform = platformDetection.detectPlatform();
    this._debug(`Detected platform: ${platform}`);

    // Validate environment
    const validation = platformDetection.validateEnvironment();
    if (!validation.isValid) {
      const error = new Error(`Invalid environment for hook execution: ${validation.warnings.join(', ')}`);
      return {
        stdout: '',
        stderr: error.message,
        exitCode: 1,
        error,
        executionTime: Date.now() - startTime
      };
    }

    // Get script path
    const scriptPath = this.getScriptPath(hookName, platform);
    
    // Validate script exists
    const scriptExists = await this.validateScript(scriptPath);
    if (!scriptExists) {
      const error = new Error(`Hook script not found: ${scriptPath}`);
      return {
        stdout: '',
        stderr: error.message,
        exitCode: 1,
        error,
        executionTime: Date.now() - startTime
      };
    }

    // Get execution command
    const { command, args: baseArgs } = this._getExecutionCommand(platform, scriptPath);
    const allArgs = [...baseArgs, ...args];

    this._debug(`Executing: ${command} ${allArgs.join(' ')}`);

    // Create JSON from Claude environment variables
    const claudeData = this._createClaudeJSON();
    
    // Execute the script
    return new Promise((resolve) => {
      const child = spawn(command, allArgs, {
        env: { ...process.env, ...options.env },
        cwd: options.cwd || process.cwd(),
        stdio: ['pipe', 'pipe', 'pipe']  // Enable stdin pipe
      });

      let stdout = '';
      let stderr = '';
      let resolved = false;

      // Send JSON data to stdin if available
      if (claudeData && child.stdin) {
        this._debug(`Sending JSON to stdin: ${claudeData}`);
        child.stdin.write(claudeData);
        child.stdin.end();
      }

      // Set up timeout
      const timeoutId = setTimeout(() => {
        if (!resolved) {
          resolved = true;
          child.kill('SIGTERM');
          
          setTimeout(() => {
            if (!child.killed) {
              child.kill('SIGKILL');
            }
          }, 5000);

          resolve({
            stdout,
            stderr: stderr + `\nProcess timed out after ${this.timeout}ms`,
            exitCode: 124,
            error: new Error(`Process timed out after ${this.timeout}ms`),
            executionTime: Date.now() - startTime
          });
        }
      }, options.timeout || this.timeout);

      // Handle output
      if (child.stdout) {
        child.stdout.on('data', (data) => {
          stdout += data.toString();
        });
      }

      if (child.stderr) {
        child.stderr.on('data', (data) => {
          stderr += data.toString();
        });
      }

      // Handle completion
      child.on('close', (code, signal) => {
        if (!resolved) {
          resolved = true;
          clearTimeout(timeoutId);
          
          const executionTime = Date.now() - startTime;
          this._debug(`Hook execution completed in ${executionTime}ms with code: ${code}`);

          resolve({
            stdout,
            stderr,
            exitCode: code || 0,
            signal,
            executionTime
          });
        }
      });

      // Handle errors
      child.on('error', (error) => {
        if (!resolved) {
          resolved = true;
          clearTimeout(timeoutId);
          
          resolve({
            stdout,
            stderr: stderr + `\nExecution error: ${error.message}`,
            exitCode: 1,
            error,
            executionTime: Date.now() - startTime
          });
        }
      });
    });
  }

  /**
   * Execute a hook with automatic platform detection and error handling
   * This is the main entry point for universal hook execution
   * @param {string} hookName - Name of the hook
   * @param {Array<string>} args - Arguments to pass to the hook
   * @param {object} options - Execution options
   * @returns {Promise<object>} - Execution result
   */
  async run(hookName, args = [], options = {}) {
    try {
      const result = await this.executeHook(hookName, args, options);
      
      // Log performance warning if execution is slow
      if (result.executionTime > 50) {
        this._debug(`WARNING: Hook execution took ${result.executionTime}ms (> 50ms threshold)`);
      }

      return result;
    } catch (error) {
      this._debug(`Unexpected error during hook execution: ${error.message}`);
      return {
        stdout: '',
        stderr: `Unexpected error: ${error.message}`,
        exitCode: 1,
        error,
        executionTime: 0
      };
    }
  }

  /**
   * Get information about available hooks for the current platform
   * @returns {object} - Information about available hooks
   */
  async getHookInfo() {
    const platform = platformDetection.detectPlatform();
    const hookTypes = [
      'user-prompt-submit-hook',
      'pre-tool-use-hook',
      'post-tool-use-hook',
      'notification-hook',
      'pre-compact-hook',
      'stop-hook',
      'subagent-stop-hook'
    ];

    const hookInfo = {
      platform,
      availableHooks: [],
      missingHooks: []
    };

    for (const hookName of hookTypes) {
      const scriptPath = this.getScriptPath(hookName, platform);
      const exists = await this.validateScript(scriptPath);
      
      if (exists) {
        hookInfo.availableHooks.push({ name: hookName, path: scriptPath });
      } else {
        hookInfo.missingHooks.push({ name: hookName, expectedPath: scriptPath });
      }
    }

    return hookInfo;
  }
}

module.exports = UniversalHookWrapper;