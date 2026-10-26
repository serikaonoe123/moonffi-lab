"""Exercise release-candidate gates using isolated Git indexes, never changing refs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile

SCOPE = 'docs/releases/v0.1.0-rc.2-scope.json'
OLD_SCOPE = 'docs/releases/v0.1.0-scope.json'
BASELINE = 'f464479107ea46369846a41dde090d25b28426d6'
OLD_RELEASE = '23893d5bb3a231a21df10db506d8da821a7e984d'
ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def git(*args, data=None, env=None):
    return subprocess.check_output(['git', *args], input=data, cwd=ROOT, env=env)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ref', default='HEAD')
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    out = Path(args.out).resolve()
    if out.exists():
        raise ValueError('Test output must be new')
    out.mkdir(parents=True)
    commit = git('rev-parse', '--verify', args.ref + '^{commit}').decode().strip()
    original_head = git('rev-parse', 'HEAD')
    original_index = git('write-tree')
    checks = []
    mutations = []

    def prepare(label, ref=commit, scope=SCOPE, error=None, stage=None, destination=None):
        destination = destination or out / label
        result = subprocess.run(['pwsh', '-NoProfile', '-File', str(ROOT / 'scripts/prepare-release.ps1'),
                                 '-Ref', ref, '-ScopeFile', scope, '-Out', str(destination)],
                                cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (out / (label + '.log')).write_bytes(result.stdout)
        if error is None:
            assert result.returncode == 0, (label, result.stdout.decode(errors='replace'))
            return read(destination / 'candidate.json')
        assert result.returncode != 0, 'Unexpected acceptance: ' + label
        if stage:
            failure = read(destination / 'failure.json')
            assert failure['stage'] == stage and error in failure['error'], (label, failure)
            assert not (destination / 'candidate.json').exists()
        checks.append({'name': label, 'outcome': 'rejected', 'stage': stage})

    def mutation(label, path, transform):
        # Each labelled probe uses a separate index. No worktree or branch is changed.
        index = out / (label + '.index')
        env = os.environ.copy()
        env.update(GIT_INDEX_FILE=str(index), GIT_AUTHOR_NAME='Release gate control',
                   GIT_AUTHOR_EMAIL='control@example.invalid', GIT_COMMITTER_NAME='Release gate control',
                   GIT_COMMITTER_EMAIL='control@example.invalid',
                   GIT_AUTHOR_DATE='2000-01-01T00:00:00Z', GIT_COMMITTER_DATE='2000-01-01T00:00:00Z')
        git('read-tree', commit, env=env)
        original = git('show', commit + ':' + path) if path in tracked else b''
        content = transform(original)
        blob = git('hash-object', '-w', '--stdin', data=content).decode().strip()
        git('update-index', '--add', '--cacheinfo', '100644,' + blob + ',' + path, env=env)
        tree = git('write-tree', env=env).decode().strip()
        changed_commit = git('commit-tree', tree, '-p', commit,
                             data=('Labelled release gate control: ' + label + '\n').encode(), env=env).decode().strip()
        mutations.append({'label': label, 'path': path, 'commit': changed_commit})
        return changed_commit

    def json_change(update):
        def transform(content):
            data = json.loads(content)
            update(data)
            return (json.dumps(data, indent=2) + '\n').encode()
        return transform

    tracked = set(git('ls-tree', '-r', '--name-only', commit).decode().splitlines())
    try:
        first, second = prepare('a'), prepare('b')
        assert first['state'] == second['state'] == 'prepared-not-published'
        assert first['release_tag'] == 'v0.1.0-rc.2' and first['scope_file'] == SCOPE
        assert first['archive_sha256'] == second['archive_sha256']
        assert first['source_manifest_sha256'] == second['source_manifest_sha256']
        assert first['baseline_tested_commit'] == BASELINE and not first['baseline_is_candidate_ci']
        assert not first['publish_ready'] and not first['release_published'] and not first['registry_published']
        assert set(first['pending']) == {'candidate-hosted-acceptance', 'independent-user-reproduction', 'explicit-publication-approval'}
        entries = read(out / 'a/source-manifest.json')
        with zipfile.ZipFile(out / 'a/source.zip') as archive:
            names = {name for name in archive.namelist() if not name.endswith('/')}
            assert names == tracked == {entry['path'] for entry in entries}
            assert all(hashlib.sha256(archive.read(entry['path'])).hexdigest().upper() == entry['sha256'] for entry in entries)
        checks.append({'name': 'two-complete-source-archives', 'outcome': 'passed', 'files': len(entries),
                       'deterministic_zip': True, 'deterministic_manifest': True})
        preserved = sha(out / 'a/source.zip')
        prepare('existing-output', destination=out / 'a', error='existing output')
        assert sha(out / 'a/source.zip') == preserved
        prepare('missing-commit', ref='missing-rc2-controls-ref', error='Git command failed', stage='resolve-commit')
        prepare('unsupported-scope', scope='../scope.json', error='Unsupported release scope path', stage='select-scope')
        prepare('missing-rc2-scope', ref=BASELINE, error='Commit has no frozen release scope', stage='scope-and-evidence')
        legacy = prepare('rc1-preserved', ref=OLD_RELEASE, scope=OLD_SCOPE)
        assert legacy['source_commit'] == OLD_RELEASE and legacy['release_tag'] == 'v0.1.0-rc.1'
        checks.append({'name': 'rc1-frozen-candidate-still-prepares', 'outcome': 'passed'})
        prepare('rc1-rejects-new-runtime', scope=OLD_SCOPE,
                error='Runtime or validation scripts differ', stage='scope-and-evidence')
        core = sorted(path for path in tracked if path.startswith('core/') and path.endswith('.mbt'))[0]
        for label, path in [('runtime-drift', core), ('validation-drift', 'scripts/verify-clean.ps1')]:
            changed = mutation(label, path, lambda b: b + b'\n// Labelled source drift control\n')
            prepare(label, ref=changed, error='Runtime or validation scripts differ', stage='scope-and-evidence')
        changed = mutation('linux-lock-drift', 'toolchain-linux.json',
                           json_change(lambda data: data['binary_sha256'].update(moon='0' * 64)))
        prepare('linux-lock-drift', ref=changed, error='Toolchain content differs', stage='scope-and-evidence')
        changed = mutation('evidence-drift', 'docs/evidence/main-toolchain-acceptance-20261024.json',
                           json_change(lambda data: data.update(state='failed')))
        prepare('evidence-drift', ref=changed, error='Recorded baseline evidence differs', stage='scope-and-evidence')
        changed = mutation('notice-drift', 'LICENSE', lambda b: b + b'\nLabelled notice drift control\n')
        prepare('notice-drift', ref=changed, error='Required notice content differs', stage='scope-and-evidence')
        for label, update, error in [
            ('suite-omitted', lambda data: data.update(required_suites=['sdk']), 'Release suite list changed'),
            ('pending-omitted', lambda data: data.update(pending=[]), 'Candidate pending work must remain explicit'),
            ('baseline-relabelled', lambda data: data.update(baseline_tested_commit=OLD_RELEASE), 'Unsupported rc.2 baseline'),
        ]:
            changed = mutation(label, SCOPE, json_change(update))
            prepare(label, ref=changed, error=error, stage='scope-and-evidence')
        changed = mutation('unaccepted-ci-drift', '.github/workflows/unaccepted-control.yml',
                           lambda b: b'name: labelled control only\n')
        prepare('unaccepted-ci-drift', ref=changed, error='Runtime or validation scripts differ', stage='scope-and-evidence')
        assert git('rev-parse', 'HEAD') == original_head and git('write-tree') == original_index
        summary = {'state': 'passed', 'source_commit': commit, 'checks': checks,
                   'source_files_checked': len(entries), 'archive_sha256': first['archive_sha256'],
                   'source_manifest_sha256': first['source_manifest_sha256'], 'mutations': mutations,
                   'refs_and_main_index_unchanged': True, 'published': False,
                   'preparer_sha256': sha(ROOT / 'scripts/prepare-release.ps1')}
        (out / 'verification.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'state': 'passed', 'checks': len(checks), 'source_files': len(entries)}))
    except Exception as error:
        (out / 'failure.json').write_text(json.dumps({'state': 'failed', 'error': str(error), 'checks': checks}, indent=2) + '\n', encoding='utf-8')
        raise


if __name__ == '__main__':
    main()
