"""Keeps Korean words together when a line wraps.

Flutter breaks Korean text between any two syllables, so a word can be split across lines ("되돌려 줍니" / "다").
This puts a WORD JOINER (U+2060, invisible) between the characters of each word in app_ko.arb, so lines only break at
spaces. Run it after editing app_ko.arb; it removes the joiners first, so running it again changes nothing:

    py scripts/l10n/ko_keep_all.py
"""
import json
import re
import sys
from pathlib import Path

ARB = Path(__file__).resolve().parents[2] / 'noterly' / 'lib' / 'l10n' / 'app_ko.arb'
JOINER = '⁠'


def is_hangul(ch):
    return '가' <= ch <= '힣' or 'ᄀ' <= ch <= 'ᇿ' or '㄰' <= ch <= '㆏'


def keep_all(text):
    text = text.replace(JOINER, '')
    out = []
    for i, ch in enumerate(text):
        if i > 0:
            prev = text[i - 1]
            # Join two characters of the same word when either of them is Hangul
            if not prev.isspace() and not ch.isspace() and (is_hangul(prev) or is_hangul(ch)):
                out.append(JOINER)
        out.append(ch)
    return ''.join(out)


def main():
    data = json.loads(ARB.read_text(encoding='utf-8'))
    for key, value in data.items():
        if not key.startswith('@') and isinstance(value, str):
            data[key] = keep_all(value)
    # The joiners are written as they are (invisible), so the Korean text still reads normally in an editor
    text = json.dumps(data, ensure_ascii=False, indent=4) + '\n'
    ARB.write_text(text, encoding='utf-8', newline='\n')
    print(f'{ARB.name}: joiners added', file=sys.stderr)


if __name__ == '__main__':
    main()
