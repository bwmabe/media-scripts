# Video Conversion Scripts

A set of video processing scripts using `ffmpeg`/`ffprobe`.

| Script | Purpose |
|---|---|
| `detect_mode_crop.fish` | Scans a directory of videos, detects crop values for each, and reports the most common (mode) crop |
| `encode_ivtc.fish` | Encodes telecined 480i content (e.g. film-sourced cartoons) using inverse telecine + x265 |
| `encode_progressive.fish` | Encodes progressive video with x265, auto-selecting CRF based on resolution (4K/1080p/480p) |
| `encode_progressive_crop.fish` | Like above but also auto-detects and removes letterbox/pillarbox bars |
| `fix_aspect.fish` | Remuxes MKVs in-place to force a specific aspect ratio (default 4:3) |
| `scan_field_order.fish` | Reports the field order (interlaced vs progressive) of video files |
| `rename_episodes.py` | Renames MKV files to `S##E##.mkv` format |
| `extract_frame.fish` | Extracts a single frame as PNG at a given timestamp (default `00:00:30`); accepts `-t timestamp` and optional file args, otherwise globs `*.mkv` in cwd |

## encode_ivtc.fish

Recovers original 24fps progressive frames from telecined 480i content via inverse telecine, then encodes with x265 CRF 18.

When passed directories, output goes to `<dir>/converted/` inside each one, making it easy to batch multiple seasons:

```
encode_ivtc.fish /shows/rocko/s01 /shows/rocko/s02 /shows/rocko/s03
```

**Modes:**

| Flag | Behaviour |
|---|---|
| _(none)_ | `fieldmatch,decimate` — standard IVTC for clean telecined content |
| `-y` | `fieldmatch,yadif=deint=interlaced,decimate` — adds a deinterlacer pass for content with irregular pulldown or residual interlace artifacts |
| `--deint <filter>` | Skips IVTC entirely; just deinterlaces with the given filter. Common filters: `yadif`, `bwdif`, `estdif`, `w3fdif` |

**Other flags:**

| Flag | Description |
|---|---|
| `-o <dir>` | Output directory for file inputs (default: `./converted`) |
| `--crf <n>` | x265 CRF value (default: `18`, lower = better quality) |
| `--preset <p>` | x265 preset (default: `medium`, e.g. `slow`, `veryslow`) |
