"""Repackage the pinned v1.0.0 delta release with reviewed scripts and extras."""
import hashlib
import shutil
import urllib.request
import zipfile
from pathlib import Path

BASE_URL = 'https://github.com/LCAR979/thesilentage-2610-patch/releases/download/v1.0.0/TheSilentAge_Chinese_2610_v1.0.0.zip'
BASE_HASH = '631586b2e85279e24beb17a87fe8af3f9574f1aa9a11fdb20cfa18f3ea41d28e'


def build(root: Path, output: Path, base_zip: Path):
    if not base_zip.exists():
        base_zip.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(BASE_URL, base_zip)
    if hashlib.sha256(base_zip.read_bytes()).hexdigest() != BASE_HASH:
        raise ValueError('Pinned base release checksum mismatch')
    output.mkdir(parents=True, exist_ok=True)
    dest = output / 'TheSilentAge_Chinese_2610_v1.1.0.zip'
    with zipfile.ZipFile(base_zip) as src, zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED) as archive:
        for item in src.infolist():
            if item.filename.endswith('.delta.gz'):
                archive.writestr(item.filename, src.read(item))
        for path in (root / 'scripts').iterdir():
            if path.is_file():
                archive.write(path, path.name)
        for path in (root / 'extras').iterdir():
            if path.is_file():
                archive.write(path, 'extras/' + path.name)
        for name in ['Tools.cmd', 'LICENSE', 'THIRD_PARTY_NOTICES.md']:
            archive.write(root / name, name)
        archive.write(root / 'docs' / '使用说明-v1.1.0.txt', '使用说明.txt')
    checksum = hashlib.sha256(dest.read_bytes()).hexdigest()
    (output / 'SHA256SUMS.txt').write_text(f'{checksum}  {dest.name}\n', encoding='utf-8')
    shutil.copyfile(root / 'docs' / '使用说明-v1.1.0.txt', output / 'ReleaseNotes-v1.1.0.txt')
    print(f'{dest}: {checksum}')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=Path('dist'))
    parser.add_argument('--base-zip', type=Path, default=Path('.cache/base-v1.0.0.zip'))
    args = parser.parse_args()
    build(Path(__file__).resolve().parents[1], args.output, args.base_zip)
