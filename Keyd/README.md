# Keyd

Mouse button remapping via [keyd](https://github.com/rvaiya/keyd). Gives the Logitech G502 sixteen usable extra keys that every application actually sees.

## Install

```
bash <(curl -fsSL https://raw.githubusercontent.com/JakeFlanagan/Dotfiles/main/Keyd/install.sh)
```

Safe to re-run. Backs up any existing `/etc/keyd/default.conf` with a timestamp before writing.

## The problem this solves

The G502's onboard memory is programmed via G HUB to emit F17-F24 on its eight remappable buttons. Those are real HID usages and the kernel receives them correctly, which `evtest` confirms.

XKB is where it falls apart. `xkeyboard-config`'s `symbols/inet` overloads part of the F13-F24 range with media-key symbols, because a lot of laptop keyboards emit high F-key scancodes for keys physically labelled something else. So:

| Key | What XKB resolves it to |
| --- | --- |
| F17 | `XF86Launch8` |
| F18 | `XF86Launch9` |
| F20 | `XF86AudioMicMute` |
| F21 | `XF86TouchpadToggle` |
| F23 | passes through fine |
| F24 | passes through fine |

Anything reading evdev scancodes directly (most SDL games) sees the correct F-key. Anything reading XKB keysyms (GTK, Qt, Electron, the desktop itself) gets the media key. Hence a mouse button muting the microphone.

keyd sits below XKB and rewrites the keycode before XKB ever sees it. Numpad codes are unclaimed, so they resolve cleanly on both paths. It also means this works identically on Wayland, X11 and a bare VT.

Fixing XKB directly is possible but fiddly, gets rebuilt on `xkeyboard-config` updates, and a broken keymap takes the login screen with it.

## Mapping

| Button | Plain | Holding left Ctrl |
| --- | --- | --- |
| 1 | `kp1` | `kpplus` |
| 2 | `kp2` | `kpminus` |
| 3 | `kp3` | `kp0` |
| 4 | `kp4` | `kpasterisk` |
| 5 | `kp5` | `kpslash` |
| 6 | `kp6` | `kpcomma` |
| 7 | `kp7` | `kpdot` |
| 8 | `kp8` | `kpequal` |

The shift layer is declared `[mshift:C]`, so it still behaves as Control. Ctrl+C, Ctrl+V and any in-game Ctrl binds keep working. Only these eight keys are overridden while it is held.

`kpcomma` does not exist on UK or US numpads, so some applications may not recognise it. `kpequal` is deliberately chosen for being real but almost never default-bound.

## Num Lock

Numpad keys resolve differently depending on Num Lock state: `kp1` with it on, `KP_End` with it off. Pick a state, leave it there, and bind in-game with it set that way.

## Hardware

Defaults are hardcoded but overridable:

```
MOUSE_ID=046d:4082 KBD_ID=046d:c33f bash <(curl -fsSL .../install.sh)
```

| Variable | Default | Device |
| --- | --- | --- |
| `MOUSE_ID` | `046d:407f` | Logitech G502 |
| `KBD_ID` | `046d:c336` | Logitech G213 |

The keyboard is only needed for the Ctrl shift layer. If it is not attached the installer skips that layer and the eight base bindings still work.

Find an ID with `sudo keyd monitor` and press a key on the device.

## Distro support

| Distro | Source |
| --- | --- |
| Fedora | `alternateved/keyd` COPR |
| Debian 13+ / Ubuntu 25.04+ | official archives |
| Older Ubuntu | `ppa:keyd-team/ppa` |
| Arch | `extra` |
| openSUSE | official |
| Void | official |
| Anything else | built from source |

## Troubleshooting

Verify what is actually being emitted:

```
sudo keyd monitor
```

Stop it:

```
sudo systemctl stop keyd
```

If a bad config ever leaves the keyboard unusable, the panic sequence is **backspace + escape + enter**, which forces keyd to terminate.
