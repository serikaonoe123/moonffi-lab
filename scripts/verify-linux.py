"""Linux ordinary native build, unit tests, correct campaigns and external SDK checks."""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess

from linux_toolchain import check_file_manifest, extract, read_json, run, sha, verify, write_json


def require(value, message):
    if not value:
        raise ValueError(message)


def manifest(root):
    return {p.relative_to(root).as_posix(): sha(p) for p in root.rglob('*')
            if p.is_file() and not p.is_symlink()
            and not any(x in ('_build', '.mooncakes', '__pycache__') for x in p.relative_to(root).parts)
            and p.name != 'pkg.generated.mbti'}


def campaign(executable, out, label, count, env, generator='default', steps=64):
    destination = out / label
    run([executable, 'run', '--mode', 'correct', '--generator', generator, '--seed', '17',
         '--cases', str(count), '--steps', str(steps), '--timeout-ms', '10000', '--out', destination],
        executable.parent, env, out / f'{label}.log')
    reports = read_json(destination / 'summary.json')
    require(len(reports) == count and all(x['outcome'] == 'Pass' for x in reports),
            f'Correct campaign incomplete: {label}')
    inputs = []
    for index in range(1, count + 1):
        case = destination / f'case-{index}'
        trace, report = read_json(case / 'case.json'), read_json(case / 'report.json')
        require(report['raw_exit_code'] == 0 and report['executed'] == len(trace['steps']),
                f'Incomplete raw execution: {label}/{index}')
        require(read_json(case / 'result.json')['completed'], 'Worker completion absent')
        inputs.append(sha(case / 'case.json'))
    return {'label': label, 'cases': count, 'generator': generator, 'input_sha256': inputs}


def linux_profile(workspace):
    """Adapt compiler options in the disposable copy; preserve every C/C++ source byte."""
    changes = []
    for relative in ('vendor/eigen-binding/moon.pkg', 'fixtures/eigen/moon.pkg',
                     'cmd/eigen-lab/moon.pkg', 'cmd/reducer-probe/moon.pkg'):
        path = workspace / relative
        before, text = sha(path), path.read_text(encoding='utf-8')
        native = '"native": { "cc-link-flags": "-lstdc++", },'
        if relative.startswith('vendor/'):
            require('/EHsc /utf-8 /bigobj /O1' in text, 'Unexpected Eigen compiler profile')
            text = text.replace('/EHsc /utf-8 /bigobj /O1', '-std=c++17 -O1')
            text = text.replace('"native": {', '"native": { "cc-link-flags": "-lstdc++",', 1)
        elif 'options(' in text:
            text = text.replace('options(', 'options(link: { ' + native + ' }, ', 1)
        else:
            text += '\noptions(link: { ' + native + ' })\n'
        path.write_text(text, encoding='utf-8')
        changes.append({'path': relative, 'before_sha256': before, 'after_sha256': sha(path)})
    return changes


def copy_source(source, target):
    shutil.copytree(source, target, ignore=shutil.ignore_patterns(
        '_build', '.mooncakes', '.git', '__pycache__', 'pkg.generated.mbti',
        '*.exe', '*.obj', '*.pdb', '*.mi', '*.core', '*.o', '*.a', '*.dll', '*.lib'))


def executable(build_root, name):
    found = [path for path in build_root.rglob('*')
             if path.name in (name, name + '.exe') and path.is_file() and os.access(path, os.X_OK)]
    require(len(found) == 1, f'Executable discovery ambiguous: {name}: {[str(x) for x in found]}')
    return found[0]


