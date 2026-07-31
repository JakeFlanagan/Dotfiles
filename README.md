# Dotfiles

> Personal dotfiles for cross-machine continuity. Configs, tooling, and shell preferences: everything needed to make any new box feel like home.

<div align="center">

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

</div>

---

## Install

Each section is independent. Run only the ones you want, in any order.

| Section | What it does | Install |
|---|---|---|
| **OMZ** | Zsh, Oh My Zsh, Powerlevel10k, plugins | `bash <(curl -fsSL https://raw.githubusercontent.com/JakeFlanagan/Dotfiles/main/OMZ/install.sh)` |
| **Keyd** | Logitech G502 button remapping via keyd | `bash <(curl -fsSL https://raw.githubusercontent.com/JakeFlanagan/Dotfiles/main/Keyd/install.sh)` |

Installers are idempotent and back up anything they overwrite. See the README in each folder for details and options.

---

## Structure

```
dotfiles/
├── Binaries/   # Standalone scripts and helpers
├── Keyd/       # Input remapping, G502 buttons to numpad, via keyd
└── OMZ/        # Zsh, Oh My Zsh, Powerlevel10k, plugins, custom scripts
```

Sections are added as needed. Each lives in its own folder with its own installer and README.

---

## Licence

JakeFlanagan/Dotfiles is licensed under the **GNU General Public License v3.0**.

| Permissions | Limitations | Conditions |
|---|:---:|:---:|
| ✅ Commercial use | ❌ Liability | 📋 License and copyright notice |
| ✅ Modification | ❌ Warranty | ✏️ State changes |
| ✅ Distribution | | 📂 Disclose source |
| ✅ Patent use | | 🔄 Same license |
| ✅ Private use | | |
