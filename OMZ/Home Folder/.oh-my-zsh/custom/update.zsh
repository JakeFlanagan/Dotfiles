## System Update
update() {

  # ── Colours ─────────────────────────────────────────────────────────────
  local RED='\033[0;31m'    GREEN='\033[1;32m'   YELLOW='\033[1;33m'
  local CYAN='\033[0;36m'   BOLD='\033[1m'        GREY='\033[0;90m'
  local RESET='\033[0m'

  # ── Header ───────────────────────────────────────────────────────────────
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║         System Update            ║${RESET}"
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
    ubuntu|debian|linuxmint|pop|kali) PKG_MANAGER="apt"    ;;
    fedora|rhel|centos|rocky|almalinux) PKG_MANAGER="dnf"  ;;
    arch|manjaro|endeavouros)           PKG_MANAGER="pacman" ;;
    alpine)                             PKG_MANAGER="apk"   ;;
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

  # ── Refresh Package Index ─────────────────────────────────────────────────
  echo -e "${CYAN}${BOLD}[INFO]${RESET}  Refreshing package index..."

  case "$PKG_MANAGER" in
    apt)
      sudo apt-get update -qq
      ;;
    dnf)
      # dnf check-update exits 100 when updates are available — not a real error
      sudo dnf check-update -q &>/dev/null || true
      ;;
    pacman)
      sudo pacman -Sy --noconfirm &>/dev/null
      ;;
    apk)
      if command -v sudo &>/dev/null; then sudo apk update -q
      else apk update -q; fi
      ;;
  esac

  # ── Gather Available Updates ──────────────────────────────────────────────
  echo -e "${CYAN}${BOLD}[INFO]${RESET}  Checking for available updates..."
  echo ""

  local update_list="" update_count=0

  case "$PKG_MANAGER" in
    apt)
      update_list=$(apt list --upgradable 2>/dev/null | grep -v '^Listing') || true
      ;;
    dnf)
      # exits 100 if updates exist — suppress pipefail
      update_list=$(dnf check-update 2>/dev/null | grep -vE '^$|^Last metadata|^Obsoleting') || true
      ;;
    pacman)
      update_list=$(pacman -Qu 2>/dev/null) || true
      ;;
    apk)
      update_list=$(apk list --upgradable 2>/dev/null | grep -v '^$') || true
      ;;
  esac

  [[ -n "$update_list" ]] && update_count=$(echo "$update_list" | grep -c .)

  # ── Up To Date ────────────────────────────────────────────────────────────
  if [[ $update_count -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}[OK]${RESET}    System is already up to date."
    echo ""

  else

    # ── List Packages ───────────────────────────────────────────────────────
    echo -e "${CYAN}${BOLD}[INFO]${RESET}  ${BOLD}${update_count}${RESET} package(s) available to update:"
    echo ""
    echo -e "${GREY}${update_list}${RESET}"
    echo ""

    # ── Confirm ─────────────────────────────────────────────────────────────
    echo -ne "${YELLOW}${BOLD}[?]${RESET}     Install all updates? [y/N] "
    local confirm
    read -r confirm
    echo ""

    case "$confirm" in
      [yY]|[yY][eE][sS])

        echo -e "${CYAN}${BOLD}[INFO]${RESET}  Installing updates..."
        echo ""

        case "$PKG_MANAGER" in
          apt)    sudo apt-get upgrade -y ;;
          dnf)    sudo dnf upgrade -y ;;
          pacman) sudo pacman -Su --noconfirm ;;
          apk)
            if command -v sudo &>/dev/null; then sudo apk upgrade
            else apk upgrade; fi
            ;;
        esac

        echo ""
        echo -e "${GREEN}${BOLD}[OK]${RESET}    Updates installed successfully."
        echo ""
        ;;

      *)
        echo -e "${YELLOW}${BOLD}[WARN]${RESET}  Update cancelled — no changes made."
        echo ""
        ;;
    esac
  fi

  # ── Distro Upgrade Check ──────────────────────────────────────────────────
  # Runs at the end regardless of whether packages were updated.
  # Informs only — never performs the upgrade.

  local upgrade_title="" upgrade_cmd="" upgrade_note=""

  case "$PKG_MANAGER" in

    apt)
      # Ubuntu ships do-release-upgrade; plain Debian typically doesn't
      if command -v do-release-upgrade &>/dev/null; then
        local dru_out
        dru_out=$(do-release-upgrade -c 2>&1) || true
        if echo "$dru_out" | grep -qi "new release"; then
          upgrade_title=$(echo "$dru_out" \
            | grep -iE "new release|LTS|Ubuntu|Debian" \
            | head -1 \
            | sed 's/^[[:space:]]*//')
          [[ -z "$upgrade_title" ]] && upgrade_title="A new OS release is available."
          upgrade_cmd="sudo do-release-upgrade"
        fi
      fi
      ;;

    dnf)
      # Fedora only — RHEL/CentOS/Rocky upgrades are handled differently
      local current_ver
      current_ver=$(rpm -E %fedora 2>/dev/null) || true
      if [[ "$current_ver" =~ ^[0-9]+$ ]]; then
        local next_ver=$(( current_ver + 1 ))
        upgrade_title="You are on Fedora ${current_ver}. Fedora ${next_ver} may be available."
        upgrade_cmd="sudo dnf system-upgrade download --releasever=${next_ver} && sudo dnf system-upgrade reboot"
        upgrade_note="Run the command above to download the upgrade. Your system will reboot to apply it."
      fi
      ;;

    pacman)
      # Arch / Manjaro / EndeavourOS are rolling releases — no distro upgrades
      ;;

    apk)
      # Alpine distro upgrades (e.g. 3.19 → 3.20) require manually editing
      # /etc/apk/repositories. In an LXC container the template handles this.
      # Nothing useful to surface here automatically.
      ;;

  esac

  if [[ -n "$upgrade_title" ]]; then
    echo -e "${YELLOW}${BOLD}╔══ Distro Upgrade Available ══════════════════════════════════╗${RESET}"
    echo -e "${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}║${RESET}  ${BOLD}${upgrade_title}${RESET}"
    if [[ -n "$upgrade_note" ]]; then
      echo -e "${YELLOW}${BOLD}║${RESET}"
      echo -e "${YELLOW}${BOLD}║${RESET}  ${GREY}${upgrade_note}${RESET}"
    fi
    echo -e "${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}║${RESET}  ${GREY}To upgrade:${RESET}"
    echo -e "${YELLOW}${BOLD}║${RESET}  ${CYAN}${upgrade_cmd}${RESET}"
    echo -e "${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
  fi
}
