# SpongeBob DVD Encoding Project — Session Summary

## Overview

This session covered the full design and implementation of a pipeline to convert a complete SpongeBob SquarePants DVD rip collection (ripped with MakeMKV, ~545 source MKV files) into x265-encoded MKVs with proper episode naming, artifact trimming, and Jellyfin-compatible output.

---

## Encoding Settings

### Codec and Format
- Input: MPEG-2 from DVD rips via MakeMKV
- Output: x265 (libx265) in MKV container
- Audio: stream copy (AC3/Dolby preserved as-is, no re-encode)
- Subtitles: stream copy

### CRF Selection
- Tested CRF 18 as the primary setting
- SpongeBob's flat cel animation compresses extremely well — CRF 20-22 would likely be indistinguishable and save more space, but CRF 18 was chosen for archive quality
- The interactive CRF guide built during the session covers the tradeoffs across resolutions

### Preset
- `slow` chosen for quality; adds ~40-50% encode time vs `medium` but produces better compression
- On the weak always-on machine, this is acceptable given the batch runs unattended

---

## Deinterlacing and IVTC

### Source characteristics
- All content is 480i, 29.97fps NTSC
- SpongeBob is film-sourced animation — drawn on paper and shot on film, then telecined to 29.97i for broadcast
- This makes it an ideal candidate for inverse telecine (IVTC)

### Filter comparison (9-minute test clip on slow machine)
| Filter | Encode time | File size |
|--------|-------------|-----------|
| None | 661s | 224MB |
| yadif | 620s | 181MB |
| fieldmatch,decimate (IVTC) | 601s | 193MB |

- IVTC is fastest on both machines because clean 24fps progressive frames are easier for x265 to motion-estimate than interlaced or yadif-reconstructed frames
- IVTC produces 24fps output (the original film rate) vs yadif's 30fps
- The 12MB size difference between IVTC and yadif is negligible across the series (~6-7GB total)
- IVTC chosen as the final setting

### IVTC quality check
- Only ~6 warnings per 9-minute episode during `fieldmatch,decimate` — essentially all at scene cuts where the cadence briefly resets. Not visible in output.
- The encode script uses container metadata first to detect interlacing, falling back to ffprobe's `idet` filter sampling 100 frames if metadata is inconclusive

---

## DVD Structure and Authoring Quirks

### MakeMKV naming
- Files are named `[disc_label]_t[title_number].mkv` (e.g. `D7_t09.mkv`)
- Organized into per-disc subfolders named after the DVD title

### Episode structure by season
- **Seasons 1-5 (First 100 discs)**: Each 11-minute segment is its own MKV title with no chapter markers. Only the last file on each disc has chapters (2 chapters: episode + artifact).
- **Seasons 6-8**: Single files per episode, no chapter markers on most. Last file on each disc has 2 chapters with artifact appended.
- **Seasons 9-12**: Files contain 2 chapters each (~11min + ~11min). Some files on each disc have unbalanced chapters (~14-16min + ~5-9min) — these are the artifact cases.
- **Seasons 13-15**: Files contain 3 chapters each (~11min + ~11min + ~47s). The 47s Chapter 3 is real end credits — preserved intentionally.

### The authoring artifact
A blob of titlecards and credits from all episodes on the disc is authored as both:
1. A separate standalone title (the "credits reel" file — filtered out by minimum duration or left blank in CSV)
2. A chapter appended to the final episode title on each disc

The appended chapter ranges from 5-9 minutes and must be trimmed before encoding.

### Special cases identified
| File | Notes |
|------|-------|
| `S6 D2 D5_t09.mkv` | Truth or Square special — 6 chapters, ~58min total, encode in full |
| `S12 D2 B4_t03.mkv` | 4 chapters, ~43min total — normal episode content, unusual authoring |
| `S13 D4 A1_t00.mkv` | 6 chapters: 45s opener + 4 episodes + 47s credits — encode in full |
| `S14 D2 A1_t02.mkv` | 5 chapters: 4 episodes + 47s credits — encode in full |
| `First 100 D1 D6_t00.mkv` | 3 chapters: 9m | 2m 53s | 11m — middle segment is Reef Blower, needs manual handling |
| `S7 D4 F1_t14.mkv`, `G1_t15.mkv` | Special features — skip via CSV |
| `S8 D1 A1_t13.mkv` | Special feature — skip via CSV |
| `S9 D4 D6_t07.mkv` | Special feature — skip via CSV |

### Reef Blower (S01E02b)
Only ~3 minutes long — the only legitimate episode that falls below the minimum duration threshold. Needs to be encoded manually after the batch completes.

---

## Naming Convention

### Target format
`SpongeBob SquarePants - S01E01a - Help Wanted.mkv`

