#!/usr/bin/env fish
# extract_frame.fish
# Extracts a single frame from video files as a PNG.
# Usage: extract_frame.fish [-t timestamp] [FILE ...]
#        timestamp defaults to 00:00:30
#        with no files, processes all MKVs in the current directory

set timestamp 00:00:30
set inputs

set i 1
while test $i -le (count $argv)
    if test $argv[$i] = -t
        set i (math $i + 1)
        set timestamp $argv[$i]
    else
        set inputs $inputs $argv[$i]
    end
    set i (math $i + 1)
end

if test (count $inputs) -eq 0
    for f in *.mkv
        if test -f $f
            set inputs $inputs $f
        end
    end
end

if test (count $inputs) -eq 0
    echo "no files specified and no MKV files found in current directory" >&2
    exit 1
end

for f in $inputs
    ffmpeg -ss $timestamp -i $f -frames:v 1 $f.png
end
