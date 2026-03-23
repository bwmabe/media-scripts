#!/usr/bin/env fish
# fix_aspect.fish
# Remuxes MKV files in place, forcing a given aspect ratio.
# Usage: fix_aspect.fish [-a aspect] [FILE ...]
#        aspect defaults to 4:3
#        with no files, processes all MKVs in the current directory

set aspect 4:3
set inputs

set i 1
while test $i -le (count $argv)
    if test $argv[$i] = -a
        set i (math $i + 1)
        set aspect $argv[$i]
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
    echo "no MKV files found" >&2
    exit 1
end

for f in $inputs
    echo "Fixing: $f"
    ffmpeg -i "$f" -map 0 -c copy -aspect $aspect "$f.tmp.mkv" -y 2>&1
    and mv "$f.tmp.mkv" "$f"
    or begin
        echo "error: failed on $f, leaving original untouched" >&2
        rm -f "$f.tmp.mkv"
    end
end
