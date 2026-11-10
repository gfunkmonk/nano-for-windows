<div align="center">

# NANO FOR WINDOWS

[![Build](https://github.com/gfunkmonk/nano-for-windows/actions/workflows/Build.yml/badge.svg)](https://github.com/gfunkmonk/nano-for-windows/actions/workflows/Build.yml) [![SyncNano](https://github.com/gfunkmonk/nano-for-windows/actions/workflows/SyncNano.yml/badge.svg)](https://github.com/gfunkmonk/nano-for-windows/actions/workflows/SyncNano.yml) [![Toolchain](https://github.com/gfunkmonk/nano-for-windows/actions/workflows/toolchain-builder.yml/badge.svg)](https://github.com/gfunkmonk/nano-for-windows/actions/workflows/toolchain-builder.yml)
[![Version](https://img.shields.io/github/v/release/gfunkmonk/nano-for-windows)](https://github.com/gfunkmonk/nano-for-windows/releases/latest) [![GitHub All Releases](https://img.shields.io/github/downloads/gfunkmonk/nano-for-windows/total.svg)](https://github.com/gfunkmonk/nano-for-windows/blob/releases/README.md#installation)

</div><br/><br/>

This is a 64-bit/32-bit and Windows on ARM port of the legendary **[GNU nano text editor](https://www.nano-editor.org/)**, a small and compact CLI editor that packs a world of functionality in a small footprint (less than 300KB). It can be run in a Windows Terminal, Powershell window, Command Prompt window, SSH session, or similar environment.

GNU nano is constantly being upgraded, but the original project is focused on providing support and functionality for Linux. This project is meant to bring the latest updates to both 64-bit and 32-bit Windows users.

<div align="center"><img width="930" alt="image" src="https://github.com/user-attachments/assets/5b437953-2355-4395-8b77-816a9ce0143f">
</div>

# Features ported to Windows

Pretty much everything is supported except for Linux-specific functions, including:

- Interface customization: colors, key shortcuts, line numbers, infobar, scroll bar, etc...
- Syntax coloring for 47 different types of documents. It can be upgraded thanks to community support, for instance [here](https://github.com/scopatz/nanorc) or [here](https://github.com/mitchell486/nanorc) you can find additional syntax files for many other document types.
- Full support for UTF-8 encoded files.
- Supplemental Unicode character support, including all the languages and emojis 😜in the CLI interface.
- Multi-document editor.
- Integrated file browser.
- Mouse support for scroll and cursor location.
- Normal and regular expression (regex) search and replace.
- Auto-indent, syntax highlight and fast line comment for many programming languages.
- Line wrap, search, cut, copy & paste, and all the basic functions of any full-fledged editor.
- Data input through stdin support, from a pipe or the keyboard.
- Transparent backgrounds in Windows Terminal, and other supported environments.
- Beta native support for Windows on ARM (WoA)

<div align="center"><img width="947" alt="image" src="https://github.com/user-attachments/assets/96f12597-b9af-4d20-a0d5-88950218f71d"></div>
<div align="center"><img with="925" alt="image" src="https://github.com/user-attachments/assets/94db9963-cd5d-4be9-9da4-5608d0fa49dc"></div>
<br/>

# Windows-specific extras
<div align="center"><img width="930" alt="image" src="https://github.com/user-attachments/assets/bf02b197-ef36-4b3d-8b34-eee01b6ba6d2">
</div>

This build includes features beyond the standard GNU nano port that are unique to this project:

- **Extended color palette** — 86 named colors available in `.nanorc` (up from nano's default 34), including `junebud`, `coral`, `violet`, `hotpink`, `frost`, `volt`, and many more. Use them anywhere a color name is accepted: `set titlecolor`, `color`, etc.
- **Search history on open** — when you open the search prompt (`^W`), the most recent search from your history is pre-loaded so you can search again immediately without retyping.
- **No-wrap search** — add `set nosearchwrap` to your `.nanorc`, or pass `--nosearchwrap` on the command line, to stop search and replace from wrapping around the end of the file.
- **Set syntax on the fly** — press `M-5` (or bind `setsyntax` in `.nanorc`) to switch syntax highlighting for the current buffer without restarting.
- **Set tab size on the fly** — press `M-4` (or bind `settabsize` in `.nanorc`) to change the tab width for the current buffer without restarting.
- **Toggle line numbers on/off** — press `M-2` (or bind `togglelinenumbers` in `.nanorc`) to toggle line numbers on/off without restarting.
- **Native file dialogs (WinGUI build only)** — the WinGUI variant (`*_WinGUI_*` zip) uses the standard Windows Open/Save dialogs when inserting or saving files, giving you shell integration, bookmarks, and recent files. The built-in nano file browser is still accessible as a fallback.
- **Robust home directory fallback** — nano looks for your profile in `USERPROFILE`, then `APPDATA`, and finally the directory containing `nano.exe` itself. This means portable installs work even in environments where profile variables aren't set.
- **Color emoji rendering** — Wincon and VT use pdcurses for emoji support, however, the WinGUI build renders color emoji via Direct2D, so emoji and symbols display in full color rather than GDI monochrome.
  
# Installation via direct download

Visit the [releases](https://github.com/gfunkmonk/nano-for-windows/releases) page, and download the latest release file ending in `.zip` for your architecture (Windows 32, Windows 64, or Windows on Arm). Then unzip the file to a directory in your `%PATH%`.

# Portable install

Every release zip is self-contained — no installer, no registry entries. To run nano from a USB drive or a folder that isn't in `%PATH%`:

1. Unzip the release archive anywhere you like, e.g. `D:\tools\nano\`.
2. Run `nano.exe` directly, or add the folder to your session path:
   ```pwsh
   $env:PATH += ";D:\tools\nano"
   ```
3. Your `.nanorc` and syntax files are picked up from the same folder as `nano.exe`, so the whole thing is portable as-is.

nano looks for your config in this order: `%USERPROFILE%`, then `%APPDATA%`, then the directory containing `nano.exe`. That last fallback is what makes portable installs work even on machines where those environment variables aren't set — just drop a `.nanorc` next to `nano.exe` and it will be found automatically.

# Usage

This repo handles only the conversion to the Windows OS. The original GNU nano **[documentation](https://www.nano-editor.org/docs.php)** covers all the usage instructions. For a quick reference, you can just press F1 within nano to open the integrated help.

The interface customization file is located in the user profile and has good descriptions of each setting. To edit it, just open a powershell terminal, and type:
```pwsh
nano ~/.nanorc
```
# Notes

- When using Windows Terminal and the screen is resized within nano, after returning to the shell there could be some corruption due to the new size. To fix the issue without losing the terminal history just resize the terminal window to zero lines and return to the desired size.

- Feel free to open any issue you find, or use the [Discussions](https://github.com/gfunkmonk/nano-for-windows/discussions) section for any other issue, suggestion, question, etc...

# Special Mention & Thanks

- original idea and repo this work is built from https://github.com/okibcn/nano-for-windows

- and I shamelessly stole most of the nano patches from https://github.com/chawyehsu/nano-for-windows

- nosearchwrap settabsize & change syntax on the fly patches here https://github.com/davidhcefx/GNU-Nano-Extended
