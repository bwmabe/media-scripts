#!/usr/bin/env python3
"""
ocr_title.py — Extract a frame and OCR it for episode title text.

Usage: ocr_title.py [-t TIMESTAMP] [FILE ...]
       With no files, processes all MKVs in the current directory.
       TIMESTAMP defaults to 00:00:47.5
"""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import cv2
import numpy as np
import pytesseract

VIDEO_EXTS = {".mkv", ".mp4", ".avi"}
DEFAULT_TIMESTAMP = "00:00:47.5"


def extract_frame(video_path: Path, timestamp: str) -> np.ndarray | None:
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        tmp_path = tmp.name

    r = subprocess.run(
        ["ffmpeg", "-ss", timestamp, "-i", str(video_path),
         "-frames:v", "1", "-y", tmp_path],
        capture_output=True,
    )
    if r.returncode != 0:
        return None

    img = cv2.imread(tmp_path)
    Path(tmp_path).unlink(missing_ok=True)
    return img


def ocr_frame(img: np.ndarray) -> str:
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    # Light threshold to pull out dark-on-light and light-on-dark text
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    text = pytesseract.image_to_string(thresh, lang="eng").strip()
    return " ".join(text.split())


def main():
    p = argparse.ArgumentParser(description="OCR episode title from a video frame")
    p.add_argument("-t", "--timestamp", default=DEFAULT_TIMESTAMP,
                   help=f"Timestamp to sample (default: {DEFAULT_TIMESTAMP})")
    p.add_argument("files", nargs="*", metavar="FILE")
    args = p.parse_args()

    if args.files:
        paths = [Path(f) for f in args.files]
    else:
        paths = sorted(p for p in Path(".").iterdir() if p.suffix.lower() in VIDEO_EXTS)

    if not paths:
        print("No video files found.", file=sys.stderr)
        sys.exit(1)

    for path in paths:
        img = extract_frame(path, args.timestamp)
        if img is None:
            print(f"{path.name}: (could not extract frame)")
            continue
        text = ocr_frame(img)
        print(f"{path.name}: {text or '(no text detected)'}")


if __name__ == "__main__":
    main()
