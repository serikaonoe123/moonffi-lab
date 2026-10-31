"""Fresh Linux Mooncakes 0.1.0 download, byte identity and external native SDK validation."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import platform
import subprocess

from linux_toolchain import extract, read_json, run, sha, verify, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--toolchain', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--ref', default='HEAD')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    out, toolchain = Path(args.out).resolve(), Path(args.toolchain).resolve()
    if out.exists():
        raise ValueError('Evidence output must be new')
    out.mkdir(parents=True)
    stage = 'platform'
    try:
        if platform.system() != 'Linux' or platform.machine() != 'x86_64':
            raise ValueError('Linux x86_64 required')
        env = {**os.environ, 'MOON_HOME': str(toolchain),
               'PATH': str(toolchain / 'bin') + os.pathsep + os.environ['PATH']}
        stage = 'toolchain'
        verify(toolchain, read_json(project / 'toolchain-linux.json'), env, out / 'toolchain.json')
        run(['gcc', '--version'], project, env, out / 'gcc-version.log')
        stage = 'export-harness'
        commit = subprocess.check_output(['git', 'rev-parse', '--verify', args.ref + '^{commit}'],
                                         cwd=project, text=True).strip()
        run(['git', 'archive', '--format=tar', f'--output={out / "source.tar"}', commit],
            project, env, out / 'archive.log')
        harness = out / 'harness'
        harness.mkdir()
        extract(out / 'source.tar', harness)
        drivers = ('verify-linux-registry.py', 'verify-linux.py', 'registry_consumer.py', 'linux_toolchain.py')
        for name in drivers:
            if sha(project / 'scripts' / name) != sha(harness / 'scripts' / name):
                raise ValueError('Running driver differs from the specified commit: ' + name)
        published = read_json(harness / 'docs/releases/mooncakes-0.1.0.json')
        spec = importlib.util.spec_from_file_location('linux_ordinary', project / 'scripts/verify-linux.py')
        ordinary = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ordinary)
        stage = 'fresh-registry-sdk'
        sdk = ordinary.sdk(harness, out / 'sdk', env, registry_package=published)
        result = {'state': 'passed', 'source_commit': commit, 'source_archive_sha256': sha(out / 'source.tar'),
                  'driver_sha256': {name: sha(project / 'scripts' / name) for name in drivers},
                  'harness_source': 'adapter-starter from the specified Git commit; engine and async resolved only from registry',
                  'host': {'os': platform.platform(), 'github_actions': os.getenv('GITHUB_ACTIONS')},
                  'sdk': sdk, 'independent_user_feedback': False, 'new_version_published': False,
                  'scope': 'Fresh Linux registry download, pinned ZIP and all 32 installed files, 7 SDK unit tests, 88 correct campaigns, 1024 typed C FFI operations and 23 ABI boundaries. No error/ASan reduction, full Windows suite equivalence or independent-user feedback claimed.'}
        write_json(out / 'verification.json', result)
        print(json.dumps({'state': 'passed', 'source_commit': commit, 'registry_engine': sdk['registry_engine']}))
    except Exception as error:
        write_json(out / 'failure.json', {'state': 'failed', 'stage': stage, 'error': str(error)})
        raise


if __name__ == '__main__':
    main()
