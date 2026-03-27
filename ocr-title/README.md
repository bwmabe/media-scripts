# ocr-title

OCR a single frame from video files to extract on-screen title text.

Extracts a frame at a given timestamp with ffmpeg, then runs tesseract on it. Useful for reading stylized episode title cards.

## Setup (once per machine)

```fish
cd ocr-title
./install.fish
```

Creates a venv, installs `opencv-python`, `pytesseract`, and `numpy`, and offers to symlink `ocr-title` into `~/.local/bin`.

Requires `tesseract` to be installed system-wide:

```fish
sudo apt install tesseract-ocr
```

## Usage

```
ocr-title [-t TIMESTAMP] [FILE ...]
```

- With no files, processes all MKVs in the current directory
- `TIMESTAMP` defaults to `00:00:47.5` (tuned for Rocko's Modern Life title cards)

## Output

One line per file to stdout:

```
S01E01.mkv: No Pain No Gain
S01E02.mkv: (no text detected)
```
