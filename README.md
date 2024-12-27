# Meld for macOS

![main branch](https://gitlab.com/dehesselle/meld_macos/badges/main/pipeline.svg?key_text=main)
![latest release](https://gitlab.com/dehesselle/meld_macos/-/badges/release.svg?key_text=latest%20release&key_width=100&value_width=100)

![screenshot](resources/screenshot.png)

This project builds a macOS app for [Meld](https://meld.app).

The goal is to have [CI](https://gitlab.gnome.org/GNOME/meld/pipelines/latest?ref=main) and official releases in the upstream project, not to run an independent fork. Let's support and consolidate our efforts [upstream](https://gitlab.gnome.org/GNOME/meld) to keep it alive and healthy!

💁 _There is no issue tracker here on purpose._

## Installation

Downloads are available in the [Releases](https://gitlab.com/dehesselle/meld_macos/-/releases) section.  
There is also a [cask](https://formulae.brew.sh/cask/dehesselle-meld#default) available for Homebrew, courtesy of [Klaus Hipp](https://github.com/khipp).

The app is standalone, relocatable and supports macOS High Sierra up to macOS Sequoia.

## Usage

### in the terminal

You probably want to just type `meld` to open it. There are different ways to set that up.

Add an alias to e.g. `~/.zshrc`:

```bash
# This command assumes you are using the ZSH shell.
echo "alias meld='/Applications/Meld.app/Contents/MacOS/Meld'" >> ~/.zshrc
```

Or create a wrapper script that is in your `$PATH`, e.g. in `/usr/local/bin`:

```bash
# Ensure that /usr/local/bin exists and that you have write permission
# before running this command.
echo '/Applications/Meld.app/Contents/MacOS/Meld "$@"' > /usr/local/bin/meld
chmod 755 /usr/local/bin/meld
```

⚠️ Do not create a symlink to the binary in the application bundle, this isn't supported!

### as difftool

```bash
git config --global diff.tool meld
git config --global difftool.prompt false
git config --global difftool.meld.cmd "/Applications/Meld.app/Contents/MacOS/Meld \$LOCAL \$REMOTE"
```

## Acknowledgements

Built using other people's work:

- [gtk-osx](https://gitlab.gnome.org/GNOME/gtk-osx) for building GTK with JHBuild.
- [Meld for OSX](https://github.com/yousseb/meld) for better macOS integration.

## License

This work is licensed under [GPL-2.0-or-later](LICENSE).  
Meld is licensed under [GPL-2.0-or-later](https://gitlab.gnome.org/GNOME/meld/-/blob/main/COPYING?ref_type=heads).
