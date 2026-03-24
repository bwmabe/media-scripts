# Video Conversion Scripts

A set of video processing scripts using `ffmpeg`/`ffprobe`.

| Script | Purpose |
|---|---|
| `encode.fish` | Encodes video with x265 — handles progressive, IVTC, deinterlace, and crop via flags |
| `detect_mode_crop.fish` | Scans a directory of videos, detects crop values for each, and reports the most common (mode) crop |
| `fix_aspect.fish` | Remuxes MKVs in-place to force a specific aspect ratio (default 4:3) |
| `scan_field_order.fish` | Reports the field order (interlaced vs progressive) of video files |
| `rename_episodes.py` | Renames MKV files to `S##E##.mkv` format |
| `extract_frame.fish` | Extracts a single frame as PNG at a given timestamp (default `00:00:30`); accepts `-t timestamp` and optional file args, otherwise globs `*.mkv` in cwd |

## encode.fish

Encodes video files with x265. CRF is auto-selected by resolution unless overridden.

When passed directories, output goes to `<dir>/converted/` inside each one, making it easy to batch multiple seasons:

```
encode.fish --ivtc /shows/rocko/s01 /shows/rocko/s02 /shows/rocko/s03
```

**Flags:**

| Flag | Description |
|---|---|
| `-o <dir>` | Output directory for file inputs (default: `./converted`) |
| `--crf <n>` | x265 CRF (default: auto by resolution — 480p=18, 1080p=18, 4K=16) |
| `--preset <p>` | x265 preset (default: `medium`, e.g. `slow`, `veryslow`) |
| `--ivtc` | Inverse telecine (`fieldmatch,decimate`) for 24fps film content in 480i |
| `-y` | IVTC + yadif deinterlacer for irregular pulldown or residual interlace artifacts |
| `--deint <filter>` | Deinterlace only, no IVTC. Common filters: `yadif`, `bwdif`, `estdif`, `w3fdif` |
| `--crop [value]` | Auto-detect and remove letterbox/pillarbox bars. Optionally supply a manual crop string (e.g. `crop=536:480:92:0`) to skip auto-detection |

Flags can be freely combined — e.g. `--ivtc --crop`, `--deint bwdif --crop crop=536:480:92:0`.

**Examples:**

```
# Plain progressive encode (CRF auto-selected by resolution)
encode.fish movie.mkv

# IVTC for telecined 480i content, multiple season dirs
encode.fish --ivtc /shows/rocko/s01 /shows/rocko/s02

# IVTC + yadif for tricky pulldown, manual quality settings
encode.fish -y --crf 16 --preset slow episode.mkv

# Straight deinterlace, no IVTC
encode.fish --deint bwdif episode.mkv

# Auto crop letterbox bars
encode.fish --crop movie.mkv

# Manual crop value
encode.fish --crop crop=536:480:92:0 /path/to/season/

# IVTC + crop together
encode.fish --ivtc --crop --crf 18 --preset slow episode.mkv
```

For 480i content deinterlaced with `--deint bwdif`, `--crf 16 --preset slow` has produced the best results.
