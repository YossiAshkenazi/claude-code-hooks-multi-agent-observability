const os = require('os');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

/**
 * Detects the current platform
 * @returns {string} Platform identifier: 'windows', 'wsl', 'linux', 'macos', 'cygwin', 'mingw', or 'unknown'
 */
function detectPlatform() {
  const platform = process.platform;
  
  // Check for Windows
  if (platform === 'win32') {
    // Check for Git Bash / MinGW
    if (process.env.MSYSTEM && process.env.MSYSTEM.startsWith('MINGW')) {
      return 'mingw';
    }
    
    // Check for Cygwin
    if (process.env.TERM === 'cygwin') {
      return 'cygwin';
    }
    
    return 'windows';
  }
  
  // Check for macOS
  if (platform === 'darwin') {
    return 'macos';
  }
  
  // Check for Linux or WSL
  if (platform === 'linux') {
    // Check for WSL
    if (isWSL()) {
      return 'wsl';
    }
    return 'linux';
  }
  
  return 'unknown';
}

/**
 * Checks if running on Windows
 * @returns {boolean}
 */
function isWindows() {
  return process.platform === 'win32';
}

/**
 * Checks if running in WSL (Windows Subsystem for Linux)
 * @returns {boolean}
 */
function isWSL() {
  // Check environment variables
  if (process.env.WSL_DISTRO_NAME || process.env.WSL_INTEROP) {
    return true;
  }
  
  // Check for WSL in /proc/version
  try {
    if (fs.existsSync('/proc/version')) {
      const procVersion = fs.readFileSync('/proc/version', 'utf8').toLowerCase();
      if (procVersion.includes('microsoft') || procVersion.includes('wsl')) {
        return true;
      }
    }
  } catch (e) {
    // Silent fail
  }
  
  // Check for WSL specific files
  if (fs.existsSync('/mnt/c') || fs.existsSync('/mnt/wsl')) {
    return true;
  }
  
  return false;
}

/**
 * Checks if running on Linux (not WSL)
 * @returns {boolean}
 */
function isLinux() {
  return process.platform === 'linux' && !isWSL();
}

/**
 * Checks if running on macOS
 * @returns {boolean}
 */
function isMacOS() {
  return process.platform === 'darwin';
}

/**
 * Gets the available shell type
 * @returns {string} Shell type: 'powershell', 'bash', 'zsh', 'git-bash', or 'unknown'
 */
function getShellType() {
  const platform = detectPlatform();
  
  // Windows platforms
  if (platform === 'windows') {
    // Check if PowerShell is available
    try {
      execSync('powershell -Command "Get-Host"', { stdio: 'ignore' });
      return 'powershell';
    } catch (e) {
      // PowerShell not available
    }
    
    // Check for cmd
    try {
      execSync('cmd /c echo test', { stdio: 'ignore' });
      return 'cmd';
    } catch (e) {
      // cmd not available
    }
  }
  
  // Git Bash on Windows
  if (platform === 'mingw') {
    return 'git-bash';
  }
  
  // Unix-like platforms (WSL, Linux, macOS)
  if (platform === 'wsl' || platform === 'linux' || platform === 'macos') {
    // Check current shell
    const shell = process.env.SHELL || '';
    
    if (shell.includes('zsh')) {
      return 'zsh';
    }
    
    if (shell.includes('bash')) {
      return 'bash';
    }
    
    // Default to bash for Unix-like systems
    return 'bash';
  }
  
  return 'unknown';
}

/**
 * Validates the current environment for hook execution
 * @returns {object} Validation result with isValid, platform, shell, and warnings
 */
