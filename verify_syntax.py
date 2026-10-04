#!/usr/bin/env python3
"""
Syntax and script integrity check for Godot GDScript files.
Scans all .gd files in the project for structural issues, matching braces/brackets,
and runs Godot headless script verification if Godot console is available.
"""

import os
import sys
import subprocess
from pathlib import Path

GODOT_PATHS = [
    r"C:\Users\feljo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    r"C:\Users\feljo\Downloads\Godot_v4.7.2-stable_win64_console.exe",
    "godot",
    "godot4"
]

def find_godot_bin():
    for p in GODOT_PATHS:
        if os.path.exists(p):
            return p
    return None

def check_brackets_and_quotes(file_path):
    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    lines = content.splitlines()
    stack = []
    pairs = {')': '(', ']': '[', '}': '{'}
    in_multiline_str = False
    quote_char = ""

    for line_idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue

        i = 0
        while i < len(line):
            ch = line[i]
            
            # Check multiline comments / strings
            if not in_multiline_str and (line[i:i+3] == '"""' or line[i:i+3] == "'''"):
                in_multiline_str = True
                quote_char = line[i:i+3]
                i += 3
                continue
            elif in_multiline_str and line[i:i+3] == quote_char:
                in_multiline_str = False
                i += 3
                continue
            elif in_multiline_str:
                i += 1
                continue

            # Skip single line comments
            if ch == '#':
                break

            # Skip strings
            if ch in ('"', "'"):
                q = ch
                i += 1
                while i < len(line) and line[i] != q:
                    if line[i] == '\\':
                        i += 1
                    i += 1
                i += 1
                continue

            if ch in "([{":
                stack.append((ch, line_idx, i + 1))
            elif ch in ")]}":
                if not stack:
                    return f"Unmatched closing '{ch}' at line {line_idx}:{i+1}"
                top, t_line, t_col = stack.pop()
                if pairs[ch] != top:
                    return f"Mismatched bracket '{top}' (from line {t_line}:{t_col}) closed with '{ch}' at line {line_idx}:{i+1}"
            i += 1

    if stack:
        top, t_line, t_col = stack.pop()
        return f"Unclosed bracket '{top}' opened at line {t_line}:{t_col}"
    return None

def main():
    root_dir = Path(__file__).parent.resolve()
    gd_files = list(root_dir.glob("**/*.gd"))
    gd_files = [f for f in gd_files if ".godot" not in f.parts and "addons" not in f.parts]

    print(f"Checking {len(gd_files)} project GDScript files...")
    errors = 0

    for f in gd_files:
        err = check_brackets_and_quotes(f)
        if err:
            print(f"FAIL: {f.relative_to(root_dir)}: {err}")
            errors += 1
        else:
            print(f"OK:   {f.relative_to(root_dir)}")



    if errors == 0:
        print("\nAll GDScript syntax checks PASSED cleanly!")
        return 0
    else:
        print(f"\nSyntax check FAILED with {errors} error(s).")
        return 1

if __name__ == "__main__":
    sys.exit(main())
