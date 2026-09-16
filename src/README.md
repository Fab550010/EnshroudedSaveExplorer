# EnshroudedSaveExplorer

EnshroudedSaveExplorer is an unofficial Windows utility for exploring progression data stored in Enshrouded save files.

It can inspect a save and show which quests and lore entries have been discovered or completed.

## Features

* Automatically discovers local Enshrouded saves
* Supports manual save-file selection
* Displays quest progression
* Displays lore progression
* Filters and searches quest and lore entries
* Shows completed, incomplete and partially discovered entries
* Opens the corresponding Enshrouded Wiki page by double-clicking an entry
* Monitors the active save for updates
* Runs as a standalone Windows executable

## Status

Current version: **0.1.0**

This is an early public release.

The save formats used by Enshrouded are not officially documented and may change between game updates. A future game update may therefore temporarily break some features.

## Requirements

* Windows 64-bit
* Enshrouded installed locally if automatic save discovery is used

The release build is distributed as a standalone executable and does not require a separate Zstd DLL.

## Building

The project is written in Free Pascal using Lazarus.

Open:

`src/gui/EnshroudedSaveExplorer.lpi`

in Lazarus and select the `Release` build mode.

The repository contains the static libraries required for the Windows build under:

* `src/third_party/zstd/win64`
* `src/third_party/mingw/win64`

## Save files

EnshroudedSaveExplorer only reads save data.

It does not intentionally modify save files.

As with any unofficial save-related tool, keeping backups of important saves is recommended.

## License

The original EnshroudedSaveExplorer source code is released under the Zero-Clause BSD license (`0BSD`).

See [LICENSE](LICENSE).

Third-party components retain their respective licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Disclaimer

EnshroudedSaveExplorer is an unofficial community project.

It is not affiliated with, endorsed by, or sponsored by Keen Games.

Enshrouded and related names and trademarks belong to their respective owners.

## Acknowledgements

Thanks to [Brabb3l/kfc-parser](https://github.com/Brabb3l/kfc-parser) for providing a useful public reference for understanding the KFC container format used by Enshrouded.

EnshroudedSaveExplorer implements its own parser independently; no source code from kfc-parser is included.
