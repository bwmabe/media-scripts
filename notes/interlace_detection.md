# Interlace Detection

## Container metadata is unreliable

The `field_order` flag in container metadata (read by `ffprobe` or `scan_field_order.fish`) reflects
what the encoder wrote — it can be wrong. Content flagged as `progressive` may still have interlace
artifacts baked in.

## Use idet for content-based detection

```sh
ffmpeg -fflags +igndts -i input.mkv -vf idet -f null - 2>&1 | grep idet
```

`-fflags +igndts` suppresses errors from files with broken/non-monotonic timestamps.

Look at the **Multi frame detection** row — it's more reliable than Single frame detection.

Example output:
```
[Parsed_idet_0 @ ...] Multi frame detection: TFF:  7610 BFF:   172 Progressive: 26139 Undetermined: 24
```

## Interpreting results

- **TFF/BFF dominate** → interlaced
- **Progressive dominates with some TFF/BFF** → likely telecined (3:2 pulldown)
- **Progressive dominates heavily** → probably genuinely progressive

For telecined content, roughly 40% of frames may register as interlaced (the pulldown fields),
though idet will undercount on animation with many held frames. Even 20-25% TFF with fast-motion
combing visible on playback is a strong indicator of telecine.

Interlace artifacts are **only visible during fast motion** — static and slow scenes look fine
because the two fields are nearly identical. This is expected behavior, not evidence of progressive.

## Telecine vs. straight interlaced

The fix differs depending on source type:

| Type | Source | Fix |
|---|---|---|
| Telecined (3:2 pulldown) | Film-sourced, 24fps origin | `fieldmatch,decimate` (IVTC) → recovers 24fps |
| Straight interlaced | Video-sourced, native 29.97i | `yadif` deinterlace → stays at ~29.97fps |

US animation from DVD/broadcast is almost always telecined. If the original framerate was 24fps,
assume telecine.

A small number of BFF frames alongside predominantly TFF (or vice versa) is normal — can come from
scene transitions, mixed source segments, or idet misreads around cuts.

## Scan multiple files

To run idet across many files and suppress console noise:

```sh
ffmpeg -fflags +igndts -i input.mkv -vf idet -f null - 2>&1 | grep idet
```
