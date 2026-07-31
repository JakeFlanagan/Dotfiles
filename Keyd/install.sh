#!/usr/bin/env bash
#
# Dotfiles / Keyd
#
# Remaps the Logitech G502's onboard F17-F24 phantom keys to numpad keys,
# with a left-Ctrl shift layer giving a second set of eight.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/JakeFlanagan/Dotfiles/main/Keyd/install.sh)
#
# Why this exists:
#   xkeyboard-config's symbols/inet overloads part of the F13-F24 range with
#   media-key symbols (XF86Launch8/9, XF86AudioMicMute, XF86TouchpadToggle).
#   Anything reading XKB keysyms gets the media key instead of the F-key, so
#   the mouse buttons silently do the wrong thing or nothing at all. Numpad
#   keycodes are unclaimed, so they pass through cleanly everywhere.
#
#   keyd sits below XKB and rewrites at the evdev layer, which is why it works
#   on Wayland, X11 and in a bare VT alike.
#
# Panic sequence if a bad config ever locks the keyboard:
#   backspace + escape + enter
#
set -euo pipefail

# --- config ------------------------------------------------------------------

# Override at call time if the hardware differs, e.g.
#   MOUSE_ID=046d:4082 bash <(curl -fsSL .../install.sh)
MOUSE_ID="${MOUSE_ID:-046d:407f}"   # Logitech G502
KBD_ID="${KBD_ID:-046d:c336}"       # Logitech G213, only used for the Ctrl layer

CONFIG_DIR="/etc/keyd"
CONFIG="${CONFIG_DIR}/default.conf"
COPR="alternateved/keyd"
UBUNTU_PPA="ppa:keyd-team/ppa"
SOURCE_REPO="https://github.com/rvaiya/keyd"

# --- helpers -----------------------------------------------------------------

