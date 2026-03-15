# FancyTasks Reloaded

FancyTasks Reloaded is a KDE Plasma task manager plasmoid for Plasma 6. It keeps the familiar taskbar workflow, then adds more styling, more layout control, and more behavior options than the stock task manager exposes by default.

This repository is an actively maintained Plasma 6 fork of the original FancyTasks plasmoid (found here: https://github.com/alexankitty/FancyTasks), itself based on KDE's task manager applet (found here: https://invent.kde.org/plasma/plasma-workspace/-/tree/master/applets/taskmanager)

![FancyTasks Reloaded Icon](package/FancyTasksReloaded.png)

## Goals

- Keep a traditional taskbar-style workflow with icons and optional labels.
- Expose the customization Plasma users usually end up patching around by hand.
- Stay usable on modern Plasma 6 systems without requiring users to rebuild KDE components.
- Provide a practical fork that remains installable, testable, and maintainable outside the upstream desktop package tree.

## Features

- Icons-only and text-label taskbar modes.
- Configurable grouping, sorting, launcher separation, and click behavior.
- Multiple grouped-task interaction modes, including cycling, tooltip thumbnails, side-by-side window display, and textual lists when compositor support is limited.
- Adjustable task sizing, icon scaling, icon pixel sizing, spacing, and stripe layout.
- Hover effects like bounce and magnifying glass, floating icon shadows, and minimized-window previews.
- Audio-stream indicators for apps currently playing sound.
- Custom indicator system with animated styles such as Metro, Ciliora, and Dashes.
- Indicator position, size, color, min/max count, progress display, and minimized-state effects.
- Button colorization using Plasma accent color, dominant icon color, or a custom color.
- Plasma border and button-decoration overrides for floating or heavily customized panels.

## Requirements

- KDE Plasma 6 with the task manager and workspace packages installed.
- `kpackagetool6`
- `python3`
- Kirigami/QML runtime provided by your Plasma desktop packages

FancyTasks Reloaded currently depends on some Plasma private task manager and audio APIs, so it is expected to work best when your installed Plasma desktop packages match the target runtime.

## Installation

Clone the current repository:

```bash
git clone https://github.com/Kombatant/FancyTasksReloaded.git
cd FancyTasksReloaded
```

Install the plasmoid with the helper script:

```bash
./install.sh
```

That script:

- installs or upgrades the current package from `./package`
- installs the app icon into `~/.local/share/icons/hicolor/256x256/apps/`

You can also install manually:

```bash
kpackagetool6 --type Plasma/Applet --install ./package
```

Important: the plasmoid root is `./package`, not the repository root. Commands such as `kpackagetool6 --type Plasma/Applet --upgrade .` will fail because the package metadata expects `ui/main.qml` relative to `./package`.

After installation:

1. Right-click the Plasma panel.
2. Choose `Add Widgets`.
3. Search for `FancyTasks Reloaded`.
4. Add it to the panel and open `Configure FancyTasks Reloaded...`.

## Updating

Use the provided update helper:

```bash
./update.sh
```

This upgrades the package, restarts `plasmashell`, and reinstalls the icon asset. Manual upgrade is also possible:

```bash
kpackagetool6 --type Plasma/Applet --upgrade ./package
```

## Testing

To run the plasmoid in a standalone Plasma window for development:

```bash
./testing.sh
```

## Special Note: `patch-kicker.py`

This repository includes [`patch-kicker.py`](/home/kombatant/Dev/languages/fancytasks/patch-kicker.py), a Python utility that patches:

```text
/usr/lib/qt6/qml/org/kde/plasma/private/kicker/libkickerplugin.so
```

Why it exists:

- Kicker/Kickoff keeps a hardcoded list of task manager plugin IDs.
- FancyTasks Reloaded uses `org.kombatant.fancytasks_rld`.
- Without the patch, launcher menus may not show `Pin to Task Manager` for FancyTasks Reloaded and window previews when minimizing may not work correctly.

What it does:

- replaces the unused hardcoded string `org.kde.plasma.expandingiconstaskmanager`
- inserts `org.kombatant.fancytasks_rld`
- updates the embedded string length
- creates a backup beside the library as `libkickerplugin.so.bak`

Usage:

```bash
sudo python3 patch-kicker.py
sudo python3 patch-kicker.py --revert
```

Notes:

- This modifies a system library, so it requires root privileges.
- Re-run it after each `plasma-workspace` update, since package upgrades can replace the patched library.
- Restart Plasma afterward:

```bash
kquitapp6 plasmashell && plasmashell --replace &
```

## Translations

Translation helper files live under `package/translate/`. The existing translation notes are in [`package/translate/ReadMe.md`](/home/kombatant/Dev/languages/fancytasks/package/translate/ReadMe.md).

## Screenshots

![Colorful tasks](docs/colorfulicons%20crop.png)
![Metro](docs/metro.png)
![Ciliora](docs/ciliora.png)
![Dashes](docs/dashes.png)
![Dots](docs/dots.png)
![Desaturated minimized tasks](docs/desaturate%20crop.png)
![Minimized task shrinking](docs/shrink%20crop.png)

## Contact

Issues, bug reports, and pull requests should go through the GitHub repository:

- <https://github.com/Kombatant/FancyTasksReloaded>
- <https://github.com/Kombatant/FancyTasksReloaded/issues>

## License

FancyTasks Reloaded is distributed under the GPL. See [`LICENSE`](/home/kombatant/Dev/languages/fancytasks/LICENSE).
