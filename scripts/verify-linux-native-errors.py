"""Fixed-commit Linux validation of owned native fault reduction fixtures."""
import argparse
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess

from linux_toolchain import extract, read_json, run, sha, verify, write_json
from importlib.util import spec_from_file_location, module_from_spec

spec = spec_from_file_location('ordinary', Path(__file__).with_name('verify-linux.py'))
ordinary = module_from_spec(spec)
spec.loader.exec_module(ordinary)


def require(value, message):
    if not value:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True)
    parser.add_argument('--toolchain', required=True)
    parser.add_argument('--ref', default='HEAD')
    parser.add_argument('--dependency-source', required=True,
                        help='Prepared moonbitlang/async source directory, not a registry cache')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    out, toolchain = Path(args.out).resolve(), Path(args.toolchain).resolve()
    dependency = Path(args.dependency_source).resolve()
    require(not out.exists(), 'Output must be new')
    out.mkdir(parents=True)
    stage = 'platform'
    try:
        require(platform.system() == 'Linux' and platform.machine() == 'x86_64', 'Linux x86_64 required')
        env = {**os.environ, 'MOON_HOME': str(toolchain),
               'PATH': str(toolchain / 'bin') + os.pathsep + os.environ['PATH'],
               'ASAN_OPTIONS': 'halt_on_error=1:abort_on_error=1'}
        lock = read_json(project / 'toolchain-linux.json')
        verify(toolchain, lock, env, out / 'toolchain.json')
        require(re.search(r'^version\s*=\s*"' + re.escape(lock['async_version']) + r'"\s*$',
                          (dependency / 'moon.mod').read_text(), re.M), 'async version mismatch')
        run(['gcc', '--version'], project, env, out / 'gcc-version.log')
        run(['ldd', '--version'], project, env, out / 'libc-version.log')
        commit = subprocess.check_output(['git', 'rev-parse', '--verify', args.ref + '^{commit}'],
                                         cwd=project, text=True).strip()
        stage = 'export'
        run(['git', 'archive', '--format=tar', f'--output={out / "source.tar"}', commit],
            project, env, out / 'archive.log')
        exported = out / 'exported'
        exported.mkdir()
        extract(out / 'source.tar', exported)
        write_json(out / 'source-manifest.json', ordinary.manifest(exported))
        profiles = []
        for mode in ('crash', 'asan'):
            stage = f'prepare/{mode}'
            profile = out / mode
            workspace = profile / 'workspace'
            workspace.mkdir(parents=True)
            for name in ('core', 'runner', 'cmd/native-errors', 'fixtures/native-errors'):
                ordinary.copy_source(exported / name, workspace / name)
            shutil.copy2(exported / 'moon.mod', workspace / 'moon.mod')
            async_root = workspace / '.mooncakes/moonbitlang/async'
            ordinary.copy_source(dependency, async_root)
            (workspace / 'moon.work').write_text('members = [".", ".mooncakes/moonbitlang/async"]\n')
            adaptations = []
            if mode == 'asan':
                for relative, old, new in (
                    ('fixtures/native-errors/moon.pkg', 'options("native-stub": ["faults.c"])',
                     'options("native-stub": ["faults.c"], link: { "native": { '
                     '"stub-cc-flags": "-fsanitize=address -fno-omit-frame-pointer -g", }, })'),
                    ('cmd/native-errors/moon.pkg', 'options("is-main": true)',
                     'options("is-main": true, link: { "native": { '
                     '"cc-link-flags": "-fsanitize=address", }, })')):
                    path = workspace / relative
                    text, before = path.read_text(), sha(path)
                    require(old in text, f'Unexpected compiler configuration: {relative}')
                    path.write_text(text.replace(old, new))
                    adaptations.append({'path': relative, 'before_sha256': before, 'after_sha256': sha(path)})
            before = ordinary.manifest(workspace)
            dependencies = ordinary.manifest(async_root)
            write_json(profile / 'source-manifest.json', before)
            write_json(profile / 'dependency-manifest.json', dependencies)
            write_json(profile / 'compiler-profile.json', adaptations)
            stage = f'build/{mode}'
            run(['moon', 'tree', '--json'], workspace, env, profile / 'module-tree.json')
            modules = read_json(profile / 'module-tree.json')['modules']
            resolved = [m for m in modules if m['name'] == 'moonbitlang/async']
            require(len(resolved) == 1 and resolved[0]['source']['kind'] == 'local'
                    and resolved[0]['source']['path'] == str(async_root), 'async local resolution mismatch')
            if mode == 'crash':
                run(['moon', 'check', '--target', 'native', '--deny-warn', '--frozen'],
                    workspace, env, profile / 'check.log')
                run(['moon', 'test', '--target', 'native', '--deny-warn', '--frozen', '-j', '1',
                     '--package', 'serikaonoe123/moonffi-lab'],
                    workspace, env, profile / 'tests.log')
                require('Total tests: 49, passed: 49, failed: 0.' in (profile / 'tests.log').read_text(),
                        'Focused native unit tests incomplete')
            run(['moon', 'build', '--verbose', '--target', 'native', '--deny-warn', '--frozen', 'cmd/native-errors'],
                workspace, env, profile / 'build.log')
            executable = ordinary.executable(workspace / '_build/native/debug/build', 'native-errors')
            binary = sha(executable)
            stage = f'execute/{mode}'
            run([executable, '--self-check', mode, profile / 'checks'], workspace, env, profile / 'checks.log')
            checks = read_json(profile / 'checks/verification.json')
            strategies = [c for c in checks['checks'] if 'strategy' in c]
            require(checks['state'] == 'passed' and checks['mode'] == mode and len(strategies) == 3,
                    'Missing strategy checks')
            controls = [c for c in checks['checks'] if 'control' in c]
            require(len(controls) == 5 and sorted(c['control'] for c in controls)
                    == ['budget', 'disabled', 'flaky-baseline', 'flaky-final', 'weak'],
                    'Missing or duplicate native controls')
            for check in strategies:
                reduction = check['reduction']
                require(reduction['confirmed'] and reduction['deletion_minimal']
                        and reduction['reduced_steps'] == 2 and reduction['original_steps'] == 32
                        and reduction['baseline_checks'] == reduction['final_checks'] == 3,
                        'Incomplete reduction confirmation')
                require(check['replay']['fingerprint'] == reduction['baseline']['fingerprint']
                        and check['different_site']['fingerprint'] != reduction['baseline']['fingerprint']
                        and check['correct']['outcome'] == 'Pass', 'Replay controls failed')
            require(sha(executable) == binary and ordinary.manifest(workspace) == before
                    and ordinary.manifest(async_root) == dependencies, 'Inputs changed during execution')
            profiles.append({'mode': mode, 'executable_sha256': binary, 'checks': checks,
                             'compiler_profile': adaptations})
        verify(toolchain, lock, env, out / 'toolchain-after.json')
        write_json(out / 'verification.json', {
            'state': 'passed', 'source_commit': commit, 'driver_sha256': sha(__file__),
            'source_archive_sha256': sha(out / 'source.tar'), 'profiles': profiles,
            'host': platform.platform(), 'github_actions': os.getenv('GITHUB_ACTIONS'),
            'scope': 'Owned intentional C faults, three strategies and five controls per profile; '
                     'ASan weak evidence uses a synthetic incomplete diagnostic, not an actual detection. '
                     'ASan instruments faults.c only. Same-site identity is scoped to an unchanged binary.'})
        print(f'Linux native error reduction passed: {commit}')
    except Exception as error:
        write_json(out / 'failure.json', {'state': 'failed', 'stage': stage, 'error': str(error)})
        raise


if __name__ == '__main__':
    main()
