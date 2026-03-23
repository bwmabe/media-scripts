#!/usr/bin/env fish

# Usage: scan_field_order [FILE ...]
# With no args, scans all files in the current directory.

set -l files $argv
if test (count $files) -eq 0
    set files *
end

for file in $files
    if not test -f $file
        continue
    end

    set -l scan (ffprobe -v error \
        -select_streams v:0 \
        -show_entries stream=field_order \
        -of default=noprint_wrappers=1:nokey=1 \
        $file 2>/dev/null)

    if test (count $scan) -eq 0
        set scan "(no video stream)"
    end

    echo "$file: $scan"
end
