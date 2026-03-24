# DVD Ripping & Encoding Session Notes

## The Problem

A batch conversion job produced MKV files with mangled metadata and baked-in pillarbox bars:

- **Source**: 720x480 DVD content, SAR 32:27, DAR 16:9 — widescreen frame with pillarbox bars baked in to pad 4:3 content
- **After bad conversion**: SAR changed to 8:9, DAR 4:3 — content appeared squished
- **Reality**: The content is genuine 4:3 material; the DVD was padding it out to 16:9 with side bars

The fix required two things:
1. Crop the pillarbox bars out during a fresh x265 re-encode
2. Correct the aspect ratio metadata on the output

---

## Scripts Produced

All scripts should be placed in `~/.local/bin/` and made executable with `chmod +x`.

---

### `rename_episodes.py`

Renames all MKV files in the current directory alphabetically to `S##E##.mkv`.

**Flags:**
- `-s` — season number (required)
- `-e` — first episode number (default: 1)
- `--dry-run` — preview without renaming

**Examples:**
```sh
rename_episodes.py -s 3
rename_episodes.py -s 3 -e 5
rename_episodes.py -s 3 --dry-run
```

**Notes:**
- Zero-pads season and episode to two digits (`S03E07`)
- Aborts before touching anything if a target filename already exists

---

### `scan_field_order`

Runs ffprobe on video files to report the field order of each.

**Usage:**
```sh
scan_field_order            # all files in cwd
scan_field_order *.mkv      # specific glob
scan_field_order a.mkv b.mkv
```

---

### `detect_mode_crop.fish`

Samples every video file in a directory using ffprobe cropdetect and reports the most commonly detected crop value (the mode).

**Usage:**
```sh
detect_mode_crop.fish /path/to/season/
detect_mode_crop.fish       # defaults to cwd
```

**Example output:**
```
Sampling 12 file(s)...
  S03E01.mkv: crop=536:480:92:0
  S03E02.mkv: crop=536:478:92:2
  ...

Results:
  9 x crop=536:480:92:0
  3 x crop=536:478:92:2

Mode crop (9/12 files): crop=536:480:92:0
```

**Notes:**
- Samples 1 minute starting at the 5-minute mark to avoid black title cards
- Falls back to sampling from the start for short files
- `cropdetect limit=32` is used to handle compression noise at bar edges
- The 2px variance (478 vs 480) is noise — trust your eyes with ffplay and hardcode

---

### `encode_progressive_crop.fish`

x265 re-encode with automatic crop detection. Based on `encode_progressive.fish` with crop support added.

**Flags:**
- `-o output_dir` — output directory (default: `./converted`)
- `-c crop=W:H:X:Y` — hardcode a crop value, skipping per-file auto-detection

**Usage:**
```sh
encode_progressive_crop.fish -c crop=536:480:92:0 -o ./converted /path/to/season/
encode_progressive_crop.fish movie.mkv
encode_progressive_crop.fish /path/to/season/
```

**CRF settings:**
- 4K (2000p+): CRF 22, HDR10 flags
- 1080p+: CRF 22
- 480p and below: CRF 18

**Notes:**
- Auto-detection samples 1 min at the 5-minute mark, falls back to start for short files
- Preserves source SAR via `setsar` after cropping
- `-map 0` ensures all streams including subtitles are carried through
- Always use `-c crop=...` for a whole season once you've verified the crop with ffplay

---

### `fix_aspect.fish`

Remuxes MKV files in place to correct aspect ratio metadata. No re-encode — pure container metadata fix.

**Flags:**
- `-a aspect` — aspect ratio to set (default: `4:3`)

**Usage:**
```sh
fix_aspect.fish                        # all MKVs in cwd, 4:3
fix_aspect.fish S03E01.mkv S03E02.mkv  # specific files
fix_aspect.fish -a 16:9 *.mkv          # different aspect
```

**Notes:**
- Uses `-map 0` to preserve all streams including subtitles
- Writes to a `.tmp.mkv` then moves over the original — safe, only replaces on success

---

## Season 3 Specifics

- **Crop value**: `crop=536:480:92:0` (verified with ffplay)
- **Aspect ratio**: `4:3` — 536x480 with SAR 32:27 works out to ~4:3 DAR, not 16:9
- **Subtitles**: `dvd_subtitle` (bitmap). Were being dropped by the aspect ratio fix step until `-map 0` was added. The encode itself was fine.
- **Workflow used**:
  1. `detect_mode_crop.fish` to find crop value
  2. Verify with `ffplay -vf crop=536:480:92:0 S03E01.mkv`
  3. `encode_progressive_crop.fish -c crop=536:480:92:0 -o ./converted /path/to/season/`
  4. `fix_aspect.fish` on the output to correct DAR to 4:3

---

## Workflow for Future Discs

```sh
# 1. Rename files
rename_episodes.py -s 4 -e 1

# 2. Find the crop
detect_mode_crop.fish .

# 3. Verify crop visually
ffplay -vf crop=W:H:X:Y S04E01.mkv

# 4. Encode
encode_progressive_crop.fish -c crop=W:H:X:Y -o ./converted .

# 5. Fix aspect if needed (may not apply to other seasons)
cd ./converted
fix_aspect.fish
```

**The crop and aspect ratio situation may differ per season/disc** — always run `detect_mode_crop.fish` and verify with ffplay before batch encoding.

---

## Key ffprobe/ffmpeg One-Liners

Check streams on a file:
```sh
ffprobe -v error -show_entries stream=index,codec_type,codec_name -of default=noprint_wrappers=1 file.mkv
```

Check SAR/DAR:
```sh
ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height,sample_aspect_ratio,display_aspect_ratio \
    -of default=noprint_wrappers=1 file.mkv
```

Manual cropdetect on one file:
```sh
ffmpeg -ss 00:05:00 -i file.mkv -t 00:01:00 \
    -vf cropdetect=limit=32:round=2:reset=0 \
    -f null - 2>&1 | grep cropdetect | tail -5
```

Preview crop without re-encode:
```sh
ffplay -vf crop=536:480:92:0 file.mkv
```
