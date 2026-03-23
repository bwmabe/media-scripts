# ffmpeg Field Order Values

| Value | Meaning |
|---|---|
| `progressive` | Progressive (not interlaced) |
| `tt` | Top field first |
| `bb` | Bottom field first |
| `tb` | Top field first, bottom field repeated |
| `bt` | Bottom field first, top field repeated |

For NTSC 480i content, `tt` or `bb` is typical. `fieldmatch,decimate` handles both field orders.

## Verifying `bb` metadata

Sometimes the field order metadata is wrong while the actual video is progressive. To check:

```
ffmpeg -i file.mkv -vf idet -frames:v 200 -f null - 2>&1 | grep "Multi frame"
```

If it reports mostly progressive frames, the `bb` flag is just bad metadata.
