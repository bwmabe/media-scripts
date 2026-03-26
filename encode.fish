#!/usr/bin/env fish
# encode.fish
# Encodes video files with x265. Handles progressive, IVTC, deinterlace, and crop.
# Usage: encode.fish [-o dir] [--crf n] [--preset p] [--ivtc] [-y] [--deint filter] [--crop [value]] <input_file|dir> [...]
#
# By default encodes progressive content; CRF is auto-selected by resolution.
# When directories are passed, output goes to <dir>/converted/.
#
# Flags:
#   -o <dir>           Output directory for file inputs (default: ./converted)
#   --crf <n>          x265 CRF (default: auto by resolution — sub-4K=18, 4K=20)
#   --preset <p>       x265 preset (default: medium)
#   --ivtc             Inverse telecine (fieldmatch,decimate) for 24fps film in 480i
#   -y                 IVTC + yadif for irregular pulldown or residual interlace artifacts
#   --deint <filter>   Deinterlace only, no IVTC (e.g. yadif, bwdif, estdif, w3fdif)
#   --crop [value]     Auto-detect and remove letterbox/pillarbox bars; optionally supply
#                      a manual crop string e.g. crop=536:480:92:0 to skip auto-detection
#
# Examples:
#   encode.fish episode.mkv
#   encode.fish --ivtc /shows/rocko/s01 /shows/rocko/s02
#   encode.fish -y --crf 16 --preset slow episode.mkv
#   encode.fish --deint bwdif episode.mkv
#   encode.fish --crop movie.mkv
#   encode.fish --crop crop=536:480:92:0 /path/to/season/
#   encode.fish --ivtc --crop --crf 18 --preset slow episode.mkv

set output_dir ./converted
set inputs
set use_ivtc false
set ivtc_yadif false
set deint_filter ""
set use_crop false
set forced_crop ""
set crf_override ""
set preset medium

# parse args
set i 1
while test $i -le (count $argv)
    switch $argv[$i]
        case -o
            set i (math $i + 1)
            set output_dir $argv[$i]
        case --crf
            set i (math $i + 1)
            set crf_override $argv[$i]
        case --preset
            set i (math $i + 1)
            set preset $argv[$i]
        case --ivtc
            set use_ivtc true
        case -y
            set use_ivtc true
            set ivtc_yadif true
        case --deint
            set i (math $i + 1)
            set deint_filter $argv[$i]
        case --crop
            set use_crop true
            # peek at next arg: if it looks like a crop string, consume it
            set next (math $i + 1)
            if test $next -le (count $argv)
                if string match -q 'crop=*' $argv[$next]
                    set forced_crop $argv[$next]
                    set i $next
                end
            end
        case '*'
            set inputs $inputs $argv[$i]
    end
    set i (math $i + 1)
end

if test (count $inputs) -eq 0
    echo "Usage: encode.fish [-o dir] [--crf n] [--preset p] [--ivtc] [-y] [--deint filter] [--crop [value]] <input_file|dir> [...]"
    exit 1
end

function fmt_duration
    set secs (math --scale=0 "$argv[1]")
    set h (math --scale=0 "$secs / 3600")
    set m (math --scale=0 "($secs % 3600) / 60")
    set s (math --scale=0 "$secs % 60")
    printf "%02d:%02d:%02d" $h $m $s
end

function detect_crop
    set infile $argv[1]
    set crop_line (ffmpeg -ss 00:05:00 -i "$infile" \
        -t 00:01:00 \
        -vf cropdetect=limit=32:round=2:reset=0 \
        -f null - 2>&1 | grep cropdetect | tail -1)
    if test -z "$crop_line"
        set crop_line (ffmpeg -i "$infile" \
            -t 00:02:00 \
            -vf cropdetect=limit=32:round=2:reset=0 \
            -f null - 2>&1 | grep cropdetect | tail -1)
    end
    echo $crop_line | grep -oP 'crop=\d+:\d+:\d+:\d+'
end

