# Video Encoding Notes

## Context

Converting a personal video library to x265/HEVC for size reduction. Playback target is iPad 6th gen (A10 chip, supports HEVC hardware decode, does not support AV1 or Dolby Vision).

---

## Why the Original 4K Encode Took 67 Hours

- `libx265` with `preset slow` is extremely CPU-intensive
- quad-core i5 @ 3GHz does not scale well with x265
- Source and output on HDD added I/O latency
- CRF 18 with `slow` preset forces the encoder to work very hard
- Space in `-x265-params` string (`"hdr10=1:hdr10-opt=1: repeat-headers=1"`) caused silent param parsing failure

---

## Codec Decisions

### Why Not AV1 (SVT-AV1)

AV1 would be faster and produce better compression, but iPad 6th gen (A10, 2018) has no AV1 hardware decoder. Playback would require software decoding, likely resulting in dropped frames or refusal to play. AV1 hardware decode was introduced in Apple silicon with the A14 (2020).

### Why Not GPU Encoding (hevc_qsv / hevc_nvenc)

Intel Quick Sync is available on the 2017 i5 but 7th-gen Quick Sync has a noticeable quality gap vs software x265, particularly in shadow detail, fine texture, and dark gradients. Acceptable for casual use but not ideal for archival. Not used.

### Final Codec: libx265, preset medium

`preset medium` vs `slow` produces nearly identical file sizes at the same CRF (2-5% difference at most) because CRF is a quality target, not a bitrate target. Switching from `slow` to `medium` reduces encode time significantly with no meaningful quality loss.

---

## HDR Notes

Source 4K content contains Dolby Vision Profile 7.6 (BL+EL+RPU) over an HDR10 base layer. x265 cannot encode Dolby Vision - the enhancement layer and RPU metadata are dropped. The HDR10 base layer is preserved correctly via `-x265-params "hdr10=1:hdr10-opt=1:repeat-headers=1"`.

Since the playback target (iPad 6th gen) does not support Dolby Vision, the dropped DV metadata is irrelevant.

VMAF scoring on HDR content is less reliable than SDR - VMAF was designed for SDR and HDR scores should be treated as directional rather than absolute.

---

## Source Types and Filters

### 1080p Blu-ray (progressive)
No filter needed. Straight encode.

### 480p DVD (progressive)
No filter needed. Straight encode.

### 480i DVD (telecined film content - 90s/early 2000s cartoons)
Use IVTC (Inverse Telecine) via `fieldmatch,decimate`. This recovers the original 24fps progressive frames from 3:2 pulldown. Do not use `yadif` deinterlacing for film-sourced content as it interpolates rather than reconstructs.

Output is 23.976fps progressive.

### Detecting Interlacing

```fish
ffprobe -v error -select_streams v:0 \
  -show_entries stream=field_order \
  -of default=noprint_wrappers=1:nokey=1 "$file"
```

Returns `progressive`, `tt`, `bb`, or `unknown`. For `unknown`, use idet:

```fish
ffmpeg -i "$file" \
  -vf idet \
  -frames:v 500 \
  -an -f null - 2>&1 | grep "Multi frame detection"
```

### Telecine vs Genuine Interlace

`field_order` alone cannot distinguish them. Visual check is most reliable:
- Telecined: clean frames alternating with combed frames in a regular pattern (~every 4th-5th frame combed)
- Genuine interlace: combing on every frame with motion

For 90s/early 2000s US broadcast animation, assume telecine unless known otherwise.

### Mixed Sources

Some DVDs contain a mix of telecined and progressive content (e.g. shows that switched from film to digital production mid-run). Strategy: manually split by season based on known production history. Per-episode or per-frame detection adds complexity with limited benefit.

---

## VMAF Testing Methodology

VMAF measures perceptual quality against a reference source. Scores above 93-95 are considered transparent (indistinguishable from source). Used to validate CRF settings before committing to full batch encodes.

### Test clip extraction (no re-encode)

```fish
ffmpeg -i "source.mkv" -ss 48:00 -to 51:00 -c copy "test_clip.mkv"
```

Pick a clip with complex content: fast motion, film grain, dark scenes. Avoid credits or slow scenes.

### Running VMAF

```fish
ffmpeg -i "encode.mkv" -i "source.mkv" \
  -lavfi libvmaf \
  -f null - 2>&1 | grep VMAF
```