- Series name prepended by mnamer from TVDB lookup
- 2-digit season and episode numbers (mnamer default, sufficient for SpongeBob)
- `a`/`b` suffix for split 11-minute segments (seasons 1-5 only)
- Title from mnamer/TVmaze lookup

### mnamer configuration
- Provider: TVmaze (no API key required)
- Format: `{series} - S{season:02}E{episode:02} - {title}.{extension}`
- `recurse: false` in config — scripts invoke mnamer per-directory

---

## Pipeline Scripts

All scripts are written in Python 3. The full workflow in order:

### 1. `duration_report.py`
Scans all source MKVs, prints a duration report, and writes `rename_mapping.csv`.

**Outputs:**
- `duration_report.txt` — full report of all files grouped by directory
- `flagged_report.txt` — only flagged files for focused review
- `rename_mapping.csv` — template with `source_file` and `episode_code` columns

**Duration classifications:**
| Label | Range |
|-------|-------|
| `short?` | under 5 minutes |
| `~7min` | 5-10 minutes |
| `~11min` | 10-14 minutes |
| `~14min!` | 14-21 minutes (artifact likely) |
| `~22min` | 21-30 minutes |
| `long?` | 30+ minutes |

**Flags:**
- `~14min!` — always flagged, likely has artifact chapter appended
- `[first!]` — first file in a folder classified as `short?` or `~7min`, may be the disc's credits reel

### 2. Fill in `rename_mapping.csv`
Add episode codes (e.g. `S01E01a`) to each row. Leave blank for special features, extras, and the credits reel files — they will be skipped and logged.

### 3. `rename.py`
Renames source MKVs from MakeMKV names to bare episode codes (`S01E01.mkv`). Strips `a`/`b` suffixes before renaming and saves them to `suffix_map.json` for later restoration.

```fish
python rename.py --dry-run
python rename.py
```

### 4. mnamer
Looks up episode titles from TVmaze and renames files to the full format.

```fish
mnamer --recurse ~/SpongeBob
```

### 5. `reapply_suffixes.py`
Reads `suffix_map.json` and reinserts `a`/`b` suffixes into mnamer's output filenames. Deletes `suffix_map.json` when complete.

```fish
python reapply_suffixes.py --dry-run
python reapply_suffixes.py
```

### 6. `trim.py`
Detects and trims artifact chapters from source MKVs using stream copy (no re-encode, essentially instant). Originals are moved to `untrimmed_originals/` subfolders within each disc directory for recovery if needed.

**Detection rule:**
- Final chapter duration between 2-9 minutes AND all preceding chapters at least 10 minutes → artifact, trim it
- Real credits (~47s on S13-15) fall below the 2-minute minimum → preserved
- Any preceding chapter under 10 minutes → skip (unusual authoring, leave alone)

```fish
python trim.py ~/SpongeBob          # detect, write .trimmed.mkv files
# review trim_report.txt and spot-check .trimmed.mkv files
python trim.py ~/SpongeBob --apply  # replace originals, move to untrimmed_originals/
```

### 7. `encode.py`
Batch encodes all source MKVs to x265. No CSV dependency — files are already named correctly by this point.

```fish
python encode.py ~/SpongeBob
# optional flags:
python encode.py ~/SpongeBob --crf 20 --preset medium
```

**Features:**
- Auto interlace detection (container metadata → idet frame sampling fallback)
- Applies `fieldmatch,decimate` IVTC filter for interlaced content
- Skips files already encoded (`.x265.mkv` exists)
- Skips files under 2 minutes (extras, menu titles)
- Skips `untrimmed_originals/` folders
- Logs everything to `encode_log.txt`
- Files with no mapping entry logged to `skipped_no_mapping.txt`

### 8. `chapter_report.py` (utility)
Standalone script for inspecting chapter structure across the collection. Used during analysis to identify the artifact pattern.

```fish
python chapter_report.py ~/SpongeBob
```

---

## Estimated Scale

- ~545 source MKV files total
- Majority are 11 or 22-minute episodes
- Encode time on the weak always-on machine: ~601s per 9-minute segment
  - ~11min episode: ~12-13 minutes encode time
  - ~22min episode: ~24-26 minutes encode time
- Total estimated encode time: ~120-160 hours
- Estimated output size: ~90-130GB for the full series at CRF 18

---

## File Locations

- Source rips: `/mnt/primary/DVD RIPS/Spongebob Stuff/`
- Scripts: run from whatever directory, paths passed as arguments
- Logs written to the working directory where scripts are run:
  - `encode_log.txt`
  - `trim_report.txt`
  - `duration_report.txt`
  - `flagged_report.txt`
  - `rename_mapping.csv`
  - `suffix_map.json`
  - `skipped_no_mapping.txt`
