#!/usr/bin/env fish
# encode_ivtc.fish
# Encodes telecined 480i content (film-sourced cartoons) using IVTC + x265
# Recovers original 24fps progressive frames via inverse telecine
# Usage: encode_ivtc.fish [-o output_dir] [-y] <input_file|dir> [<input_file|dir> ...]
#        output_dir defaults to ./converted (only applies to file inputs)
#        when a directory is passed, output goes to <dir>/converted/
#        -y: use fieldmatch,yadif,decimate instead of fieldmatch,decimate
#            for content with irregular pulldown or residual interlace artifacts
#
# Examples:
#   encode_ivtc.fish episode.mkv
#   encode_ivtc.fish /path/to/season/
#   encode_ivtc.fish s01e01.mkv s01e02.mkv s01e03.mkv
#   encode_ivtc.fish -o /output/path episode.mkv
#   encode_ivtc.fish -y /shows/rocko/s01 /shows/rocko/s02 /shows/rocko/s03

set output_dir ./converted
set inputs
set use_yadif 0

# parse args
set i 1
while test $i -le (count $argv)
    if test $argv[$i] = -o
        set i (math $i + 1)
        set output_dir $argv[$i]
    else if test $argv[$i] = -y
        set use_yadif 1
    else
        set inputs $inputs $argv[$i]
    end
    set i (math $i + 1)
end

if test (count $inputs) -eq 0
    echo "Usage: encode_ivtc.fish [-o output_dir] [-y] <input_file|dir> [<input_file|dir> ...]"
    exit 1
end

mkdir -p $output_dir

function encode_file
    set infile $argv[1]
    set outdir $argv[2]
    set yadif $argv[3]
    set filename (basename $infile)
    set outfile "$outdir/$filename"

    if test $yadif -eq 1
        set vf_chain "fieldmatch,yadif=deint=interlaced,decimate"
        echo "Encoding (IVTC+yadif): $filename"
    else
        set vf_chain "fieldmatch,decimate"
        echo "Encoding (IVTC): $filename"
    end

    time ffmpeg -fflags +igndts -i "$infile" \
        -loglevel error \
        -vf "$vf_chain" \
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
        encode_file $input $output_dir $use_yadif
    else if test -d $input
        set dir_output "$input/converted"
        mkdir -p $dir_output
        for f in $input/*.mkv $input/*.mp4 $input/*.avi
            if test -f $f
                encode_file $f $dir_output $use_yadif
            end
        end
    else
        echo "Skipping, not found: $input"
    end
end
