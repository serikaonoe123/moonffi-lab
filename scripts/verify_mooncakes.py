"""Prepare and consume the actual Mooncakes ZIP; never authenticate or publish."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import zipfile

PROJECT = Path(__file__).resolve().parent.parent


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ref', default='HEAD')
    parser.add_argument('--out', required=True)
    parser.add_argument('--dependency-source', help='Explicit .mooncakes source cache; marks validation as offline.')
    args = parser.parse_args()
    out = Path(args.out).resolve()
    if out.exists() or out.is_relative_to(PROJECT):
        raise ValueError('Output must be new and outside the checkout to avoid inherited ignore rules')
    out.mkdir(parents=True)
    stage = 'export'
    env = os.environ.copy()
    (out / 'temp').mkdir()
    env['TEMP'] = env['TMP'] = str(out / 'temp')

    def run(argv, log, cwd=PROJECT):
        with (out / log).open('wb') as stream:
            result = subprocess.run(argv, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f'Exit {result.returncode}; see {out / log}')

    try:
        commit = subprocess.check_output(['git', 'rev-parse', '--verify', args.ref + '^{commit}'], cwd=PROJECT).decode().strip()
        data = subprocess.check_output(['git', '-c', 'core.autocrlf=false', '-c', 'core.eol=lf',
                                        'archive', '--format=tar', commit], cwd=PROJECT)
        source = out / 'source'
        source.mkdir()
        originals = {}
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            for item in archive:
                path = PurePosixPath(item.name)
                if path.is_absolute() or '..' in path.parts or chr(92) in item.name or ':' in item.name:
                    raise ValueError('Unsafe source path')
                if item.isdir():
                    continue
                if not item.isfile():
                    raise ValueError('Non-ordinary source file')
                content = archive.extractfile(item).read()
                originals[item.name] = content
                target = source / item.name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
        stage = 'toolchain'
        run(['pwsh', '-NoProfile', '-File', str(source / 'scripts/assert-toolchain.ps1'),
             '-Out', str(out / 'toolchain.json')], 'toolchain.log')
        stage = 'dependencies'
        if args.dependency_source:
            dependency = Path(args.dependency_source).resolve() / 'moonbitlang/async'
            assert 'version = "0.22.5"' in (dependency / 'moon.mod').read_text(encoding='utf-8')
            dest = out / 'async'
            for file in dependency.rglob('*'):
                if not file.is_file():
                    continue
                relative = file.relative_to(dependency)
                if any(x in ('_build', '.git', 'target') for x in relative.parts) or file.name == 'pkg.generated.mbti' or file.suffix in ('.exe', '.dll', '.obj', '.pdb', '.ilk', '.lib', '.o', '.a', '.mi', '.core'):
                    continue
                target = dest / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(file, target)
            (out / 'moon.work').write_text('members = ["source", "async"]\n', encoding='utf-8')
        else:
            run(['moon', '-C', str(source), 'update'], 'update.log')
            # update restores the index; an unfrozen check installs the declared dependencies.
            run(['moon', '-C', str(source), 'check', '--target', 'native', '--deny-warn'], 'dependency-check.log')
            installed = source / '.mooncakes/moonbitlang/async/moon.mod'
            assert 'version = "0.22.5"' in installed.read_text(encoding='utf-8')
        # Labelled untracked files prove the archive policy excludes generated/private-shaped inputs.
        probes = ['core/mooncakes-omit-probe.txt', 'runner/generated-probe.obj', '.credentials-probe']
        for name in probes:
            (source / name).write_text('Synthetic exclusion probe; contains no credentials.\n', encoding='utf-8')
        stage = 'package'
        run(['moon', '-C', str(source), 'package', '--frozen'], 'package.log')
        packages = list(out.rglob('serikaonoe123-moonffi-lab-0.1.0.zip'))
        assert len(packages) == 1, 'Package discovery ambiguous'
        packaged = packages[0]
        shutil.copyfile(packaged, out / 'package.zip')
        root_files = {'.moonignore', 'moon.mod', 'README.mooncakes.md', 'LICENSE'}
        expected = {name for name in originals if name in root_files or
                    (len(PurePosixPath(name).parts) == 2 and PurePosixPath(name).parts[0] in ('core', 'runner') and
                     (name.endswith('.mbt') or name.endswith('/moon.pkg') or name == 'runner/native_guard.c'))}
        assert root_files <= expected and 'runner/native_guard.c' in expected and len(expected) > 20
        harness = out / 'package-consumer-harness'
        harness.mkdir()
        manifest = []
        stage = 'archive-audit'
        with zipfile.ZipFile(out / 'package.zip') as archive:
            names = [x.filename for x in archive.infolist() if not x.is_dir()]
            assert len(names) == len(set(names)) and set(names) == expected, 'Empty, incomplete or unexpected package contents'
            for name in names:
                content = archive.read(name)
                assert content == originals[name], 'Packaged source differs from Git: ' + name
                target = harness / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
                manifest.append({'path': name, 'bytes': len(content), 'sha256': sha(content)})
        assert not (set(probes) & expected)
        (out / 'package-manifest.json').write_text(json.dumps(sorted(manifest, key=lambda x: x['path']), indent=2) + '\n', encoding='utf-8')
        # Only harness drivers/example inputs are added; the engine bytes come from the audited ZIP.
        (harness / 'scripts').mkdir()
        shutil.copyfile(source / 'scripts/verify-sdk.ps1', harness / 'scripts/verify-sdk.ps1')
        shutil.copytree(source / 'examples/adapter-starter', harness / 'examples/adapter-starter')
        stage = 'external-consumer'
        command = ['pwsh', '-NoProfile', '-File', str(harness / 'scripts/verify-sdk.ps1'), '-Out', str(out / 'sdk')]
        if args.dependency_source:
            command += ['-OfflineDependencySource', str(Path(args.dependency_source).resolve())]
        run(command, 'sdk-driver.log')
        sdk = read(out / 'sdk/verification.json')
        assert sdk['state'] == 'passed' and sdk['unit_tests'] == 7
        assert sdk['typed_ffi_parameters']['native_operations'] == 1024 and sdk['typed_ffi_parameters']['explicit_boundary_operations'] == 23
        checked = 0
        for entry in read(out / 'sdk/source-manifest.json'):
            if entry['path'].startswith('engine/'):
                name = entry['path'][7:]
                assert name in expected and entry['sha256'] == sha(originals[name])
                checked += 1
        record = {'state': 'package-and-archive-consumer-passed-not-published', 'source_commit': commit,
                  'archive_sha256': sha((out / 'package.zip').read_bytes()), 'archive_bytes': (out / 'package.zip').stat().st_size,
                  'package_files': len(expected), 'excluded_probes': probes, 'engine_inputs_matched': checked,
                  'sdk_unit_tests': 7, 'typed_ffi_operations': 1024, 'explicit_abi_boundaries': 23,
                  'dependency_mode': 'explicit-local-async-source' if args.dependency_source else 'registry-index-or-tool-cache',
                  'engine_resolution': 'Local workspace engine extracted only from the actual package ZIP',
                  'registry_installed_engine': False, 'registry_published': False, 'scope': 'Archive consumption, not registry publication or installation.'}
        (out / 'verification.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(record))
    except Exception as error:
        (out / 'failure.json').write_text(json.dumps({'state': 'failed', 'stage': stage, 'error': str(error)}, indent=2) + '\n', encoding='utf-8')
        raise


if __name__ == '__main__':
    main()
