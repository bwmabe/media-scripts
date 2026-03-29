#!/usr/bin/env python3

import argparse
import os
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Rename MKV files in the current directory to S##E## format."
    )
    parser.add_argument(
        "-s", "--season",
        type=int,
        required=True,
        metavar="SEASON",
        help="Season number (required)",
    )
    parser.add_argument(
        "-e", "--first-episode",
        type=int,
        default=1,
        metavar="EPISODE",
        help="Episode number to start from (default: 1)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be renamed without actually doing it",
    )
    parser.add_argument(
        "files",
        nargs="*",
        metavar="FILE",
        help="Files to rename (default: all .mkv files in cwd, sorted)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    season: int = args.season
    first_episode: int = args.first_episode
    dry_run: bool = args.dry_run

    if season < 1:
        print("error: season must be a positive integer", file=sys.stderr)
        sys.exit(1)

    if first_episode < 1:
        print("error: first-episode must be a positive integer", file=sys.stderr)
        sys.exit(1)

    if args.files:
        mkv_files = []
        for arg in args.files:
            p = Path(arg)
            if p.is_dir():
                mkv_files.extend(sorted(p.glob("*.mkv")))
            elif p.exists():
                mkv_files.append(p)
            else:
                print(f"error: not found: {p}", file=sys.stderr)
                sys.exit(1)
    else:
        mkv_files = sorted(Path.cwd().glob("*.mkv"))

    if not mkv_files:
        print("no .mkv files found", file=sys.stderr)
        sys.exit(1)

    renames: list[tuple[Path, Path]] = []
    for i, src in enumerate(mkv_files):
        episode = first_episode + i
        new_name = f"S{season:02d}E{episode:02d}.mkv"
        dst = src.parent / new_name
        renames.append((src, dst))

    # Check for collisions before doing anything
    destinations = [dst for _, dst in renames]
    if len(destinations) != len(set(destinations)):
        print("error: renaming would produce duplicate filenames", file=sys.stderr)
        sys.exit(1)

    for src, dst in renames:
        if dry_run:
            print(f"[dry-run] {src.name} -> {dst.name}")
        else:
            if dst.exists() and dst != src:
                print(
                    f"error: target already exists, aborting: {dst.name}",
                    file=sys.stderr,
                )
                sys.exit(1)
            src.rename(dst)
            print(f"{src.name} -> {dst.name}")


if __name__ == "__main__":
    main()
