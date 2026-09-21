<div align="center">

# gitframe

**A quick, keyboard-first look at your own GitHub history, right on your desktop.**

Contribution graph, streaks, recent commits and your repositories in one
black-and-white overlay. Press a key, take a look, press it again.

![License](https://img.shields.io/badge/license-GPL--3.0-blue)
![Toolkit](https://img.shields.io/badge/Qt-PySide6-41cd52)
![Platform](https://img.shields.io/badge/platform-Wayland%20%C2%B7%20wlr--layer--shell-informational)

</div>

---

<div align="center">

![gitframe Overview](https://github.com/user-attachments/assets/59c2c8da-270f-40f8-b685-8dc1d27eaf7b)

![gitframe Repositories](https://github.com/user-attachments/assets/b80de078-a859-4c28-b0c7-915143df4c51)

</div>

---

## Why this exists

I wanted a fast way to look at my git history without opening a browser, so I
built this small app with [Claude Code](https://claude.com/claude-code). The
result turned out too nice not to share.

## Features

- **Zero configuration**: it uses your existing `gh` login. No token to paste,
  no config file.
- **Overview**: profile header, a full-year contribution heatmap you can step
  through year by year, stat tiles for today, current streak, best streak and
  this year, and your five most recent commits.
- **Repositories**: every repository you own, with a detail panel for the one
  under the cursor. It shows stars, commits, pull requests, the language
  breakdown, recent commits and top contributors.
- **Search and filter**: type to filter by name or description, and cycle
  `All` / `Public` / `Private`.
- **Pinned repositories** in the sidebar, one keypress away from the browser.
- **Keyboard-first**: `hjkl` or the arrow keys everywhere. The mouse works too.
- **Opens instantly**: the last snapshot is cached, drawn on launch and
  refreshed in the background. If you are offline, the cached data stays on
  screen.
- **Read-only**: it never writes anything to GitHub.
- **On demand**: it runs only while it is open. Opening a link, pressing `Q`
  or clicking outside the window closes it.

## Supported compositors

gitframe draws itself as a `wlr-layer-shell` overlay. It has only been tested
on **Hyprland**, but it should work on other compositors that implement the
protocol, such as Sway, river or niri.

It does not run on GNOME or X11.

## Installation

> [!IMPORTANT]
> **Install PySide6 from your distribution, not pip.** `layer-shell-qt` is a
> compiled Qt plugin, so its Qt version has to match the one PySide6 uses.
> Distro packages always match. A pip-installed PySide6 bundles its own Qt and
> may fail to load the overlay.

**1. Install the dependencies**

| Dependency | Purpose |
| --- | --- |
| `pyside6` | the Qt 6 / QML runtime |
| `layer-shell-qt` | the overlay |
| `github-cli` (`gh`) | fetches your data, using your existing login |
| `ttf-jetbrains-mono-nerd` | the font and the icons |

On Arch:

```fish
sudo pacman -S pyside6 layer-shell-qt github-cli ttf-jetbrains-mono-nerd
```

On other distros, install the same packages with your package manager. The
names vary, for example `python3-pyside6`.

**2. Log in to GitHub**, if you haven't yet:

```fish
gh auth login
```

**3. Run it**

```fish
git clone https://github.com/Roberth-Souza/gitframe
cd gitframe
python main.py
```

## Setup (Hyprland)

**Keybind.** Launching it again while it is open closes it, so one key toggles
it:

```lua
-- ~/.config/hypr/modules/keybinds.lua
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("python /path/to/gitframe/main.py"))
```

**Blur (recommended).** The background is 90% black. Hyprland does not blur
layer surfaces unless a rule asks for it, and without blur the windows behind
gitframe show through:

```lua
-- ~/.config/hypr/modules/winrules.lua
hl.layer_rule({
    name         = "gitframe",
    match        = { namespace = "^gitframe$" },
    blur         = true,
    ignore_alpha = 0.5,
})
```

## Usage

| Key | Action |
| --- | --- |
| `h` `j` `k` `l` / arrows | move |
| `Enter` / `Space` | open the tab, link or repository under the cursor |
| `/` | search repositories |
| `Escape` | step back: stop typing, then return to the sidebar, then close |
| `R` / `F5` | refresh |
| `Q` | close |

In the heatmap, `h`/`l` move between days. On the year control, they step the
year.

### Sorting

The search field opens with `@stars` already typed, so the list is **sorted by
stars**. Repositories with no stars stay at the bottom, most recently pushed
first.

If you don't want that, **just delete `@stars`**: the list goes back to the
most recently pushed order.

`@stars` also works together with a search: `@stars wall` keeps only the
repositories matching `wall` and sorts them by stars.

## Privacy

gitframe never sees your token: every request goes through `gh`. Your data is
cached in `~/.cache/gitframe/`, readable only by your user. Delete that folder
to clear it.

## License

[GPL-3.0](LICENSE)
