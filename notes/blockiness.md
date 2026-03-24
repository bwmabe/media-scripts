Yes, almost certainly. The medium preset is the culprit for what you're seeing.

Here's what's happening: CRF controls *quality target*, but the preset controls how hard the encoder works to *achieve* that target. At `medium`, x264/x265 skips a lot of analysis passes — motion estimation search range is smaller, fewer reference frames are considered, partition decisions are less thorough. The encoder hits the CRF bitrate budget but does it sloppily, which shows up as blocking in complex motion and banding in smooth gradients.

With `slow` (or `slower`), the encoder uses:

- Larger motion estimation search (me_range)
- More B-frames and reference frames
- Better rate-distortion optimization for partition decisions
- More thorough subpel refinement

The result is that the same CRF 18 produces noticeably better quality because the bits are allocated more intelligently — flat areas stay flat (less banding), and complex areas get proper motion vectors instead of falling back to blocky intra coding.

**Practical advice:**

- `slow` is usually the sweet spot — big quality jump over `medium`, encode time roughly 2-3x longer
- `slower` gives diminishing returns for another ~2x time cost
- `veryslow` is rarely worth it outside archival work
- For banding specifically, also consider adding `--deband` if you're using ffmpeg with libx265, or tune with `--bframes 8` and `--aq-mode 3`

If you're encoding with ffmpeg, just swap `-preset medium` for `-preset slow` and re-encode — CRF 18 at slow should look noticeably cleaner with no other changes needed.
