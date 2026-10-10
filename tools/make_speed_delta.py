"""Build TSAD1 copy/literal delta; never ship a whole modified game DLL."""
import gzip
import hashlib
import struct
from pathlib import Path


def make_delta(source: bytes, target: bytes) -> bytes:
    block = 32
    index = {}
    for pos in range(0, len(source) - block + 1, block):
        index.setdefault(source[pos:pos + block], []).append(pos)
    out = bytearray(b'TSAD1')
    literal = bytearray()

    def flush():
        if literal:
            out.extend(b'I' + struct.pack('<I', len(literal)) + literal)
            literal.clear()

    pos = 0
    while pos < len(target):
        candidates = index.get(target[pos:pos + block], ())
        best_offset = best_length = 0
        for offset in candidates[:16]:
            length = block
            while offset + length < len(source) and pos + length < len(target) and source[offset + length] == target[pos + length]:
                length += 1
            if length > best_length:
                best_offset, best_length = offset, length
        if best_length:
            flush()
            out.extend(b'C' + struct.pack('<II', best_offset, best_length))
            pos += best_length
        else:
            literal.append(target[pos])
            pos += 1
    flush()
    out.extend(b'E')
    return gzip.compress(bytes(out), mtime=0)


if __name__ == '__main__':
    import sys
    source, target, dest = map(Path, sys.argv[1:])
    original, patched = source.read_bytes(), target.read_bytes()
    assert hashlib.sha256(original).hexdigest() == '08489c29167625d19e7aa76f1b42500782ebf979fe9b840360d72a76d17c6b36'
    assert hashlib.sha256(patched).hexdigest() == 'e0a896fa66e362db4f74fe778cd15c78bb5d993bf17358f0d6f05a512ea9e597'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(make_delta(original, patched))
    print(f'{dest}: {dest.stat().st_size} bytes')