function validateEnvironment() {
  const platform = detectPlatform();
  const shell = getShellType();
  const warnings = [];
  let isValid = true;
  
  // Check for unsupported platforms
  if (platform === 'unknown') {
    warnings.push('Unsupported platform detected');
    isValid = false;
  }
  
  // Check for unsupported shells
  if (shell === 'unknown') {
    warnings.push('No supported shell detected');
    isValid = false;
  }
  
  // Warn about edge case environments
  if (platform === 'cygwin') {
    warnings.push('Cygwin detected - some features may not work correctly');
  }
  
  if (platform === 'mingw') {
    warnings.push('Git Bash detected - using bash compatibility mode');
  }
  
  // Check for required commands
  const requiredCommands = {
    'windows': ['powershell'],
    'wsl': ['bash', 'curl'],
    'linux': ['bash', 'curl'],
    'macos': ['bash', 'curl'],
    'mingw': ['bash', 'curl'],
    'cygwin': ['bash', 'curl']
  };
  
  const platformCommands = requiredCommands[platform] || [];
  for (const cmd of platformCommands) {
    try {
      if (cmd === 'powershell') {
        execSync('powershell -Command "Get-Host"', { stdio: 'ignore' });
      } else if (cmd === 'curl') {
        execSync('which curl', { stdio: 'ignore' });
      } else if (cmd === 'bash') {
        execSync('which bash', { stdio: 'ignore' });
      }
    } catch (e) {
      warnings.push(`Required command '${cmd}' not found`);
      isValid = false;
    }
  }
  
  return {
    isValid,
    platform,
    shell,
    warnings
  };
}

/**
 * Gets comprehensive platform information
 * @returns {object} Platform information including OS, architecture, version, etc.
 */
function getPlatformInfo() {
  const platform = detectPlatform();
  const shell = getShellType();
  
  const info = {
    platform,
    isWSL: isWSL(),
    shell,
    arch: os.arch(),
    version: os.release(),
    hostname: os.hostname(),
    homedir: os.homedir(),
    tmpdir: os.tmpdir(),
    env: {
      home: process.env.HOME || process.env.USERPROFILE,
      shell: process.env.SHELL,
      path: process.env.PATH
    }
  };
  
  // Add WSL-specific information
  if (info.isWSL) {
    info.wslDistro = process.env.WSL_DISTRO_NAME;
    info.wslInterop = process.env.WSL_INTEROP;
    
    // Try to get Windows host info
    try {
      const winVer = execSync('cmd.exe /c ver', { encoding: 'utf8' }).trim();
      info.windowsHost = winVer;
    } catch (e) {
      // Silent fail
    }
  }
  
  // Add Windows-specific information
  if (platform === 'windows') {
    info.windowsVersion = os.version ? os.version() : 'Unknown';
    info.systemRoot = process.env.SystemRoot;
    info.programFiles = process.env.ProgramFiles;
  }
  
  // Add Git Bash specific information
  if (platform === 'mingw') {
    info.msystem = process.env.MSYSTEM;
    info.mingwPrefix = process.env.MINGW_PREFIX;
  }
  
  return info;
}

/**
 * Logs debug information about the platform
 * @param {boolean} verbose - Whether to include verbose output
 */
function logPlatformDebug(verbose = false) {
  console.log('=== Platform Detection Debug Info ===');
  
  const info = getPlatformInfo();
  const validation = validateEnvironment();
  
  console.log(`Platform: ${info.platform}`);
  console.log(`Shell: ${info.shell}`);
  console.log(`Architecture: ${info.arch}`);
  console.log(`OS Version: ${info.version}`);
  console.log(`Home Directory: ${info.homedir}`);
  
  if (info.isWSL) {
    console.log(`WSL Distro: ${info.wslDistro}`);
  }
  
  if (validation.warnings.length > 0) {
    console.log('\nWarnings:');
    validation.warnings.forEach(warning => {
      console.log(`  - ${warning}`);
    });
  }
  
  if (verbose) {
    console.log('\nEnvironment Variables:');
    console.log(`  HOME: ${info.env.home}`);
    console.log(`  SHELL: ${info.env.shell}`);
    console.log(`  PATH: ${info.env.path}`);
    
    if (info.isWSL) {
      console.log(`  WSL_INTEROP: ${info.wslInterop}`);
    }
  }
  
  console.log(`\nEnvironment Valid: ${validation.isValid ? 'Yes' : 'No'}`);
  console.log('=====================================');
}

module.exports = {
  detectPlatform,
  isWindows,
  isWSL,
  isLinux,
  isMacOS,
  getShellType,
  validateEnvironment,
  getPlatformInfo,
  logPlatformDebug
};