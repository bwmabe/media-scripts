#!/usr/bin/env fish
# encode_progressive.fish
# Encodes progressive video content (480p, 1080p, 4K) using x265
# Usage: encode_progressive.fish [-o output_dir] <input_file|dir> [<input_file|dir> ...]
#        output_dir defaults to ./converted
#
# Examples:
#   encode_progressive.fish movie.mkv
#   encode_progressive.fish /path/to/season/
#   encode_progressive.fish a.mkv b.mkv c.mkv
#   encode_progressive.fish -o /output/path a.mkv b.mkv

set output_dir ./converted
set inputs

# parse args
set i 1
while test $i -le (count $argv)
    if test $argv[$i] = -o
        set i (math $i + 1)
        set output_dir $argv[$i]
    else
        set inputs $inputs $argv[$i]
    end
    set i (math $i + 1)
end

if test (count $inputs) -eq 0
    echo "Usage: encode_progressive.fish [-o output_dir] <input_file|dir> [<input_file|dir> ...]"
    exit 1
end

mkdir -p $output_dir

function encode_file
    set infile $argv[1]
    set outdir $argv[2]
    set filename (basename $infile)
    set outfile "$outdir/$filename"

    # detect resolution to pick CRF and HDR params
    set height (ffprobe -v error -select_streams v:0 \
        -show_entries stream=height \
        -of default=noprint_wrappers=1:nokey=1 "$infile")

    if test $height -ge 2000
        # 4K HDR
        set crf 16
        set extra_params -x265-params "hdr10=1:hdr10-opt=1:repeat-headers=1"
    else if test $height -ge 720
	set crf 8
	set extra_params -x265-params "psy-rd=1.0:psy-rdoq=0.5"
    else
        # 480p
        set crf 16
	set extra_params -x265-params "psy-rd=1.0:psy-rdoq=0.5"
    end

    echo "Encoding: $filename (height: "$height"p, CRF: $crf)"

    time ffmpeg -i "$infile" \
        -loglevel error \
        -c:v libx265 \
        -crf $crf \
        -preset medium \
        $extra_params \
        -c:a copy \
        -c:s copy \
        "$outfile" -y 2>&1 | grep -v "nal_unit_type: 63"

    echo "Done: $outfile"
end

for input in $inputs
    if test -f $input
        encode_file $input $output_dir
    else if test -d $input
        for f in $input/*.mkv $input/*.mp4 $input/*.avi
            if test -f $f
                encode_file $f $output_dir
            end
        end
    else
        echo "Skipping, not found: $input"
    end
end