info() { printf '\033[1;34m::\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m::\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31m::\033[0m %s\n' "$1" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Is a vendor:product currently attached? Checks the kernel's own device list,
# so it needs no extra tooling and works the same on every distro.
device_present() {
    local id="${1//:/ }"
    local vendor product
    read -r vendor product <<<"$id"
    grep -qi "Vendor=${vendor}.*Product=${product}" /proc/bus/input/devices 2>/dev/null
}

# --- preflight ---------------------------------------------------------------

[[ $EUID -eq 0 ]] && die "Run as your normal user, not root. It will sudo where needed."
[[ "$(uname -s)" == "Linux" ]] || die "keyd is Linux only."
have sudo || die "sudo not found."

# --- install -----------------------------------------------------------------

install_keyd() {
    if have keyd; then
        info "keyd already installed ($(keyd --version 2>/dev/null | head -n1 || echo 'version unknown'))"
        return
    fi

    if have dnf; then
        # Not in Fedora proper. COPR package is the one upstream points at.
        info "Fedora detected, enabling COPR ${COPR}"
        sudo dnf copr enable -y "$COPR"
        sudo dnf install -y keyd

    elif have apt-get; then
        # Packaged in Debian 13 (trixie) and Ubuntu 25.04 (plucky) onward.
        info "Debian/Ubuntu detected"
        sudo apt-get update -qq
        if apt-cache show keyd >/dev/null 2>&1; then
            sudo apt-get install -y keyd
        else
            warn "keyd not in your archives, falling back to the upstream PPA"
            have add-apt-repository || sudo apt-get install -y software-properties-common
            sudo add-apt-repository -y "$UBUNTU_PPA"
            sudo apt-get update -qq
            sudo apt-get install -y keyd
        fi

    elif have pacman; then
        info "Arch detected"
        sudo pacman -S --needed --noconfirm keyd

    elif have zypper; then
        info "openSUSE detected"
        sudo zypper --non-interactive install keyd

    elif have xbps-install; then
        info "Void detected"
        sudo xbps-install -Sy keyd

    else
        warn "No known package manager, building from source"
        for dep in git make gcc; do
            have "$dep" || die "Source build needs ${dep}, which is not installed."
        done
        local tmp
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' RETURN
        git clone --depth 1 "$SOURCE_REPO" "$tmp/keyd"
        make -C "$tmp/keyd"
        sudo make -C "$tmp/keyd" install
    fi

    have keyd || die "Install finished but keyd is still not on PATH."
}

install_keyd

# The RPM in particular does not always create this, and keyd refuses to
# start without it.
[[ -d $CONFIG_DIR ]] || { info "Creating ${CONFIG_DIR}"; sudo mkdir -p "$CONFIG_DIR"; }

# --- device detection --------------------------------------------------------

if device_present "$MOUSE_ID"; then
    info "Found mouse ${MOUSE_ID}"
else
    warn "Mouse ${MOUSE_ID} not currently attached. Writing config anyway."
    warn "keyd will pick it up when it is plugged in."
fi

# The keyboard is optional. Without it there is no Ctrl shift layer, but the
# eight base bindings still work.
IDS="$MOUSE_ID"
SHIFT_LAYER=1
if device_present "$KBD_ID"; then
    info "Found keyboard ${KBD_ID}, Ctrl shift layer enabled"
    IDS="${IDS}"$'\n'"${KBD_ID}"
else
    warn "Keyboard ${KBD_ID} not found, skipping the Ctrl shift layer."
    warn "Set KBD_ID=vendor:product and re-run to enable it on other hardware."
    SHIFT_LAYER=0
fi

# --- config ------------------------------------------------------------------

if [[ -f $CONFIG ]]; then
    BACKUP="${CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
    warn "Existing config found, backing up to ${BACKUP}"
    sudo cp "$CONFIG" "$BACKUP"
fi

info "Writing ${CONFIG}"

{
    cat <<EOF
# Managed by JakeFlanagan/Dotfiles - Keyd/install.sh
# Local edits will be overwritten on re-run.
#
# The G502's onboard memory (written via G HUB) emits F17-F24 on its eight
# remappable buttons. keyd rewrites those to numpad keys, which XKB passes
# through untouched.

[ids]
${IDS}

[main]
EOF

    if [[ $SHIFT_LAYER -eq 1 ]]; then
        cat <<'EOF'

leftcontrol = layer(mshift)
EOF
    fi

    cat <<'EOF'

f17 = kp1
f18 = kp2
f19 = kp3
f20 = kp4
f21 = kp5
f22 = kp6
f23 = kp7
f24 = kp8
EOF

    if [[ $SHIFT_LAYER -eq 1 ]]; then
        cat <<'EOF'

# ':C' keeps this layer behaving as Control, so Ctrl+C, Ctrl+V and any
# in-game Ctrl binds still work. Only the eight keys below are overridden
# while it is held.
[mshift:C]

f17 = kpplus
f18 = kpminus
f19 = kp0
f20 = kpasterisk
f21 = kpslash
f22 = kpcomma
f23 = kpdot
f24 = kpequal
EOF
    fi
} | sudo tee "$CONFIG" >/dev/null

# --- service -----------------------------------------------------------------

if have systemctl && [[ -d /run/systemd/system ]]; then
    info "Enabling and starting keyd"
    sudo systemctl enable --now keyd
    sudo systemctl restart keyd

    if systemctl is-active --quiet keyd; then
        info "keyd is running."
    else
        die "keyd failed to start. Check: systemctl status keyd"
    fi
else
    warn "No systemd detected. Start keyd with your init system manually."
    warn "Upstream ships only a systemd unit, so you may need your own."
fi

# --- done --------------------------------------------------------------------

cat <<'NOTE'

Done.

Verify:
    sudo keyd monitor

Press each mouse button alone, then again holding left Ctrl.
Expect kp1-kp8 plain, and kpplus / kpminus / kp0 / kpasterisk / kpslash /
kpcomma / kpdot / kpequal while shifted.

Num Lock changes what these resolve to (kp1 vs KP_End). Pick a state, leave
it, and bind in-game with it set that way.

Undo:   sudo systemctl stop keyd
Panic:  backspace + escape + enter

NOTE
