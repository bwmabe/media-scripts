# Video Conversion Scripts

A set of video processing scripts using `ffmpeg`/`ffprobe`.

| Script | Purpose |
|---|---|
| [`encoder-thing/`](encoder-thing/) | x265 batch encoder with live TUI — queue, progress, keyboard controls |
| `detect_mode_crop.fish` | Scans a directory of videos, detects crop values for each, and reports the most common (mode) crop |
| `fix_aspect.fish` | Remuxes MKVs in-place to force a specific aspect ratio (default 4:3) |
| `scan_field_order.fish` | Reports the field order (interlaced vs progressive) of video files |
| `rename_episodes.py` | Renames MKV files to `S##E##.mkv` format |
| `extract_frame.fish` | Extracts a single frame as PNG at a given timestamp (default `00:00:30`); accepts `-t timestamp` and optional file args, otherwise globs `*.mkv` in cwd |

## encoder-thing

See [encoder-thing/README.md](encoder-thing/README.md) for full docs.

**Setup (once per machine):**

```
cd encoder-thing
./install.fish
```

Creates a venv, installs `rich`, and offers to symlink `encoder-thing` into
`~/.local/bin` so it's available system-wide.

**Usage:**

```
encoder-thing [flags] <input_file|dir> [...]
```

Keys: `p`/`space` pause · `s` skip · `q` quit
