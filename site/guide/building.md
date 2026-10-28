# Building from source

Stroad Hero is an open-source [Godot 4.7](https://godotengine.org/) project written in GDScript. The source is on [GitHub](https://github.com/dustinmichels/stroad-hero).

## Requirements

- Godot 4.7, installed at `/Applications/Godot.app` on macOS
- [mise](https://mise.jdx.dev/), which installs the other tools (uv, oxfmt, butler) and runs the project tasks
- Node.js, for this site

## Run the game

```sh
git clone https://github.com/dustinmichels/stroad-hero.git
cd stroad-hero
mise run dev
```

`mise run dev` opens the main scene in a Godot window. You can also open the folder in the Godot editor and press **Run**.

## Test

```sh
mise run test              # fast core suite: obstacle detection, traffic priority, exit yielding
mise run test --extended   # long traffic simulations and secondary systems
mise run test -- <flag>    # one test, e.g. --test-drive-thru
mise run bench             # manual performance benchmarks
```

Format GDScript and Markdown with `mise run fmt`.

## Export

`mise run export-desktop` exports macOS, Windows, and Linux builds to `build/`. Exports run from a copy of the project in `/tmp`, so an open Godot editor isn't disturbed.

## Publish to itch.io

Builds go to [dustinmichels.itch.io/stroad-hero](https://dustinmichels.itch.io/stroad-hero) through [butler](https://itch.io/docs/butler/).

1. `mise run itch-setup` saves your [itch.io API key](https://itch.io/user/settings/api-keys) to `mise.local.toml`, which git ignores.
2. `mise run itch [v1.2.3]` exports all builds and pushes them to the `mac`, `windows`, and `linux` channels. Add `--skip-export` to push the builds already in `build/`.
3. `mise run release [patch|minor|major|v1.2.3]` checks that `main` is committed and pushed, exports, tags the next version, pushes the tag, and publishes to itch.io.

## This site

The site lives in `site/` and is built with [VitePress](https://vitepress.dev/). It reads screenshots from `screenshots/` and Mom's dialogue from `objectives/mats_objectives.json`, so it stays in step with the game. A `.gdignore` file keeps Godot from importing it.

```sh
cd site
npm install
npm run dev       # http://localhost:5173
npm run build     # static site in site/.vitepress/dist
```