Note: requires ffmpeg built with libvmaf. The yt-dlp static ffmpeg build includes it.

---

## CRF Test Results

### 4K HDR (Blu-ray, x264 source, 3 min clip)

| CRF | VMAF | Size |
|-----|------|------|
| 18 | 97.5 | 346MB |
| 20 | 96.9 | 254MB |
| 22 | 96.2 | 199MB |
| 24 | 95.2 | 167MB |

### 1080p BD (x264 source, 3 min clip)

| CRF | VMAF | Size | Time |
|-----|------|------|------|
| 18 | 97.49 | 202MB | 294s |
| 20 | 96.38 | 162MB | 249s |
| 22 | 94.87 | 133MB | 209s |
| 24 | 92.93 | 101MB | 172s |

CRF 24 is below the transparency threshold for 1080p. CRF 22 is at the edge.

### 480p DVD (progressive, 3 min clip)

| CRF | VMAF | Size |
|-----|------|------|
| 18 | 92.6 | 247MB |

VMAF is below threshold but visually identical to source. Low source quality ceiling means VMAF is less meaningful here - trust eyes over number.

---

## Final CRF Settings

| Resolution | CRF | Notes |
|------------|-----|-------|
| 4K HDR | 22 | well above threshold, 3.75x reduction |
| 1080p BD | 20 | CRF 22 shows color blocking and crushed blacks on live action |
| 480p DVD | 18 | VMAF unreliable at this resolution, visually clean |
| 480i telecined | 18 | same as 480p, IVTC filter applied |

Note: CRF 22 works for animated 1080p content but live action requires CRF 20 or lower due to sensitivity of skin tones and shadow detail. Further testing at CRF 16-18 with psy-rd adjustment ongoing.

### psy-rd

x265 default `psy-rd=2.0` causes crushed blacks and color blocking in live action content. Reducing to `psy-rd=1.0:psy-rdoq=0.5` improves shadow detail. Testing ongoing to find the right CRF + psy-rd combination for live action 1080p under 10GB per film target.

Full film size at CRF 20 (1080p live action): ~4.5GB. Target is under 10GB.

---

## x265 Parameter Notes

- No spaces between parameters in `-x265-params` string - spaces cause silent parsing failure
- `hdr10-opt` was silently disabled due to space bug in original command
- `log-level=0` in x265-params silences x265 internal logging
- Filter NAL unit 63 warnings (from dropped Dolby Vision data): `2>&1 | grep -v "nal_unit_type: 63"`
- Do not force `-pix_fmt yuv420p10le` on 8-bit sources - padding to 10-bit adds no quality
- `pools=N` pins x265 thread count explicitly to core count

---

## Encode Script

Single script: `encode.fish`. Replaces the old `encode_progressive.fish`, `encode_ivtc.fish`, and `encode_progressive_crop.fish`.

Accepts `-o output_dir` (default: `./converted`), file and directory inputs. Directories output to `<dir>/converted/`. CRF auto-selected by resolution (sub-4K=18, 4K=20), overridable with `--crf`. Preset defaults to `medium`, overridable with `--preset`. IVTC, deinterlace, and crop are flags that can be freely combined.

```fish
encode.fish movie.mkv
encode.fish --ivtc /shows/rocko/s01 /shows/rocko/s02
encode.fish --ivtc --crop crop=536:480:92:0 --preset slow .
encode.fish --deint bwdif --crf 16 episode.mkv
encode.fish --crop movie.mkv
```

---

## Miscellaneous

- HDD I/O is a meaningful bottleneck for 4K encodes. Copying source to `/tmp` or `/dev/shm` before encoding can save 20-30% encode time.
- IVTC output files are larger than equivalent progressive encodes (~100MB per episode) due to field reconstruction artifacts that x265 treats as detail to preserve. A temporal denoise filter `hqdn3d=0:0:3:3` after decimate can reduce this.
- Some 90s/early 2000s cartoons have CGI elements composited at the video stage. `fieldmatch` handles this reasonably well on a per-frame basis but occasional artifacts on CGI-heavy sequences are possible.
- Animation compresses much better than live action at the same CRF due to flat colors and simple motion. CRF settings tuned for live action will produce oversized files for animation.
