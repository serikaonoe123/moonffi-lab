"""Audit retained ordinary Linux CI artifacts against committed source; run no tests."""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess

from linux_toolchain import archive_path, extract, read_json, sha, write_json


def require(condition, message):
    if not condition:
        raise ValueError(message)


def inventory(root):
    return {path.relative_to(root).as_posix(): sha(path) for path in root.rglob('*')
            if path.is_file() and not path.is_symlink() and path.name != 'pkg.generated.mbti'
            and not any(part in ('_build', '.mooncakes', '__pycache__')
                        for part in path.relative_to(root).parts)}


def compiler_changes(reference, changes):
    paths = {'vendor/eigen-binding/moon.pkg', 'fixtures/eigen/moon.pkg',
             'cmd/eigen-lab/moon.pkg', 'cmd/reducer-probe/moon.pkg'}
    require(len(changes) == 4 and {x['path'] for x in changes} == paths,
            'Unexpected compiler profile paths')
    for entry in changes:
        path = reference / entry['path']
        require(sha(path) == entry['before_sha256'], 'Compiler profile input differs')
        # Model the recorded Linux compiler-config adaptation explicitly. This
        # does not normalize or relax any original source-byte comparison.
        text = path.read_bytes().decode('utf-8').replace('\r\n', '\n')
        native = '"native": { "cc-link-flags": "-lstdc++", },'
        if entry['path'].startswith('vendor/'):
            require('/EHsc /utf-8 /bigobj /O1' in text, 'Unknown Eigen compiler profile')
            text = text.replace('/EHsc /utf-8 /bigobj /O1', '-std=c++17 -O1')
            text = text.replace('"native": {', '"native": { "cc-link-flags": "-lstdc++",', 1)
        elif 'options(' in text:
            text = text.replace('options(', 'options(link: { ' + native + ' }, ', 1)
        else:
            text += '\noptions(link: { ' + native + ' })\n'
        digest = hashlib.sha256(text.encode()).hexdigest().upper()
        require(digest == entry['after_sha256'], 'Compiler profile output differs')


def campaign(root, entry, expected_cases):
    label = entry['label']
    require(entry['cases'] == expected_cases, f'Unexpected campaign size: {label}')
    output = root / label
    summary = read_json(output / 'summary.json')
    hashes = entry['input_sha256']
    require(len(summary) == len(hashes) == expected_cases, 'Campaign records incomplete')
    require(all(x['outcome'] == 'Pass' for x in summary), 'Campaign contains non-passing cases')
    traces = []
    for index, digest in enumerate(hashes, 1):
        case = output / f'case-{index}'
        trace, report = read_json(case / 'case.json'), read_json(case / 'report.json')
        require(sha(case / 'case.json') == digest, 'Campaign input hash differs')
        require(report['outcome'] == 'Pass' and report['raw_exit_code'] == 0
                and report['executed'] == len(trace['steps']), 'Incomplete raw execution')
        require(read_json(case / 'result.json')['completed'] is True, 'Worker completion absent')
        traces.append(trace)
    return traces


