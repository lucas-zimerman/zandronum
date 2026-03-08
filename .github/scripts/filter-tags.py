#!/usr/bin/env python3
"""
Filter out problematic tags from hg-fast-export output.

Some ST_* tags (0.97d-beta4.2 onwards) point to commits on unnamed Mercurial heads
that don't get converted. This script removes those tag commands from the
fast-import stream before git processes them.

Usage:
    hg-fast-export.py ... | python3 filter-tags.py | git fast-import ...
"""
import sys
import re

# Tags pointing to commits on unnamed heads (won't exist after conversion)
# These are ST_* tags from hg r7350 onwards that are on an orphaned branch
SKIP_TAGS = [
    'ST_0.97d-beta4.2',
    'ST_0.97d-beta4.3',
    'ST_0.97d-RC9',
    'ST_0.97d-RC10',
    'ST_0.97d',
    'ST_0.97d2-RC2',
    'ST_0.97d2-RC3',
    'ST_0.97d2-RC6',
    'ST_0.97d2',
    'ST_0.97d3-RC1',
    'ST_0.97d3-RC2',
    'ST_0.97d3',
    'ST_0.97d3-security-update-1',
    'ST_0.97d4',
    'ST_0.97d5',
    'ST_0.97d5-security-update-1',
]


def filter_tags(content: str) -> str:
    """Remove tag commands for problematic tags from fast-import stream."""
    for tag in SKIP_TAGS:
        # Match: tag <name>\nfrom <ref>\ntagger ...\ndata <n>\n<content of n bytes or empty>
        pattern = rf'tag {re.escape(tag)}\nfrom [^\n]+\ntagger [^\n]+\ndata (\d+)\n'
        match = re.search(pattern, content)
        while match:
            data_len = int(match.group(1))
            # Remove the tag command including its data content
            start = match.start()
            end = match.end() + data_len
            content = content[:start] + content[end:]
            match = re.search(pattern, content)
    return content


def main():
    content = sys.stdin.buffer.read().decode('utf-8', errors='replace')
    filtered = filter_tags(content)
    sys.stdout.buffer.write(filtered.encode('utf-8'))


if __name__ == '__main__':
    main()