def sdk(workspace, out, env):
    out.mkdir()
    root = out / 'workspace'
    engine, consumer = root / 'engine', root / 'consumer'
    engine.mkdir(parents=True)
    consumer.mkdir()
    for name in ('core', 'runner'):
        copy_source(workspace / name, engine / name)
    shutil.copy2(workspace / 'moon.mod', engine / 'moon.mod')
    starter = workspace / 'examples/adapter-starter'
    for name in ('counter', 'cmd'):
        copy_source(starter / name, consumer / name)
    shutil.copy2(starter / 'moon.mod', consumer / 'moon.mod')
    copy_source(workspace / '.mooncakes/moonbitlang/async', root / 'async')
    (root / 'moon.work').write_text('members = ["engine", "consumer", "async"]\n', encoding='utf-8')
    before = manifest(root)
    write_json(out / 'source-manifest.json', before)
    run(['moon', 'check', '--target', 'native', '--frozen', '--deny-warn', 'counter',
         'cmd/main', 'cmd/contracts', 'cmd/parameters'], consumer, env, out / 'check.log')
    run(['moon', 'test', '--target', 'native', '--frozen', '--deny-warn', '-j', '1', 'counter'],
        consumer, env, out / 'tests.log')
    require('Total tests: 7, passed: 7, failed: 0.' in (out / 'tests.log').read_text(), 'SDK tests incomplete')
    run(['moon', 'build', '--target', 'native', '--frozen', '--deny-warn',
         'cmd/main', 'cmd/contracts', 'cmd/parameters'], consumer, env, out / 'build.log')
    commands = {}
    for name in ('main', 'contracts', 'parameters'):
        commands[name] = executable(root / '_build/native/debug/build', name)
    campaigns = [campaign(commands['main'], out, 'counter-correct', 8, env),
                 campaign(commands['main'], out, 'counter-walk', 32, env, 'walk'),
                 campaign(commands['contracts'], out, 'contracts-correct', 32, env),
                 campaign(commands['parameters'], out, 'parameters-correct', 16, env, 'walk')]
    trace = read_json(out / 'parameters-correct/case-1/case.json')
    samples = [('bool', False), ('bool', True), ('i32', -(2**31)), ('i32', 2**31-1),
               ('i64', -(2**63)), ('i64', 2**63-1), ('u32', 2**32-1), ('u64', 2**64-1),
               ('text', {'$ffi_text': '😀中文\0'}), ('bytes', {'$ffi_bytes': [0,255,1,0]}),
               ('array', [-64,0,64]), ('array', []), ('optional', None), ('optional', -(2**63))]
    for bits in ('0','9223372036854775808','1','9223372036854775809','9218868437227405311',
                 '9218868437227405312','18442240474082181120','9221120237041090561','9221120237041090562'):
        samples.append(('f64', {'$ffi_f64': bits}))
    trace['generator_version'] = 'ffi-parameters-explicit-boundaries-1'
    trace['steps'] = [{'id': f'boundary-{i}', 'op': operation, 'args': args,
                       'defines': [], 'uses': [], 'releases': []}
                      for i, (operation, args) in enumerate(samples)]
    write_json(out / 'parameters-boundaries.json', trace)
    run([commands['parameters'], 'replay', out / 'parameters-boundaries.json', '--out',
         out / 'parameters-boundaries'], consumer, env, out / 'parameters-boundaries.log')
    report = read_json(out / 'parameters-boundaries/case-1/report.json')
    require(report['outcome'] == 'Pass' and report['executed'] == 23, 'Linux parameter ABI boundary failed')
    require(manifest(root) == before, 'SDK source inputs changed during validation')
    result = {'state': 'passed', 'unit_tests': 7, 'campaigns': campaigns,
              'typed_parameter_operations': 1024, 'explicit_parameter_boundaries': 23}
    write_json(out / 'verification.json', result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True)
    parser.add_argument('--toolchain', required=True)
    parser.add_argument('--ref', default='HEAD')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    out, toolchain = Path(args.out).resolve(), Path(args.toolchain).resolve()
    require(not out.exists(), 'Evidence output must be new')
    out.mkdir(parents=True)
    stage = 'platform'
    try:
        require(platform.system() == 'Linux' and platform.machine() == 'x86_64', 'Linux x86_64 required')
        env = {**os.environ, 'MOON_HOME': str(toolchain),
               'PATH': str(toolchain / 'bin') + os.pathsep + os.environ['PATH']}
        lock = read_json(project / 'toolchain-linux.json')
        stage = 'toolchain'
        verify(toolchain, lock, env, out / 'toolchain.json')
        for compiler in ('gcc', 'g++'):
            run([compiler, '--version'], project, env, out / f'{compiler}-version.log')
        stage = 'export'
        commit = subprocess.check_output(['git','rev-parse','--verify',args.ref+'^{commit}'],
                                         cwd=project, text=True).strip()
        run(['git','archive','--format=tar',f'--output={out / "source.tar"}',commit], project, env, out / 'archive.log')
        workspace = out / 'workspace'
        workspace.mkdir()
        extract(out / 'source.tar', workspace)
        require(not any((workspace / p).exists() for p in ('.git','.mooncakes','_build','results')), 'Source archive contains local state')
        original = manifest(workspace)
        write_json(out / 'source-manifest.json', original)
        # The reviewed third-party snapshot is checked before compiler-only adaptation.
        check_file_manifest(workspace / 'vendor/eigen-binding',
                            read_json(workspace / 'vendor/eigen-binding/manifest.json'))
        stage = 'compiler-profile'
        adaptations = linux_profile(workspace)
        write_json(out / 'compiler-profile.json', adaptations)
        before = manifest(workspace)
        stage = 'dependencies'
        run(['moon','update'], workspace, env, out / 'update.log')
        run(['moon','check','--target','native','--deny-warn'], workspace, env, out / 'check.log')
        module = (workspace / '.mooncakes/moonbitlang/async/moon.mod').read_text()
        require(f'version = "{lock["async_version"]}"' in module, 'Unexpected async version')
        write_json(out / 'dependency-manifest.json', manifest(workspace / '.mooncakes'))
        stage = 'unit-tests'
        run(['moon','test','--target','native','--deny-warn','--frozen','-j','1'], workspace, env, out / 'tests.log')
        match = re.search(r'Total tests: (\d+), passed: (\d+), failed: (\d+)\.', (out / 'tests.log').read_text())
        require(match and int(match[1]) >= 78 and match[1] == match[2] and match[3] == '0', 'Incomplete root native tests')
        stage = 'correct-campaigns'
        run(['moon','build','--target','native','--deny-warn','--frozen','cmd/buffer-lab','cmd/eigen-lab'],
            workspace, env, out / 'build.log')
        commands = {name: executable(workspace / '_build/native/debug/build', name + '-lab') for name in ('buffer','eigen')}
        campaigns = []
        for name in ('buffer','eigen'):
            campaigns.append(campaign(commands[name], out, f'{name}-correct', 10, env))
            campaigns.append(campaign(commands[name], out, f'{name}-stateful', 64, env, 'stateful'))
        campaigns.append(campaign(commands['eigen'], out, 'eigen-arithmetic', 64, env, 'arithmetic'))
        stage = 'external-sdk'
        consumer = sdk(workspace, out / 'sdk', env)
        require(manifest(workspace) == before, 'Project source inputs changed during validation')
        result = {'state': 'passed', 'source_commit': commit, 'source_archive_sha256': sha(out / 'source.tar'),
                  'source_files': len(original), 'driver_sha256': sha(__file__), 'root_unit_tests': int(match[1]),
                  'campaigns': campaigns, 'sdk': consumer, 'compiler_profile': adaptations,
                  'executable_sha256': {name: sha(path) for name, path in commands.items()},
                  'host': {'os': platform.platform(), 'github_actions': os.getenv('GITHUB_ACTIONS')},
                  'fault_scenarios_run': False, 'asan_run': False, 'full_six_suite_acceptance': False,
                  'scope': 'Ordinary Linux builds, native unit tests, correct campaigns and external SDK ABI only; no native error/ASan reduction or complete Windows-suite equivalence claimed.'}
        write_json(out / 'verification.json', result)
        print(json.dumps({'state': 'passed', 'source_commit': commit, 'root_unit_tests': int(match[1])}))
    except Exception as error:
        write_json(out / 'failure.json', {'state': 'failed', 'stage': stage, 'error': str(error)})
        raise


if __name__ == '__main__':
    main()
