#!/usr/bin/env fish

# Usage: scan_interlace [FILE ...]
# With no args, scans all files in the current directory.
# Runs ffmpeg idet filter to detect interlace/telecine from actual frame content.
# Uses Multi frame detection results, which are more reliable than Single frame.

set -l files $argv
if test (count $files) -eq 0
    set files *
end

for file in $files
    if not test -f $file
        continue
    end

    set -l idet (ffmpeg -fflags +igndts -i $file -vf idet -frames:v 500 -f null - 2>&1 | grep "Multi frame" | tail -1)

    if test (count $idet) -eq 0
        echo "$file: (no video stream)"
        continue
    end

    # Parse counts from: "Multi frame detection: TFF: 123 BFF: 0 Progressive: 456 Undetermined: 7"
    set -l tff (echo "$idet" | grep -oE 'TFF:[[:space:]]*[0-9]+' | grep -oE '[0-9]+')
    set -l bff (echo "$idet" | grep -oE 'BFF:[[:space:]]*[0-9]+' | grep -oE '[0-9]+')
    set -l prog (echo "$idet" | grep -oE 'Progressive:[[:space:]]*[0-9]+' | grep -oE '[0-9]+')

    set -l interlaced (math $tff + $bff)
    set -l total (math $interlaced + $prog)

    if test $total -eq 0
        echo "$file: (undetermined)"
        continue
    end

    set -l pct (math -s0 "100 * $interlaced / $total")

    set -l label progressive
    if test $pct -ge 60
        set label interlaced
    else if test $pct -ge 15
        set label telecined
    end

    echo "$file: $label (TFF:$tff BFF:$bff Prog:$prog → $pct% interlaced)"
end
