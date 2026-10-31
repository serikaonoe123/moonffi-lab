"""Identity checks shared by the Linux published-package consumer and its controls."""
from pathlib import Path
import re

from linux_toolchain import archive_path, read_json, run, sha, write_json


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_identity(published):
    require(published['schema'] == 1 and published['module'] == 'serikaonoe123/moonffi-lab'
            and published['version'] == '0.1.0', 'Unexpected published package identity')
    require(isinstance(published['archive_bytes'], int) and published['archive_bytes'] > 0
            and re.fullmatch(r'[A-Fa-f0-9]{64}', published['archive_sha256']), 'Invalid archive identity')
    require(len(published['files']) == 32, 'Expected the approved 32-file package')
    paths = set()
    for item in published['files']:
        path = archive_path(item['path']).as_posix()
        require(path == item['path'] and path not in paths, 'Invalid or duplicate package path')
        require(isinstance(item['bytes'], int) and item['bytes'] >= 0
                and re.fullmatch(r'[A-Fa-f0-9]{64}', item['sha256']), 'Invalid file identity')
        paths.add(path)


def check_resolution(tree, packages, consumer, published):
    engine = [m for m in tree['modules'] if m['name'] == published['module']]
    require(len(engine) == 1 and engine[0]['source']['kind'] == 'registry'
            and engine[0]['version'] == published['version']
            and engine[0]['workspace_member'] is False, 'Engine must resolve from the approved registry release')
    consumers = [m for m in tree['modules'] if m['name'] == 'moonffi-example/counter-lab']
    require(len(consumers) == 1 and consumers[0]['source']['kind'] == 'local'
            and Path(consumers[0]['source']['path']).resolve() == consumer.resolve(),
            'Consumer must resolve from the new local workspace')
    dependencies = [m for m in tree['modules'] if m['name'] == 'moonbitlang/async']
    require(len(dependencies) == 1 and dependencies[0]['source']['kind'] == 'registry'
            and dependencies[0]['version'] == '0.22.5' and dependencies[0]['workspace_member'] is False,
            'async must resolve to registry version 0.22.5')
    nodes = [n['rel'] for n in packages['nodes'] if n['module'] == published['module']]
    require(sorted(nodes) == ['core', 'runner'], 'Consumer used engine packages outside core/runner')


def check_installed(engine, archive, published):
    require(archive.stat().st_size == published['archive_bytes']
            and sha(archive) == published['archive_sha256'].upper(), 'Registry archive identity differs')
    actual = set()
    for path in engine.rglob('*'):
        require(not path.is_symlink(), 'Installed package contains a symbolic link')
        relative = path.relative_to(engine)
        if path.is_file() and '_build' not in relative.parts and path.name != 'pkg.generated.mbti':
            actual.add(relative.as_posix())
    require(actual == {item['path'] for item in published['files']}, 'Installed package file set differs')
    for item in published['files']:
        path = engine / item['path']
        require(path.stat().st_size == item['bytes'] and sha(path) == item['sha256'].upper(),
                f'Installed package content differs: {item["path"]}')


def verify_registry(root, consumer, env, out, published, cached_before):
    validate_identity(published)
    require(not (root / 'engine').exists() and not (root / 'async').exists(),
            'Registry consumer cannot contain local engine or async members')
    run(['moon', 'tree', '--json'], consumer, env, out / 'module-tree.json')
    run(['moon', 'tree', '--package', '--json'], consumer, env, out / 'package-tree.json')
    check_resolution(read_json(out / 'module-tree.json'), read_json(out / 'package-tree.json'), consumer, published)
    locations = [p for p in (root / '.mooncakes' / published['module'],
                             consumer / '.mooncakes' / published['module']) if p.is_dir()]
    require(len(locations) == 1, 'Installed registry source location is ambiguous')
    archive = Path(env['MOON_HOME']) / 'registry/cache' / published['module'] / (published['version'] + '.zip')
    check_installed(locations[0], archive, published)
    result = {'module': published['module'], 'version': published['version'], 'source_kind': 'registry',
              'workspace_engine_member': False, 'archive_cached_before': cached_before,
              'async_source_kind': 'registry', 'async_version': '0.22.5',
              'archive_sha256': sha(archive), 'archive_bytes': archive.stat().st_size,
              'source_files_matched': len(published['files'])}
    write_json(out / 'registry-engine.json', result)
    return result
