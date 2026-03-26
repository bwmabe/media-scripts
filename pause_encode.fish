#!/usr/bin/env fish
# pause_encode.fish
# Pauses a running encode.fish job.

if not test -f /tmp/encode.pid
    echo "No active encode found (no /tmp/encode.pid)" >&2
    exit 1
end

set pid (cat /tmp/encode.pid)

if not kill -0 $pid 2>/dev/null
    echo "Process $pid not found — encode may have finished" >&2
    rm -f /tmp/encode.pid
    exit 1
end

kill -STOP $pid
echo "Paused (PID $pid)"
