#!/usr/bin/env fish
# encode_progressive_crop.fish
# Like encode_progressive.fish but auto-detects and removes letterbox/pillarbox bars.
# Usage: encode_progressive_crop.fish [-o output_dir] [-c crop] <input_file|dir> [<input_file|dir> ...]
#        output_dir defaults to ./converted
#        -c accepts a crop string e.g. crop=536:480:92:0 (skips auto-detection)
#
# Examples:
#   encode_progressive_crop.fish movie.mkv
#   encode_progressive_crop.fish /path/to/season/
#   encode_progressive_crop.fish -c crop=536:480:92:0 /path/to/season/
#   encode_progressive_crop.fish -o /output/path a.mkv b.mkv

set output_dir ./converted
set inputs
set forced_crop ""

# parse args
set i 1
while test $i -le (count $argv)
    if test $argv[$i] = -o
        set i (math $i + 1)
        set output_dir $argv[$i]
    else if test $argv[$i] = -c
        set i (math $i + 1)
        set forced_crop $argv[$i]
    else
        set inputs $inputs $argv[$i]
    end
    set i (math $i + 1)
end

if test (count $inputs) -eq 0
    echo "Usage: encode_progressive_crop.fish [-o output_dir] <input_file|dir> [<input_file|dir> ...]"
    exit 1
end

mkdir -p $output_dir

function detect_crop
    set infile $argv[1]

    # Sample 5 minutes in (or wherever) to avoid black intros throwing off detection.
    # cropdetect emits lines like: crop=640:480:40:0
    # Grab the last one — it stabilises over time.
    set crop_line (ffmpeg -ss 00:05:00 -i "$infile" \
        -t 00:01:00 \
        -vf cropdetect=limit=32:round=2:reset=0 \
        -f null - 2>&1 | grep cropdetect | tail -1)

    if test -z "$crop_line"
        # File shorter than seek point; retry from the start
        set crop_line (ffmpeg -i "$infile" \
            -t 00:02:00 \
            -vf cropdetect=limit=32:round=2:reset=0 \
            -f null - 2>&1 | grep cropdetect | tail -1)
    end

    # Extract just the crop=W:H:X:Y value
    echo $crop_line | grep -oP 'crop=\d+:\d+:\d+:\d+'
end

function encode_file
    set infile $argv[1]
    set outdir $argv[2]
    set filename (basename $infile)
    set outfile "$outdir/$filename"

    # detect resolution to pick CRF and HDR params
    set height (ffprobe -v error -select_streams v:0 \
        -show_entries stream=height \
        -of default=noprint_wrappers=1:nokey=1 "$infile")
    set width (ffprobe -v error -select_streams v:0 \
        -show_entries stream=width \
        -of default=noprint_wrappers=1:nokey=1 "$infile")

    if test $height -ge 2000
        set crf 22
        set extra_params -x265-params "hdr10=1:hdr10-opt=1:repeat-headers=1"
    else if test $height -ge 720
        set crf 22
        set extra_params
    else
        set crf 18
        set extra_params
    end

    # crop: use forced value if provided, otherwise auto-detect
    if test -n "$forced_crop"
        set crop $forced_crop
        echo "  crop: using forced value $crop"
    else
        echo "Detecting crop: $filename ..."
        set crop (detect_crop "$infile")
    end

    if test -z "$crop"
        echo "  crop: none detected, encoding as-is"
        set vf_filter ""
    else
        # Parse W:H:X:Y out of crop=W:H:X:Y
        set crop_val (string replace 'crop=' '' $crop)
        set parts (string split ':' $crop_val)
        set crop_w $parts[1]
        set crop_h $parts[2]
        set crop_x $parts[3]
        set crop_y $parts[4]

        # Only apply if it actually removes something
        if test "$crop_w" = "$width" -a "$crop_h" = "$height"
            echo "  crop: no bars detected ($crop_w x $crop_h), skipping crop"
            set vf_filter ""
        else
            echo "  crop: $width x $height -> $crop_w x $crop_h (offset $crop_x, $crop_y)"
            set vf_filter "-vf" "$crop"
        end
    end

    echo "Encoding: $filename (height: "$height"p, CRF: $crf)"

    time ffmpeg -i "$infile" \
	-map 0 \
        -loglevel error \
        -c:v libx265 \
        -crf $crf \
        -preset medium \
        $extra_params \
        $vf_filter \
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