function encode_file
    set infile $argv[1]
    set outdir $argv[2]
    set filename (basename $infile)
    set outfile "$outdir/$filename"

    # probe resolution and duration
    set height (ffprobe -v error -select_streams v:0 \
        -show_entries stream=height \
        -of default=noprint_wrappers=1:nokey=1 "$infile")
    set width (ffprobe -v error -select_streams v:0 \
        -show_entries stream=width \
        -of default=noprint_wrappers=1:nokey=1 "$infile")
    set duration_s (ffprobe -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$infile")

    # CRF and x265 params
    if test $height -ge 2000
        set crf 20
        set extra_params -x265-params "hdr10=1:hdr10-opt=1:repeat-headers=1"
    else
        set crf 18
        set extra_params -x265-params "psy-rd=1.0:psy-rdoq=0.5"
    end
    if test -n "$crf_override"
        set crf $crf_override
    end

    # build vf filter chain
    set vf_parts

    if test $use_ivtc = true
        if test $ivtc_yadif = true
            set vf_parts $vf_parts "fieldmatch,yadif=deint=interlaced,decimate"
        else
            set vf_parts $vf_parts "fieldmatch,decimate"
        end
    else if test -n "$deint_filter"
        if contains $deint_filter yadif bwdif
            set vf_parts $vf_parts "$deint_filter=mode=1"
        else
            set vf_parts $vf_parts "$deint_filter"
        end
    end

    if test $use_crop = true
        if test -n "$forced_crop"
            set vf_parts $vf_parts "$forced_crop"
            echo "  crop: using forced value $forced_crop"
        else
            echo "Detecting crop: $filename ..."
            set crop (detect_crop "$infile")
            if test -z "$crop"
                echo "  crop: none detected"
            else
                set crop_val (string replace 'crop=' '' $crop)
                set parts (string split ':' $crop_val)
                set crop_w $parts[1]
                set crop_h $parts[2]
                set crop_x $parts[3]
                set crop_y $parts[4]
                if test "$crop_w" = "$width" -a "$crop_h" = "$height"
                    echo "  crop: no bars detected, skipping"
                else
                    echo "  crop: $width x $height -> $crop_w x $crop_h (offset $crop_x, $crop_y)"
                    set vf_parts $vf_parts "$crop"
                end
            end
        end
    end

    set vf_flag
    if test (count $vf_parts) -gt 0
        set vf_flag -vf (string join ',' $vf_parts)
    end

    echo "Encoding: $filename ("$height"p, CRF $crf, $preset)"

    # set up progress fifo
    set fifo /tmp/encode_progress_(random)
    mkfifo $fifo
    set start_time (date +%s)

    ffmpeg -fflags +igndts -i "$infile" \
        -map 0 \
        -loglevel error \
        -progress $fifo \
        -nostats \
        -c:v libx265 \
        -crf $crf \
        -preset $preset \
        $extra_params \
        $vf_flag \
        -c:a copy \
        -async 1 \
        -c:s copy \
        "$outfile" -y &
    set ffmpeg_pid $last_pid
    echo $ffmpeg_pid > /tmp/encode.pid

    # parse progress from fifo
    set out_time_ms 0
    set fps "?"
    set speed "?"
    set duration_ms 0
    if string match -qr '^\d' $duration_s
        set duration_ms (math "round($duration_s * 1000)")
    end

    while read -l line
        set parts (string split -m 1 '=' -- $line)
        set key $parts[1]
        set val $parts[2]

        switch $key
            case out_time_ms
                if string match -qr '^\d' $val
                    set out_time_ms $val
                end
            case fps
                if test -n "$val" -a "$val" != "0.00"
                    set fps $val
                end
            case speed
                if test -n "$val"
                    set speed $val
                end
            case progress
                set current_s (math --scale=0 "$out_time_ms / 1000")

                if test $duration_ms -gt 0
                    set pct (math --scale=0 "$out_time_ms * 100 / $duration_ms")
                    test $pct -gt 100; and set pct 100
                    set total_s (math --scale=0 "$duration_ms / 1000")

                    set speed_num (string replace -r 'x$' '' $speed)
                    if string match -qr '^\d+\.?\d*$' $speed_num; and test (math "$speed_num > 0") = 1
                        set remaining_s (math --scale=0 "($duration_ms - $out_time_ms) / 1000 / $speed_num")
                        set eta (fmt_duration $remaining_s)
                    else
                        set eta "--:--:--"
                    end

                    printf "\r  %3d%% | %s / %s | %s fps | %s | ETA %s    " \
                        $pct (fmt_duration $current_s) (fmt_duration $total_s) $fps $speed $eta
                else
                    printf "\r  %s fps | %s    " $fps $speed
                end
        end
    end < $fifo

    wait $ffmpeg_pid
    set encode_exit $status
    rm -f $fifo /tmp/encode.pid
    printf "\n"

    set end_time (date +%s)
    set elapsed (math $end_time - $start_time)
    set elapsed_m (math --scale=0 "$elapsed / 60")
    set elapsed_s (math --scale=0 "$elapsed % 60")

    if test $encode_exit -eq 0
        echo "Done in "$elapsed_m"m "$elapsed_s"s: $filename"
    else
        echo "Failed (exit $encode_exit): $filename" >&2
    end
    echo "────────────────────────────────────────"
end

for input in $inputs
    if test -f $input
        mkdir -p $output_dir
        encode_file $input $output_dir
    else if test -d $input
        set dir_output "$input/converted"
        mkdir -p $dir_output
        for f in $input/*.mkv $input/*.mp4 $input/*.avi
            if test -f $f
                encode_file $f $dir_output
            end
        end
    else
        echo "Skipping, not found: $input"
    end
end
