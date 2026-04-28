## Post-Distro-Upgrade Cleanup
post_upgrade() {

  # ── Colours ─────────────────────────────────────────────────────────────
  local RED='\033[0;31m'    GREEN='\033[1;32m'   YELLOW='\033[1;33m'
  local CYAN='\033[0;36m'   BOLD='\033[1m'        GREY='\033[0;90m'
  local RESET='\033[0m'

  # ── Privilege prefix ─────────────────────────────────────────────────────
  local -a SUDO=()
  [[ $EUID -ne 0 ]] && SUDO=(sudo)

  # ── Header ───────────────────────────────────────────────────────────────
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║      Post-Upgrade Cleanup        ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════╝${RESET}"
  echo ""

  # ── OS Detection ─────────────────────────────────────────────────────────
  local OS_ID="" OS_ID_LIKE="" PKG_MANAGER=""

  if [[ -f /etc/os-release ]]; then
    local _key _val
    while IFS='=' read -r _key _val; do
      _val="${_val%\"}"
      _val="${_val#\"}"
      case "$_key" in
        ID)      OS_ID="$_val"      ;;
        ID_LIKE) OS_ID_LIKE="$_val" ;;
      esac
    done < /etc/os-release
  else
    OS_ID="$(uname -s | tr '[:upper:]' '[:lower:]')"
  fi

  case "$OS_ID" in
    ubuntu|debian|linuxmint|pop|kali) PKG_MANAGER="apt"     ;;
    fedora|rhel|centos|rocky|almalinux) PKG_MANAGER="dnf"   ;;
    arch|manjaro|endeavouros)           PKG_MANAGER="pacman" ;;
    alpine)                             PKG_MANAGER="apk"    ;;
    *)
      case "$OS_ID_LIKE" in
        *debian*|*ubuntu*) PKG_MANAGER="apt"    ;;
        *fedora*|*rhel*)   PKG_MANAGER="dnf"    ;;
        *arch*)            PKG_MANAGER="pacman" ;;
        *)
          echo -e "${RED}${BOLD}[ERROR]${RESET} Unsupported OS: ${OS_ID}. Cannot determine package manager."
          return 1
          ;;
      esac
      ;;
  esac

  echo -e "${CYAN}${BOLD}[INFO]${RESET}  Detected: ${BOLD}${OS_ID}${RESET} (${BOLD}${PKG_MANAGER}${RESET})"
  echo ""

  # ── Reboot nag ───────────────────────────────────────────────────────────
  # Warn if the system hasn't been rebooted since the upgrade was applied.
  # Fedora's system-upgrade always reboots, but APT-based upgrades may not.
  if [[ -f /var/run/reboot-required ]]; then
    echo -e "${YELLOW}${BOLD}[WARN]${RESET}  A reboot is required before running post-upgrade cleanup."
    echo -e "        Reboot now and then re-run ${BOLD}post_upgrade${RESET}."
    echo ""
    echo -ne "${YELLOW}${BOLD}[?]${RESET}     Continue anyway? [y/N] "
    local _reboot_confirm
    read -r _reboot_confirm
    echo ""
    case "$_reboot_confirm" in
      [yY]|[yY][eE][sS]) ;;
      *) return 0 ;;
    esac
  fi

  # ── Step tracking ─────────────────────────────────────────────────────────
  local _steps_ok=0 _steps_warn=0

  _step_ok()   { echo -e "${GREEN}${BOLD}[OK]${RESET}    $*";  (( _steps_ok++   )); echo ""; }
  _step_info() { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
  _step_warn() { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; (( _steps_warn++ )); echo ""; }
  _step_err()  { echo -e "${RED}${BOLD}[ERROR]${RESET} $*"; echo ""; }

  # ══════════════════════════════════════════════════════════════════════════
  # APT  (Ubuntu / Debian / derivatives)
  # ══════════════════════════════════════════════════════════════════════════
  if [[ "$PKG_MANAGER" == "apt" ]]; then

    # 1. Refresh index against new-release repos
    _step_info "Refreshing package index..."
    if "${SUDO[@]}" apt-get update -qq; then
      _step_ok "Package index refreshed."
    else
      _step_err "apt-get update failed — check your sources.list."
    fi

    # 2. dist-upgrade — catches packages held back by a plain 'upgrade'
    _step_info "Running dist-upgrade to finalise held-back packages..."
    echo ""
    if "${SUDO[@]}" apt-get dist-upgrade -y; then
      _step_ok "dist-upgrade complete."
    else
      _step_err "dist-upgrade encountered errors."
    fi

    # 3. Fix any broken/unconfigured packages
    _step_info "Configuring any unconfigured packages..."
    "${SUDO[@]}" dpkg --configure -a
    if "${SUDO[@]}" apt-get install -f -y -qq; then
      _step_ok "No broken dependencies."
    else
      _step_err "apt-get install -f failed — manual intervention may be needed."
    fi

    # 4. Remove obsolete packages left over from the old release
    _step_info "Removing obsolete packages..."
    local _removable
    _removable=$("${SUDO[@]}" apt-get autoremove --purge --dry-run 2>/dev/null \
      | grep "^Remv" | awk '{print $2}') || true
    if [[ -n "$_removable" ]]; then
      local _rm_count
      _rm_count=$(echo "$_removable" | grep -c .)
      echo -e "${GREY}${_removable}${RESET}"
      echo ""
      echo -ne "${YELLOW}${BOLD}[?]${RESET}     Remove ${BOLD}${_rm_count}${RESET} obsolete package(s)? [y/N] "
      local _rm_confirm
      read -r _rm_confirm
      echo ""
      case "$_rm_confirm" in
        [yY]|[yY][eE][sS])
          "${SUDO[@]}" apt-get autoremove --purge -y
          _step_ok "${_rm_count} obsolete package(s) removed."
          ;;
        *)
          _step_warn "Skipped — obsolete packages remain."
          ;;
      esac
    else
      _step_ok "No obsolete packages found."
    fi

    # 5. Clean the package cache
    _step_info "Cleaning package cache..."
    "${SUDO[@]}" apt-get autoclean -q
    _step_ok "Package cache cleaned."

    # 6. Check for leftover config files from purged packages
    _step_info "Scanning for residual config files from removed packages..."
    local _residual
    _residual=$(dpkg -l 2>/dev/null | awk '/^rc/ {print $2}') || true
    if [[ -n "$_residual" ]]; then
      local _res_count
      _res_count=$(echo "$_residual" | grep -c .)
      _step_warn "${_res_count} residual config file set(s) found. Purge with:"
      echo -e "          ${CYAN}${SUDO[*]:+${SUDO[*]} }dpkg --purge ${_residual//$'\n'/ }${RESET}"
      echo ""
    else
      _step_ok "No residual config files found."
    fi

    # 7. Check for .dpkg-new / .dpkg-old config conflicts left by the upgrader
    _step_info "Scanning for dpkg config conflicts (.dpkg-new / .dpkg-old)..."
    local _conflicts
    _conflicts=$(find /etc /usr /lib -maxdepth 5 \
      \( -name "*.dpkg-new" -o -name "*.dpkg-old" \) 2>/dev/null) || true
    if [[ -n "$_conflicts" ]]; then
      _step_warn "Config conflicts found — review and merge these files:"
      echo -e "${GREY}${_conflicts}${RESET}"
      echo ""
    else
      _step_ok "No dpkg config conflicts found."
    fi

  fi

  # ══════════════════════════════════════════════════════════════════════════
  # DNF  (Fedora — post system-upgrade reboot)
  # ══════════════════════════════════════════════════════════════════════════
  if [[ "$PKG_MANAGER" == "dnf" ]]; then

    # 1. Clean up the upgrade download cache
    _step_info "Cleaning system-upgrade cache..."
    if "${SUDO[@]}" dnf system-upgrade clean -q 2>/dev/null; then
      _step_ok "Upgrade cache cleaned."
    else
      # system-upgrade plugin may not be installed on non-Fedora DNF distros
      _step_warn "dnf system-upgrade clean skipped (plugin not available)."
    fi

    # 2. Distro-sync — realigns any packages that drifted during the upgrade
    _step_info "Running distro-sync to align all packages to the new release..."
    echo ""
    if "${SUDO[@]}" dnf distro-sync -y; then
      _step_ok "distro-sync complete."
    else
      _step_err "distro-sync encountered errors."
    fi

    # 3. Rebuild RPM database
    _step_info "Rebuilding RPM database..."
    if "${SUDO[@]}" rpm --rebuilddb; then
      _step_ok "RPM database rebuilt."
    else
      _step_err "rpm --rebuilddb failed."
    fi

    # 4. Remove unneeded dependencies
    _step_info "Removing unneeded dependencies..."
    local _dnf_removable
    _dnf_removable=$("${SUDO[@]}" dnf autoremove --assumeno 2>/dev/null \
      | grep "^Removing:" -A 9999 | tail -n +2 | grep -v '^$' | grep -v 'Transaction') || true
    if [[ -n "$_dnf_removable" ]]; then
      echo -e "${GREY}${_dnf_removable}${RESET}"
      echo ""
      echo -ne "${YELLOW}${BOLD}[?]${RESET}     Remove these unneeded packages? [y/N] "
      local _dnf_rm_confirm
      read -r _dnf_rm_confirm
      echo ""
      case "$_dnf_rm_confirm" in
        [yY]|[yY][eE][sS])
          "${SUDO[@]}" dnf autoremove -y
          _step_ok "Unneeded packages removed."
          ;;
        *)
          _step_warn "Skipped — unneeded packages remain."
          ;;
      esac
    else
      _step_ok "No unneeded packages found."
    fi

    # 5. Flag packages not from any configured repo (old-release leftovers)
    _step_info "Checking for packages not from current repos (extras)..."
    local _extras
    _extras=$(dnf list extras 2>/dev/null | grep -vE '^Extra|^Loaded|^$') || true
    if [[ -n "$_extras" ]]; then
      _step_warn "Extra packages found (not in any current repo). Review manually:"
      echo -e "${GREY}${_extras}${RESET}"
      echo ""
    else
      _step_ok "No extra packages found."
    fi

    # 6. Check for unsatisfied dependencies
    _step_info "Checking for unsatisfied dependencies..."
    local _unsat
    _unsat=$(dnf repoquery --unsatisfied 2>/dev/null | grep -v '^$') || true
    if [[ -n "$_unsat" ]]; then
      _step_warn "Unsatisfied dependencies detected:"
      echo -e "${GREY}${_unsat}${RESET}"
      echo ""
    else
      _step_ok "All dependencies satisfied."
    fi

    # 7. Clean all caches
    _step_info "Cleaning DNF cache..."
    "${SUDO[@]}" dnf clean all -q
    _step_ok "DNF cache cleaned."

  fi

  # ══════════════════════════════════════════════════════════════════════════
  # PACMAN  (Arch / Manjaro / EndeavourOS — rolling, no distro upgrades)
  # ══════════════════════════════════════════════════════════════════════════
  if [[ "$PKG_MANAGER" == "pacman" ]]; then

    echo -e "${YELLOW}${BOLD}[WARN]${RESET}  Arch-based distros are rolling releases — there is no"
    echo -e "        discrete distro upgrade step. Running general post-update"
    echo -e "        housekeeping instead."
    echo ""

    # 1. Remove orphaned packages
    _step_info "Checking for orphaned packages..."
    local _orphans
    _orphans=$(pacman -Qdtq 2>/dev/null) || true
    if [[ -n "$_orphans" ]]; then
      local _orp_count
      _orp_count=$(echo "$_orphans" | grep -c .)
      echo -e "${GREY}${_orphans}${RESET}"
      echo ""
      echo -ne "${YELLOW}${BOLD}[?]${RESET}     Remove ${BOLD}${_orp_count}${RESET} orphaned package(s)? [y/N] "
      local _orp_confirm
      read -r _orp_confirm
      echo ""
      case "$_orp_confirm" in
        [yY]|[yY][eE][sS])
          echo "$_orphans" | "${SUDO[@]}" pacman -Rs -
          _step_ok "${_orp_count} orphaned package(s) removed."
          ;;
        *)
          _step_warn "Skipped — orphaned packages remain."
          ;;
      esac
    else
      _step_ok "No orphaned packages found."
    fi

    # 2. Find .pacnew / .pacsave config conflicts
    _step_info "Scanning for .pacnew / .pacsave config conflicts..."
    local _pacnew
    _pacnew=$(find /etc -name "*.pacnew" -o -name "*.pacsave" 2>/dev/null) || true
    if [[ -n "$_pacnew" ]]; then
      _step_warn "Config conflicts found — review and merge these files:"
      echo -e "${GREY}${_pacnew}${RESET}"
      echo -e "          ${GREY}Tip: use ${CYAN}pacdiff${GREY} (from pacman-contrib) to merge them.${RESET}"
      echo ""
    else
      _step_ok "No .pacnew / .pacsave conflicts found."
    fi

    # 3. Clean the package cache (keep last 2 versions)
    _step_info "Cleaning package cache (keeping last 2 versions)..."
    if command -v paccache &>/dev/null; then
      "${SUDO[@]}" paccache -rk2
      _step_ok "Package cache cleaned."
    else
      _step_warn "paccache not found — install pacman-contrib to enable cache cleaning."
    fi

  fi

  # ══════════════════════════════════════════════════════════════════════════
  # APK  (Alpine)
  # ══════════════════════════════════════════════════════════════════════════
  if [[ "$PKG_MANAGER" == "apk" ]]; then

    # 1. Fix any broken state
    _step_info "Running apk fix to repair any broken packages..."
    if "${SUDO[@]}" apk fix; then
      _step_ok "Package state is consistent."
    else
      _step_err "apk fix encountered errors."
    fi

    # 2. Sync to new repos
    _step_info "Upgrading to align with new repository versions..."
    if "${SUDO[@]}" apk upgrade --available; then
      _step_ok "All packages aligned to current repos."
    else
      _step_err "apk upgrade encountered errors."
    fi

    # 3. Clean cache
    _step_info "Cleaning APK cache..."
    "${SUDO[@]}" apk cache clean
    _step_ok "APK cache cleaned."

  fi

  # ── Summary ──────────────────────────────────────────────────────────────
  echo -e "${BOLD}╔══════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║           Summary                ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${GREEN}${BOLD}Passed :${RESET} ${_steps_ok}"
  echo -e "  ${YELLOW}${BOLD}Warnings:${RESET} ${_steps_warn}"
  echo ""

  if [[ $_steps_warn -gt 0 ]]; then
    echo -e "${YELLOW}${BOLD}[WARN]${RESET}  Some steps require attention — review the warnings above."
  else
    echo -e "${GREEN}${BOLD}[OK]${RESET}    Post-upgrade cleanup complete. Consider a reboot if you haven't already."
  fi
  echo ""

  # ── Reboot prompt ─────────────────────────────────────────────────────────
  echo -ne "${YELLOW}${BOLD}[?]${RESET}     Reboot now to apply all changes? [y/N] "
  local _reboot_now
  read -r _reboot_now
  echo ""
  case "$_reboot_now" in
    [yY]|[yY][eE][sS])
      echo -e "${CYAN}${BOLD}[INFO]${RESET}  Rebooting..."
      "${SUDO[@]}" reboot
      ;;
    *)
      echo -e "${GREY}        Reboot skipped. Remember to reboot when convenient.${RESET}"
      echo ""
      ;;
  esac
}
