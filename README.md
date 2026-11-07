# beautify-tmux

A small tmux config that puts a status light on every pane. I run several AI coding agents side by side over SSH, and I kept losing track of which one was still working, which one had finished, and which one was sitting there waiting for me to answer. Now the pane border tells me.

🟡 busy &nbsp; 🟢 done &nbsp; 🔴 needs you

![Four tmux panes, each with its own status light and coloured border](docs/demo.gif)

[Leia em português](README.pt-BR.md)

## What it does

Every pane gets a title bar with the light, the folder it's in, and the pane title. The border takes the colour of the light, so you can see the state of every pane from across the room. Panes with no light keep a grey border, and the active pane gets a white label.

Borders are drawn with double lines over a grey strip, which gives panes some breathing room on a crowded screen.

Alt + arrow keys move between panes without the prefix.

It is one file with ten tmux commands in it. No plugin manager, no theme engine.

## Install

You need tmux 3.2 or newer (`tmux -V`).

```sh
git clone https://github.com/felpk/beautify-tmux ~/.beautify-tmux
~/.beautify-tmux/install.sh
```

The installer adds one `source-file` line to your `~/.tmux.conf` and keeps a backup of the old file. Run it twice and nothing changes the second time.

### With Claude Code

```sh
~/.beautify-tmux/install.sh --claude
```

This also registers three hooks in `~/.claude/settings.json` (it needs `jq`, and it backs up the file first):

| Claude Code event | Light |
|---|---|
| You send a prompt | 🟡 |
| Claude finishes its turn | 🟢, or 🔴 if the last line of the reply is a question |
| Claude asks for a permission or an answer | 🔴 |

Your existing hooks stay where they are.

### With anything else

The light is just a pane option called `@light`, so any script can set it. The hook script works on its own:

```sh
~/.beautify-tmux/hooks/tmux-light.sh busy
make deploy && ~/.beautify-tmux/hooks/tmux-light.sh done || ~/.beautify-tmux/hooks/tmux-light.sh ask
```

Or set it straight from tmux:

```sh
tmux set -p @light 🟢
tmux set -p -u @light   # turn it off
```

## Keys

| Key | Action |
|---|---|
| `Alt + ←` `→` `↑` `↓` | Move to the pane in that direction |

Everything else is stock tmux.

## Customize

Open `tmux.conf`. The colours are tmux colour numbers: `colour46` green, `colour196` red, `colour220` yellow, `colour245` grey, `colour239` the strip behind the border. Run `tmux source-file ~/.tmux.conf` after editing.

If you'd rather have single-line borders, change `double` to `single` or `heavy`.

## Uninstall

```sh
~/.beautify-tmux/uninstall.sh
rm -rf ~/.beautify-tmux
```

It removes the `source-file` line and the Claude Code hooks it added. The rest of your config is left alone.

## How the demo was made

`scripts/demo.sh` starts a throwaway tmux server with this config, attaches to it from a second throwaway server, and captures the screen frame by frame. The frames go through a small ANSI-to-HTML converter, Playwright takes the screenshots, and ffmpeg stitches the GIF. So the GIF above is the actual config, not a mockup.

## License

MIT
