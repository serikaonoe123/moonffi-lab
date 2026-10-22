"""Content-locked Linux toolchain installation using only Python's standard library."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import stat
import subprocess
import tarfile
import urllib.request
import zipfile


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest().upper()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def archive_path(name):
    parts = PurePosixPath(name).parts
    if not parts or name.startswith('/') or '\\' in name or ':' in name or '..' in parts:
        raise ValueError(f'Unsupported archive path: {name}')
    return Path(*parts)


def extract(archive, destination):
    """Accept only directories and regular files; validate all entries before writes."""
    archive, destination = Path(archive), Path(destination)
    seen = set()
    if archive.name.endswith('.zip'):
        with zipfile.ZipFile(archive) as bundle:
            for item in bundle.infolist():
                relative = archive_path(item.filename)
                kind = (item.external_attr >> 16) & 0o170000
                if relative in seen or kind not in (0, stat.S_IFREG, stat.S_IFDIR):
                    raise ValueError(f'Unsupported ZIP member: {item.filename}')
                seen.add(relative)
            for item in bundle.infolist():
                target = destination / archive_path(item.filename)
                if item.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with bundle.open(item) as src, target.open('xb') as dst:
                        shutil.copyfileobj(src, dst)
    else:
        with tarfile.open(archive, 'r:*') as bundle:
            for item in bundle.getmembers():
                if item.name in ('.', './') and item.isdir():
                    continue
                relative = archive_path(item.name)
                if relative in seen or not (item.isfile() or item.isdir()):
                    raise ValueError(f'Unsupported TAR member: {item.name}')
                seen.add(relative)
            for item in bundle.getmembers():
                if item.name in ('.', './') and item.isdir():
                    continue
                target = destination / archive_path(item.name)
                if item.isdir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with bundle.extractfile(item) as src, target.open('xb') as dst:
                        shutil.copyfileobj(src, dst)
                    target.chmod(item.mode & 0o777)


def source_identity(root):
    files = {p.relative_to(root).as_posix(): sha(p) for p in root.rglob('*')
             if p.is_file() and p.relative_to(root).parts[0] not in ('_build', '.mooncakes')}
    text = ''.join(f'{name}\t{files[name]}\n' for name in sorted(files))
    return {'files': len(files), 'sha256': hashlib.sha256(text.encode()).hexdigest().upper()}


def check_file_manifest(root, entries):
    for entry in entries:
        expected = entry['sha256']
        if not re.fullmatch(r'[0-9a-fA-F]{64}', expected) or sha(root / archive_path(entry['path'])) != expected.upper():
            raise ValueError(f'Source snapshot differs: {entry["path"]}')


def run(args, cwd, env, log):
    with Path(log).open('w', encoding='utf-8') as output:
        subprocess.run([str(x) for x in args], cwd=cwd, env=env, stdout=output,
                       stderr=subprocess.STDOUT, check=True, timeout=900)


def prepare_executables(root, lock):
    # Official archives store tools without executable bits. The official unix
    # installer adds them to bin/* and bin/internal/tcc after extraction.
    if {name: sha(root / 'bin' / name) for name in lock['components']} != lock['binary_sha256']:
        raise ValueError('Tool content differs; executable modes were not changed')
    records = []
    paths = [path for path in (root / 'bin').iterdir() if path.is_file()]
    if (root / 'bin/internal/tcc').is_file():
        paths.append(root / 'bin/internal/tcc')
    for path in sorted(paths):
        before = stat.S_IMODE(path.stat().st_mode)
        path.chmod(before | stat.S_IXUSR)
        records.append({'path': path.relative_to(root).as_posix(),
                        'before': oct(before), 'after': oct(stat.S_IMODE(path.stat().st_mode))})
    return records


def verify(root, lock, env, out):
    binaries = {name: sha(root / 'bin' / name) for name in lock['components']}
    if binaries != lock['binary_sha256']:
        raise ValueError('Tool binary content differs from Linux lock; no tool was executed')
    core = source_identity(root / 'lib/core')
    if core != lock['core_source_identity']:
        raise ValueError('Core source identity differs from Linux lock')
    versions = subprocess.check_output([str(root / 'bin/moon'), 'version', '--all', '--json'],
                                       env=env, text=True, timeout=30)
    actual = {item['name']: item['version'] for item in json.loads(versions)['items']}
    if actual != lock['components']:
        raise ValueError(f'Versions differ from Linux lock: {actual}')
    module = (root / 'lib/core/moon.mod').read_text(encoding='utf-8')
    if f'version = "{lock["core_version"]}"' not in module:
        raise ValueError('Core module version differs')
    report = {'state': 'passed', 'binaries': binaries, 'core': core, 'versions': actual}
    write_json(out, report)
    return report


def install(lock_path, destination, out, archive_directory=None, inspect_only=False):
    lock_path, destination, out = Path(lock_path).resolve(), Path(destination).resolve(), Path(out).resolve()
    if out.exists() or destination.exists():
        raise ValueError('Installation and evidence directories must be new')
    out.mkdir(parents=True)
    stage, accepted = 'platform', []
    try:
        if not inspect_only and (platform.system() != 'Linux' or platform.machine() != 'x86_64'):
            raise ValueError('Execution requires Linux x86_64; inspect-only verifies archive contents')
        lock = read_json(lock_path)
        if lock['bootstrap']['platform'] != 'linux-x86_64':
            raise ValueError('A Linux-specific content lock is required')
        downloads = out / 'downloads'
        downloads.mkdir()
        stage = 'archives'
        for entry in lock['bootstrap']['archives']:
            name = entry['file']
            if Path(name).name != name:
                raise ValueError('Archive file must be a basename')
            path = Path(archive_directory).resolve() / name if archive_directory else downloads / name
            if not archive_directory:
                if not entry['url'].startswith('https://cli.moonbitlang.com/'):
                    raise ValueError('Unsupported toolchain source')
                with urllib.request.urlopen(entry['url'], timeout=90) as response, path.open('xb') as output:
                    shutil.copyfileobj(response, output)
            observed = {'file': name, 'bytes': path.stat().st_size, 'sha256': sha(path)}
            write_json(out / f'{entry["kind"]}-observed.json', observed)
            if observed['bytes'] != entry['bytes'] or observed['sha256'] != entry['sha256']:
                raise ValueError(f'Locked archive content mismatch: {name}')
            accepted.append({**observed, 'path': str(path), 'kind': entry['kind']})
        # Every content pin is checked before extracting or executing anything.
        stage = 'extract'
        destination.mkdir(parents=True)
        for item in accepted:
            extract(item['path'], destination / 'lib' if item['kind'] == 'core' else destination)
        binaries = {name: sha(destination / 'bin' / name) for name in lock['components']}
        core = source_identity(destination / 'lib/core')
        if binaries != lock['binary_sha256'] or core != lock['core_source_identity']:
            raise ValueError('Extracted content differs from the lock')
        if inspect_only:
            report = {'state': 'archives-verified-not-executed', 'binaries': binaries, 'core': core}
        else:
            env = {**os.environ, 'MOON_HOME': str(destination),
                   'PATH': str(destination / 'bin') + os.pathsep + os.environ['PATH']}
            stage = 'executable-modes'
            modes = prepare_executables(destination, lock)
            write_json(out / 'executable-modes.json', modes)
            stage = 'verify-before-bundle'
            verify(destination, lock, env, out / 'before-bundle.json')
            shutil.copy2(destination / 'bin/moon', destination / 'bin/moonx')
            stage = 'bundle'
            run([destination / 'bin/moon', 'bundle', '--warn-list', '-a', '--all'],
                destination / 'lib/core', env, out / 'bundle-all.log')
            run([destination / 'bin/moon', 'bundle', '--warn-list', '-a', '--target', 'wasm-gc', '--quiet'],
                destination / 'lib/core', env, out / 'bundle-wasm-gc.log')
            stage = 'verify-after-bundle'
            report = verify(destination, lock, env, out / 'toolchain.json')
        report.update({'archives': accepted, 'lock_sha256': sha(lock_path),
                       'source_mode': 'explicit-local-archives' if archive_directory else 'official-downloads',
                       'upstream_installer_executed': False})
        write_json(out / 'verification.json', report)
        return report
    except Exception as error:
        write_json(out / 'failure.json', {'state': 'failed', 'stage': stage,
                                        'error': str(error), 'accepted_archives': accepted})
        raise


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lock', default=str(Path(__file__).resolve().parents[1] / 'toolchain-linux.json'))
    parser.add_argument('--destination', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--archive-directory')
    parser.add_argument('--inspect-only', action='store_true')
    args = parser.parse_args()
    result = install(args.lock, args.destination, args.out, args.archive_directory, args.inspect_only)
    print(json.dumps({'state': result['state'], 'evidence': args.out}))
