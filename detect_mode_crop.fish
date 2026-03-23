#!/usr/bin/env fish
# detect_mode_crop.fish
# Samples every video file in a directory, detects crop values, and reports the mode.
# Usage: detect_mode_crop.fish [directory]
#        directory defaults to current directory

set target_dir .
if test (count $argv) -ge 1
    set target_dir $argv[1]
end

if not test -d $target_dir
    echo "error: not a directory: $target_dir" >&2
    exit 1
end

set files
for f in $target_dir/*.mkv $target_dir/*.mp4 $target_dir/*.avi
    if test -f $f
        set files $files $f
    end
end

if test (count $files) -eq 0
    echo "error: no video files found in $target_dir" >&2
    exit 1
end

echo "Sampling "(count $files)" file(s)..."

set all_crops

for f in $files
    set filename (basename $f)

    # Try 5 minutes in first
    set crop_line (ffmpeg -ss 00:05:00 -i "$f" \
        -t 00:01:00 \
        -vf cropdetect=limit=32:round=2:reset=0 \
        -f null - 2>&1 | grep cropdetect | tail -1)

    if test -z "$crop_line"
        # Fall back to sampling from the start
        set crop_line (ffmpeg -i "$f" \
            -t 00:02:00 \
            -vf cropdetect=limit=32:round=2:reset=0 \
            -f null - 2>&1 | grep cropdetect | tail -1)
    end

    set crop (echo $crop_line | grep -oP 'crop=\d+:\d+:\d+:\d+')

    if test -z "$crop"
        echo "  $filename: no crop detected"
    else
        echo "  $filename: $crop"
        set all_crops $all_crops $crop
    end
end

if test (count $all_crops) -eq 0
    echo "error: no crop values detected across any file" >&2
    exit 1
end

echo ""
echo "Results:"

# Count occurrences of each unique crop value and find the mode.
# Print a sorted summary then emit the winner.
set unique_crops (printf '%s\n' $all_crops | sort -u)

set mode_crop ""
set mode_count 0

for crop in $unique_crops
    set count (printf '%s\n' $all_crops | grep -cF $crop)
    echo "  $count x $crop"
    if test $count -gt $mode_count
        set mode_count $count
        set mode_crop $crop
    end
end

echo ""
echo "Mode crop ($mode_count/"(count $all_crops)" files): $mode_crop"
