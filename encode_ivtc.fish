#!/usr/bin/env fish
# encode_ivtc.fish
# Encodes telecined 480i content (film-sourced cartoons) using IVTC + x265
# Recovers original 24fps progressive frames via inverse telecine
# Usage: encode_ivtc.fish [-o output_dir] [-y] [--deint <filter>] [--crf <n>] [--preset <p>] <input_file|dir> [...]
#        output_dir defaults to ./converted (only applies to file inputs)
#        when a directory is passed, output goes to <dir>/converted/
#        -y: use fieldmatch,<filter>=deint=interlaced,decimate instead of fieldmatch,decimate
#            for content with irregular pulldown or residual interlace artifacts
#        --deint <filter>: use the given filter only (no IVTC) for straight interlaced content
#            common filters: yadif, bwdif, estdif, w3fdif
#        --crf <n>: x265 CRF value (default: 18, lower = better quality)
#        --preset <p>: x265 preset (default: medium, e.g. slow, veryslow)
#
# Examples:
#   encode_ivtc.fish episode.mkv
#   encode_ivtc.fish /path/to/season/
#   encode_ivtc.fish s01e01.mkv s01e02.mkv s01e03.mkv
#   encode_ivtc.fish -o /output/path episode.mkv
#   encode_ivtc.fish -y /shows/rocko/s01 /shows/rocko/s02 /shows/rocko/s03
#   encode_ivtc.fish --deint bwdif --crf 16 --preset slow /shows/something/s01

set output_dir ./converted
set inputs
set mode ivtc
set deint_filter yadif
set crf 18
set preset medium

# parse args
set i 1
while test $i -le (count $argv)
    if test $argv[$i] = -o
        set i (math $i + 1)
        set output_dir $argv[$i]
    else if test $argv[$i] = -y
        set mode ivtc_yadif
    else if test $argv[$i] = --deint
        set mode deinterlace
        set i (math $i + 1)
        set deint_filter $argv[$i]
    else if test $argv[$i] = --crf
        set i (math $i + 1)
        set crf $argv[$i]
    else if test $argv[$i] = --preset
        set i (math $i + 1)
        set preset $argv[$i]
    else
        set inputs $inputs $argv[$i]
    end
    set i (math $i + 1)
end

if test (count $inputs) -eq 0
    echo "Usage: encode_ivtc.fish [-o output_dir] [-y] [--deint <filter>] [--crf <n>] [--preset <p>] <input_file|dir> [...]"
    exit 1
end

mkdir -p $output_dir

function encode_file
    set infile $argv[1]
    set outdir $argv[2]
    set mode $argv[3]
    set deint_filter $argv[4]
    set crf $argv[5]
    set preset $argv[6]
    set filename (basename $infile)
    set outfile "$outdir/$filename"

    switch $mode
        case ivtc_yadif
            set vf_chain "fieldmatch,$deint_filter=deint=interlaced,decimate"
            echo "Encoding (IVTC+$deint_filter, crf=$crf, preset=$preset): $filename"
        case deinterlace
            if contains $deint_filter yadif bwdif
                set vf_chain "$deint_filter=mode=1"
                echo "Encoding ($deint_filter=mode=1, crf=$crf, preset=$preset): $filename"
            else
                set vf_chain "$deint_filter"
                echo "Encoding ($deint_filter, crf=$crf, preset=$preset): $filename"
            end
        case '*'
            set vf_chain "fieldmatch,decimate"
            echo "Encoding (IVTC, crf=$crf, preset=$preset): $filename"
    end

    time ffmpeg -fflags +igndts -i "$infile" \
        -loglevel error \
        -vf "$vf_chain" \
        -c:v libx265 \
        -crf $crf \
        -preset $preset \
        -c:a copy \
        -async 1 \
        -c:s copy \
        "$outfile" -y

    echo "Done: $outfile"
end

for input in $inputs
    if test -f $input
        encode_file $input $output_dir $mode $deint_filter $crf $preset
    else if test -d $input
        set dir_output "$input/converted"
        mkdir -p $dir_output
        for f in $input/*.mkv $input/*.mp4 $input/*.avi
            if test -f $f
                encode_file $f $dir_output $mode $deint_filter $crf $preset
            end
        end
    else
        echo "Skipping, not found: $input"
    end
end