def audit(repository, artifact, run_path, output):
    repository, artifact = Path(repository).resolve(), Path(artifact).resolve()
    output = Path(output).resolve()
    require(not output.exists(), 'Audit output must be new')
    output.parent.mkdir(parents=True, exist_ok=True)
    run = read_json(run_path)
    commit = run['headSha']
    require(re.fullmatch(r'[0-9a-f]{40}', commit), 'Run must name a complete Git commit')
    require(run['status'] == 'completed' and run['conclusion'] == 'success', 'Run did not succeed')
    reference = output.parent / (output.stem + '-source')
    require(not reference.exists(), 'Reference source directory must be new')
    reference.mkdir()
    archive = reference / 'source.tar'
    # git archive follows local line-ending settings. Match Linux's LF export,
    # while retaining vendor/** -text bytes exactly as recorded by Git.
    subprocess.run(['git', '-c', 'core.autocrlf=false', '-c', 'core.eol=lf', 'archive',
                    '--format=tar', '--output=' + str(archive), commit], cwd=repository, check=True)
    source = reference / 'source'
    source.mkdir()
    extract(archive, source)
    ci = artifact / 'linux-ordinary'
    report = read_json(ci / 'verification.json')
    bootstrap = read_json(artifact / 'linux-bootstrap/verification.json')
    lock = read_json(source / 'toolchain-linux.json')
    require(report['state'] == 'passed' and report['source_commit'] == commit,
            'Report and run metadata identify different source')
    require(report['driver_sha256'] == sha(source / 'scripts/verify-linux.py'), 'Driver identity differs')
    require(bootstrap['state'] == 'passed' and bootstrap['source_mode'] == 'official-downloads'
            and bootstrap['lock_sha256'] == sha(source / 'toolchain-linux.json'), 'Bootstrap identity differs')
    for name in ('before-bundle.json', 'toolchain.json'):
        toolchain = read_json(artifact / 'linux-bootstrap' / name)
        require(toolchain['state'] == 'passed' and toolchain['binaries'] == lock['binary_sha256']
                and toolchain['core'] == lock['core_source_identity']
                and toolchain['versions'] == lock['components'], 'Toolchain content or versions differ')
    require(len(bootstrap['archives']) == len(lock['bootstrap']['archives']) == 2,
            'Expected two pinned archives')
    for expected in lock['bootstrap']['archives']:
        observed = [x for x in bootstrap['archives'] if x['kind'] == expected['kind']]
        require(len(observed) == 1 and observed[0]['sha256'] == expected['sha256']
                and observed[0]['bytes'] == expected['bytes'], 'Archive content pin differs')
    sources = read_json(ci / 'source-manifest.json')
    require(sources == inventory(source) and report['source_files'] == len(sources),
            'Exported project source differs from the Git commit')
    compiler_changes(source, report['compiler_profile'])
    require(report['fault_scenarios_run'] is False and report['asan_run'] is False
            and report['full_six_suite_acceptance'] is False, 'Artifact scope is not ordinary-only')
    match = re.search(r'Total tests: (\d+), passed: (\d+), failed: (\d+)\.',
                      (ci / 'tests.log').read_text(encoding='utf-8'))
    require(match and int(match[1]) == report['root_unit_tests'] >= 78
            and match[1] == match[2] and match[3] == '0', 'Native unit test evidence incomplete')
    project_cases = {'buffer-correct': 10, 'buffer-stateful': 64, 'eigen-correct': 10,
                     'eigen-stateful': 64, 'eigen-arithmetic': 64}
    entries = report['campaigns']
    require(len(entries) == 5 and {x['label'] for x in entries} == set(project_cases),
            'Unexpected project campaigns')
    for entry in entries:
        campaign(ci, entry, project_cases[entry['label']])
    sdk = report['sdk']
    sdk_root = ci / 'sdk'
    require(sdk == read_json(sdk_root / 'verification.json') and sdk['state'] == 'passed'
            and sdk['unit_tests'] == 7, 'SDK evidence differs')
    require('Total tests: 7, passed: 7, failed: 0.' in
            (sdk_root / 'tests.log').read_text(encoding='utf-8'), 'SDK raw test log incomplete')
    sdk_cases = {'counter-correct': 8, 'counter-walk': 32, 'contracts-correct': 32,
                 'parameters-correct': 16}
    require(len(sdk['campaigns']) == 4 and {x['label'] for x in sdk['campaigns']} == set(sdk_cases),
            'Unexpected SDK campaigns')
    parameters = []
    for entry in sdk['campaigns']:
        traces = campaign(sdk_root, entry, sdk_cases[entry['label']])
        if entry['label'] == 'parameters-correct':
            parameters = traces
    require(sum(len(x['steps']) for x in parameters) == 1024, 'Parameter operation count differs')
    families = {step['op'] for trace in parameters for step in trace['steps']}
    require(families == {'array', 'bool', 'bytes', 'f64', 'i32', 'i64', 'optional', 'text', 'u32', 'u64'},
            'Missing typed parameter families')
    boundary = sdk_root / 'parameters-boundaries/case-1'
    trace, raw = read_json(boundary / 'case.json'), read_json(boundary / 'report.json')
    require(raw['outcome'] == 'Pass' and raw['raw_exit_code'] == 0
            and raw['executed'] == len(trace['steps']) == 23, 'ABI boundary execution incomplete')
    require(max(x['args'] for x in trace['steps'] if x['op'] == 'u64') == 2**64 - 1
            and min(x['args'] for x in trace['steps'] if x['op'] == 'i64') == -(2**63),
            'Wide integer ABI boundary values differ')
    dependency = read_json(ci / 'dependency-manifest.json')
    sdk_sources = read_json(sdk_root / 'source-manifest.json')
    for name, digest in sdk_sources.items():
        archive_path(name)
        if name.startswith('engine/'):
            expected = sha(source / name[len('engine/'):])
        elif name.startswith('consumer/'):
            expected = sha(source / 'examples/adapter-starter' / name[len('consumer/'):])
        elif name.startswith('async/'):
            expected = dependency['moonbitlang/async/' + name[len('async/'):]]
        else:
            require(name == 'moon.work', 'Unexpected SDK source path')
            expected = hashlib.sha256(b'members = ["engine", "consumer", "async"]\n').hexdigest().upper()
        require(digest == expected, f'SDK source identity differs: {name}')
    result = {'state': 'passed', 'tested_commit': commit, 'run_url': run['url'],
              'source_files_checked': len(sources), 'sdk_source_files_checked': len(sdk_sources),
              'root_unit_tests': report['root_unit_tests'], 'sdk_unit_tests': 7,
              'correct_project_cases': sum(project_cases.values()), 'correct_sdk_cases': sum(sdk_cases.values()),
              'typed_parameter_operations': 1024, 'explicit_abi_boundaries': 23,
              'audit_driver_sha256': sha(__file__), 'test_processes_launched': False,
              'scope': 'Read-only artifact audit and Git source export; no native tests or profile reruns.'}
    write_json(output, result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument('--artifact-root', required=True)
    parser.add_argument('--run-metadata', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    result = audit(args.repository, args.artifact_root, args.run_metadata, args.out)
    print(f'Audit passed: {result["tested_commit"]}; evidence: {args.out}')
