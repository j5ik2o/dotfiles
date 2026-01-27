#!/usr/bin/env python3
"""
Remove markdown code blocks and leading/trailing empty lines from commit messages.
"""
import sys

content = sys.stdin.read()
# Remove ``` lines
lines = [l for l in content.split('\n') if not l.strip().startswith('```')]
# Remove leading and trailing empty lines
while lines and not lines[0].strip():
    lines.pop(0)
while lines and not lines[-1].strip():
    lines.pop()
print('\n'.join(lines))
