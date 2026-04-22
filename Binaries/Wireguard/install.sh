#!/usr/bin/env bash
# =============================================================================
# JakeFlanagan/Scripts — One-shot installer
# Usage:
#   From within cloned repo:  bash install.sh
#   One-liner (auto-clones):  bash <(curl -fsSL https://raw.githubusercontent.com/JakeFlanagan/Scripts/main/install.sh)
# =============================================================================

set -euo pipefail

REPO_URL="https://github.com/JakeFlanagan/Scripts.git"
REPO_DIR="$HOME/.scripts"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $*"; exit 1; }

# ── Clone / Locate Repo ───────────────────────────────────────────────────────
locate_repo() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

  if [ -f "$SCRIPT_DIR/install.sh" ] && [ -d "$SCRIPT_DIR/Home Folder" ]; then
    REPO_DIR="$SCRIPT_DIR"
    info "Running from existing repo at: ${BOLD}$REPO_DIR${RESET}"
  else
    if [ -d "$REPO_DIR/.git" ]; then
      info "Repo already cloned at ${BOLD}$REPO_DIR${RESET}, pulling latest..."
      git -C "$REPO_DIR" pull --ff-only
    else
      info "Cloning scripts repo to ${BOLD}$REPO_DIR${RESET}..."
      git clone "$REPO_URL" "$REPO_DIR"
    fi
    success "Repo ready."
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

deploy_scripts() {
  info "Deploying scripts..."

  local HOME_FOLDER="$REPO_DIR/Home Folder"
  local linked=0

  while IFS= read -r -d '' src; do
    # Skip .gitkeep files
    [[ "$(basename "$src")" == ".gitkeep" ]] && continue

    local rel="${src#"$HOME_FOLDER/"}"
    local dst="$HOME/$rel"

    mkdir -p "$(dirname "$dst")"
    symlink "$src" "$dst"
    chmod +x "$src"
    (( linked++ )) || true
  done < <(find "$HOME_FOLDER" -type f -print0)

  success "Deployed $linked file(s)."
}

# ── PATH check ────────────────────────────────────────────────────────────────
check_path() {
  if [[ ":$PATH:" != *":$HOME/.bin:"* ]]; then
    warn "~/.bin is not in your PATH."
    info  "Add this to your ~/.zshrc or ~/.bashrc:"
    echo  ""
    echo  '  export PATH="$HOME/.bin:$PATH"'
    echo  ""
  else
    success "~/.bin is already in PATH."
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║      JakeFlanagan/Scripts        ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════╝${RESET}"
  echo ""

  locate_repo
  deploy_scripts
  check_path

  echo ""
  echo -e "${GREEN}${BOLD}All done.${RESET} Reload your shell or open a new terminal."
  echo ""
}

main "$@"
