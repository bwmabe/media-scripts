#!/usr/bin/env fish
# Sets up the venv and installs ocr-title to ~/.local/bin.

set dir (dirname (realpath (status filename)))

echo "==> Creating venv..."
python3 -m venv $dir/.venv
or begin
    echo "error: python3 -m venv failed" >&2
    exit 1
end

echo "==> Installing dependencies..."
$dir/.venv/bin/pip install --quiet opencv-python pytesseract numpy
or begin
    echo "error: pip install failed" >&2
    exit 1
end

chmod +x $dir/ocr-title

echo "==> Done."
echo ""
echo "Install ocr-title to ~/.local/bin? [y/N] " && read -l response
if test "$response" = y -o "$response" = Y
    mkdir -p ~/.local/bin
    ln -sf $dir/ocr-title ~/.local/bin/ocr-title
    echo "Linked: ~/.local/bin/ocr-title -> $dir/ocr-title"
    echo ""
    echo "Make sure ~/.local/bin is on your PATH:"
    echo "  fish_add_path ~/.local/bin"
else
    echo "Skipped. Run directly with: $dir/ocr-title"
end
