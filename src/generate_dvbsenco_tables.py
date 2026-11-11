#!/usr/bin/env python3
"""Copy the legacy ARM32 encoder's constant tables into a C include.

The ARM32 assembly remains the source of truth for the portable encoder.
"""

import re
import sys
from pathlib import Path


def main(source: Path, destination: Path) -> None:
    assembly = source.read_text()
    sections = (('energytable', 1504), ('reed1table', 256), ('reed2table', 4096))
    lines = ['/* Generated from dvbsenco8.s; do not edit by hand. */']
    for name, expected in sections:
        section = assembly.split(f'{name}:', 1)[1].split('\n\n', 1)[0]
        values = [int(value, 16) for value in re.findall(r'0x[0-9a-fA-F]+', section)]
        if len(values) != expected or any(value > 255 for value in values):
            raise ValueError(f'{name}: expected {expected} bytes, found {len(values)}')
        lines.append(f'static const unsigned char {name}[{expected}] = {{')
        for offset in range(0, expected, 16):
            lines.append('    ' + ', '.join(f'0x{value:02x}' for value in values[offset:offset + 16]) + ',')
        lines.append('};')
    destination.write_text('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main(Path(sys.argv[1]), Path(sys.argv[2]))
