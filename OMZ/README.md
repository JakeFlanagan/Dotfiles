# OMZ — Oh My Zsh Configuration

Zsh environment built around [Oh My Zsh](https://ohmyz.sh/) with the [Powerlevel10k](https://github.com/romkatv/powerlevel10k) prompt. Installed and linked by `install.sh` in this directory.

---

## Quick Start

From the repo root:

```bash
bash OMZ/install.sh
```

Or the one-liner if you haven't cloned yet:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/JakeFlanagan/Dotfiles/main/OMZ/install.sh)
```

---

## Files

### `Home Folder/.zshrc`

Main Zsh config. Loads Powerlevel10k with instant prompt, sets the theme, and registers plugins.

**Plugins loaded:**

| Plugin | What it does |
|---|---|
| `git` | Git aliases and prompt integration |
| `dnf` | RPM package manager shortcuts |
| `sudo` | Double-tap `Esc` to prepend `sudo` to the current command |
| `zsh-autosuggestions` | Fish-style inline command suggestions based on history |
| `zsh-syntax-highlighting` | Live syntax colouring as you type |

---

### `Home Folder/.p10k.zsh`

Powerlevel10k prompt config — generated via `p10k configure`.

**Style:** Powerline · Rainbow · Unicode · 24h time · Angled separators · 2-line prompt · Instant prompt enabled

**Left prompt:** `dir` → `vcs` (git status) → newline → `prompt_char`

**Right prompt:** `status` · `command_execution_time` · `background_jobs` · `context` · `time` (and a full suite of optional dev environment segments that activate contextually)

To reconfigure: `p10k configure`

---

### `Home Folder/.oh-my-zsh/` — Custom Scripts

All `.zsh` files in this directory are automatically symlinked into `~/.oh-my-zsh/custom/` by the installer. Add a file here, re-run `install.sh`, it's live. Remove one, it's gone on the next fresh install.

---

#### `functions.zsh` — Custom `ll`

Replaces the standard `ll` alias with a fully custom implementation. Calls `ls` with extended flags then pipes through `awk` for formatted, colourised tabular output.

**Columns:** File/Folder · Size · Author · Date · Owner/Group · Octal permissions

**Colour coding:**

| Colour | Meaning |
|---|---|
| Blue | Directory |
| Cyan | Symlink |
| Green | Executable |
| White | Regular file |
| Red | `root` ownership |
| Orange | Foreign user ownership |
| Grey | Current user ownership |

**Requires:** `gawk` — the function will tell you if it's missing and show the install command for your distro.

---

#### `file_lock.zsh` — Recursive File Locking

```zsh
lock    # sudo chattr -R +i *  — recursively immute all files in CWD
unlock  # sudo chattr -R -i *  — recursively remove immutability
```

Useful for protecting directories from accidental modification or deletion. Requires `chattr` (standard on Linux, part of `e2fsprogs`).

> **Note:** Locked files cannot be modified or deleted even by root without first running `unlock`.

---

#### `clear.zsh` — Quality of Life

```zsh
cl    # alias for clear
```

---

## Adding Custom Scripts

Drop any `.zsh` file into `OMZ/Home Folder/.oh-my-zsh/` and re-run `install.sh`. The installer dynamically symlinks everything it finds there — no hardcoded paths, no script edits required.
