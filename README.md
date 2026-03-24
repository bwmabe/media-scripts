# Video Conversion Scripts

A set of video processing scripts using `ffmpeg`/`ffprobe`.

| Script | Purpose |
|---|---|
| `detect_mode_crop.fish` | Scans a directory of videos, detects crop values for each, and reports the most common (mode) crop |
| `encode_ivtc.fish` | Encodes telecined 480i content (e.g. film-sourced cartoons) using inverse telecine + x265; when passed directories, outputs to `<dir>/converted/` in each — useful for batch processing multiple seasons at once. Flags: `-y` adds a deinterlacer (default `yadif`) after fieldmatch for content with irregular pulldown or residual interlace artifacts; `--deint <filter>` skips IVTC entirely and just deinterlaces with the given filter (e.g. `bwdif`, `yadif`, `estdif`, `w3fdif`) |
| `encode_progressive.fish` | Encodes progressive video with x265, auto-selecting CRF based on resolution (4K/1080p/480p) |
| `encode_progressive_crop.fish` | Like above but also auto-detects and removes letterbox/pillarbox bars |
| `fix_aspect.fish` | Remuxes MKVs in-place to force a specific aspect ratio (default 4:3) |
| `scan_field_order.fish` | Reports the field order (interlaced vs progressive) of video files |
| `rename_episodes.py` | Renames MKV files to `S##E##.mkv` format |
| `extract_frame.fish` | Extracts a single frame as PNG at a given timestamp (default `00:00:30`); accepts `-t timestamp` and optional file args, otherwise globs `*.mkv` in cwd |
