#!/usr/bin/env bash
# =============================================================================
# JakeFlanagan/Dotfiles — One-shot installer
# Usage:
#   From within cloned repo:  bash OMZ/install.sh
#   One-liner (auto-clones):  bash <(curl -fsSL https://raw.githubusercontent.com/JakeFlanagan/Dotfiles/main/OMZ/install.sh)
# =============================================================================

set -euo pipefail

REPO_URL="https://github.com/JakeFlanagan/Dotfiles.git"
REPO_DIR="$HOME/dotfiles"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $*"; exit 1; }

# ── OS Detection ─────────────────────────────────────────────────────────────
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
  elif command -v uname &>/dev/null; then
    OS_ID="$(uname -s | tr '[:upper:]' '[:lower:]')"
  else
    error "Cannot detect OS."
  fi

  case "$OS_ID" in
    ubuntu|debian|linuxmint|pop|kali)   PKG_MANAGER="apt" ;;
    fedora|rhel|centos|rocky|almalinux) PKG_MANAGER="dnf" ;;
    arch|manjaro|endeavouros)           PKG_MANAGER="pacman" ;;
    alpine)                             PKG_MANAGER="apk" ;;
    *)
      # Fallback: check ID_LIKE
      case "$OS_ID_LIKE" in
        *debian*|*ubuntu*) PKG_MANAGER="apt"    ;;
        *fedora*|*rhel*)   PKG_MANAGER="dnf"    ;;
        *arch*)            PKG_MANAGER="pacman" ;;
        *)                 error "Unsupported OS: $OS_ID. Install zsh, git, curl, gawk manually and re-run." ;;
      esac
      ;;
  esac

  info "Detected OS: ${BOLD}$OS_ID${RESET} (package manager: ${BOLD}$PKG_MANAGER${RESET})"
}

# ── Package Installation ──────────────────────────────────────────────────────
install_pkg() {
  case "$PKG_MANAGER" in
    apt)
      sudo apt-get update -qq
      sudo apt-get install -y "$@"
      ;;
    dnf)
      sudo dnf install -y "$@"
      ;;
    pacman)
      sudo pacman -Sy --noconfirm "$@"
      ;;
    apk)
      # Alpine often runs as root (LXC/container); fall back gracefully if sudo absent
      if command -v sudo &>/dev/null; then
        sudo apk add --no-cache "$@"
      else
        apk add --no-cache "$@"
      fi
      ;;
  esac
}

install_deps() {
  info "Checking dependencies..."

  # bash included — Alpine doesn't ship it by default, and the script needs it
  MISSING=()
  for dep in zsh git curl gawk bash; do
    command -v "$dep" &>/dev/null || MISSING+=("$dep")
  done

  if [ ${#MISSING[@]} -eq 0 ]; then
    success "All dependencies already installed."
  else
    info "Installing missing packages: ${MISSING[*]}"
    install_pkg "${MISSING[@]}"
    success "Dependencies installed."
  fi
}

# ── Clone / Locate Repo ───────────────────────────────────────────────────────
locate_repo() {
  # If we're already running from inside the repo, use that path
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
  CANDIDATE="$(dirname "$SCRIPT_DIR")"  # parent of OMZ/

  if [ -f "$CANDIDATE/OMZ/install.sh" ] && [ -d "$CANDIDATE/OMZ/Home Folder" ]; then
    REPO_DIR="$CANDIDATE"
    info "Running from existing repo at: ${BOLD}$REPO_DIR${RESET}"
  else
    if [ -d "$REPO_DIR/.git" ]; then
      info "Repo already cloned at ${BOLD}$REPO_DIR${RESET}, pulling latest..."
      git -C "$REPO_DIR" pull --ff-only
    else
      info "Cloning dotfiles repo to ${BOLD}$REPO_DIR${RESET}..."
      git clone "$REPO_URL" "$REPO_DIR"
    fi
    success "Repo ready."
  fi
}

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
install_omz() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    warn "Oh My Zsh already installed — skipping."
  else
    info "Installing Oh My Zsh..."
    # RUNZSH=no  — don't spawn a new zsh session and block the script
    # CHSH=no    — we handle the shell change ourselves below
    RUNZSH=no CHSH=no \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    success "Oh My Zsh installed."
  fi
}

# ── Plugins & Theme ───────────────────────────────────────────────────────────
install_omz_extras() {
  local CUSTOM="$HOME/.oh-my-zsh/custom"

  if [ -d "$CUSTOM/themes/powerlevel10k" ]; then
    warn "Powerlevel10k already installed — skipping."
  else
    info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      "$CUSTOM/themes/powerlevel10k"
    success "Powerlevel10k installed."
  fi

  if [ -d "$CUSTOM/plugins/zsh-autosuggestions" ]; then
    warn "zsh-autosuggestions already installed — skipping."
  else
    info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions \
      "$CUSTOM/plugins/zsh-autosuggestions"
    success "zsh-autosuggestions installed."
  fi

  if [ -d "$CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    warn "zsh-syntax-highlighting already installed — skipping."
  else
    info "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
      "$CUSTOM/plugins/zsh-syntax-highlighting"
    success "zsh-syntax-highlighting installed."
  fi
}

# ── Symlinks ──────────────────────────────────────────────────────────────────
backup_if_exists() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    warn "Existing file found at ${target} — backing up to ${backup}"
    mv "$target" "$backup"
  fi
}

symlink() {
  local src="$1"
  local dst="$2"
  backup_if_exists "$dst"
  ln -sf "$src" "$dst"
  success "Linked: ${BOLD}$dst${RESET} → $src"
}

deploy_dotfiles() {
  info "Deploying dotfiles..."

  local HOME_FOLDER="$REPO_DIR/OMZ/Home Folder"
  local linked=0

  # Walk every file in "Home Folder/" and symlink it to the same
  # relative path under ~  — the folder structure IS the home structure
  while IFS= read -r -d '' src; do
    local rel="${src#"$HOME_FOLDER/"}"   # strip "Home Folder/" prefix
    local dst="$HOME/$rel"

    mkdir -p "$(dirname "$dst")"
    symlink "$src" "$dst"
    (( linked++ )) || true
  done < <(find "$HOME_FOLDER" -type f -print0)

  success "Deployed $linked file(s)."
}

# ── Default Shell ─────────────────────────────────────────────────────────────
set_zsh_default() {
  local ZSH_PATH
  ZSH_PATH="$(command -v zsh)"

  if [ "$SHELL" = "$ZSH_PATH" ]; then
    warn "zsh is already your default shell — skipping."
    return
  fi

  info "Setting zsh as default shell..."

  # Alpine's busybox chsh doesn't support -s; needs the 'shadow' package
  if [ "$PKG_MANAGER" = "apk" ] && ! command -v chsh &>/dev/null; then
    info "Installing shadow for chsh support on Alpine..."
    apk add --no-cache shadow
  fi

  # Add to /etc/shells if not present
  grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
  chsh -s "$ZSH_PATH"
  success "Default shell set to zsh. Takes effect on next login."
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║     JakeFlanagan/Dotfiles        ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════╝${RESET}"
  echo ""

  detect_os
  install_deps
  locate_repo
  install_omz
  install_omz_extras
  deploy_dotfiles
  set_zsh_default

  echo ""
  echo -e "${GREEN}${BOLD}All done.${RESET} Reload your shell or open a new terminal."
  echo -e "Run ${CYAN}p10k configure${RESET} if you want to reconfigure your prompt."
  echo ""
}

main "$@"
