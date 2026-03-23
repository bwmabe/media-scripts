#!/usr/bin/env fish

for f in *.mkv
	ffmpeg -ss 00:00:47.5 -i $f -frames:v 1 $f.png
end

