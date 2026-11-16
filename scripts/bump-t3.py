#!/usr/bin/env python3
"""Bump the T3 Code version tracked by the chart.

Usage:
  scripts/bump-t3.py [--chart charts/t3code/Chart.yaml] [--check] <new-t3-version>

Edits Chart.yaml in place (text edits, comments preserved):
  - appVersion             -> new T3 version
  - version (chart)        -> patch bump if only the T3 patch changed,
                              minor bump if the T3 major/minor changed
  - artifacthub.io/images  -> image tag
  - artifacthub.io/changes -> one "changed" entry

Prints "<old_app> <new_app> <old_chart> <new_chart>" on success.
Exits 3 (no changes) if the new version is not newer than appVersion.
Only stable X.Y.Z versions are accepted.
"""
import argparse
import re
import sys
from pathlib import Path

SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def parse(v: str):
    m = SEMVER.match(v)
    if not m:
        raise SystemExit(f"not a stable X.Y.Z version: {v!r}")
    return tuple(int(x) for x in m.groups())


def sub_once(pattern: str, repl, text: str, what: str) -> str:
    new, n = re.subn(pattern, repl, text, count=1, flags=re.MULTILINE)
    if n != 1:
        raise SystemExit(f"could not update {what} in Chart.yaml")
    return new


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("version")
    ap.add_argument("--chart", default="charts/t3code/Chart.yaml")
    ap.add_argument("--check", action="store_true", help="only report, do not write")
    args = ap.parse_args()

    path = Path(args.chart)
    text = path.read_text()

    old_app = re.search(r'^appVersion:\s*"?([^"\s]+)"?\s*$', text, re.MULTILINE).group(1)
    old_chart = re.search(r'^version:\s*"?([^"\s]+)"?\s*$', text, re.MULTILINE).group(1)

    new_app_t, old_app_t = parse(args.version), parse(old_app)
    if new_app_t <= old_app_t:
        print(f"appVersion {old_app} is already >= {args.version}", file=sys.stderr)
        return 3

    major, minor, patch = parse(old_chart)
    if new_app_t[:2] != old_app_t[:2]:
        new_chart = f"{major}.{minor + 1}.0"
    else:
        new_chart = f"{major}.{minor}.{patch + 1}"

    if not args.check:
        text = sub_once(r'^appVersion:.*$', f'appVersion: "{args.version}"', text, "appVersion")
        text = sub_once(r'^version:.*$', f"version: {new_chart}", text, "version")
        text = sub_once(
            r"^(\s+image:\s*\S+/t3code:)\S+\s*$",
            lambda m: f"{m.group(1)}{args.version}",
            text,
            "artifacthub.io/images",
        )
        changes = (
            "  artifacthub.io/changes: |\n"
            "    - kind: changed\n"
            f"      description: Update T3 Code to {args.version}\n"
            "      links:\n"
            "        - name: T3 Code release notes\n"
            f"          url: https://github.com/pingdotgg/t3code/releases/tag/v{args.version}\n"
        )
        # Replace the whole changes block (until the next annotation key or EOF).
        text = sub_once(
            r"^  artifacthub\.io/changes: \|\n(?:    .*\n?)*",
            lambda _m: changes,
            text,
            "artifacthub.io/changes",
        )
        path.write_text(text)

    print(old_app, args.version, old_chart, new_chart)
    return 0


if __name__ == "__main__":
    sys.exit(main())
