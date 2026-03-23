#!/usr/bin/env fish
# encode_ivtc.fish
# Encodes telecined 480i content (film-sourced cartoons) using IVTC + x265
# Recovers original 24fps progressive frames via inverse telecine
# Usage: encode_ivtc.fish [-o output_dir] <input_file|dir> [<input_file|dir> ...]
#        output_dir defaults to ./converted
#
# Examples:
#   encode_ivtc.fish episode.mkv
#   encode_ivtc.fish /path/to/season/
#   encode_ivtc.fish s01e01.mkv s01e02.mkv s01e03.mkv
#   encode_ivtc.fish -o /output/path /path/to/season/

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
    echo "Usage: encode_ivtc.fish [-o output_dir] <input_file|dir> [<input_file|dir> ...]"
    exit 1
end

mkdir -p $output_dir

function encode_file
    set infile $argv[1]
    set outdir $argv[2]
    set filename (basename $infile)
    set outfile "$outdir/$filename"

    echo "Encoding (IVTC): $filename"

    time ffmpeg -i "$infile" \
        -loglevel error \
        -vf "fieldmatch,decimate" \
        -c:v libx265 \
        -crf 18 \
        -preset medium \
        -c:a copy \
        -c:s copy \
        "$outfile" -y

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
