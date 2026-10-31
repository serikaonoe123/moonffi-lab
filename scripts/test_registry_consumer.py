"""Offline controls for published-package identity and registry resolution; no native faults."""
import copy
from pathlib import Path
import tempfile
import unittest

from linux_toolchain import sha
from registry_consumer import check_installed, check_resolution, validate_identity


class RegistryConsumerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.engine = self.root / 'installed'
        self.engine.mkdir()
        self.archive = self.root / 'published.zip'
        self.archive.write_bytes(b'synthetic archive identity fixture; not a published package')
        self.published = {'schema': 1, 'module': 'serikaonoe123/moonffi-lab', 'version': '0.1.0',
                          'archive_sha256': sha(self.archive), 'archive_bytes': self.archive.stat().st_size,
                          'files': []}
        for index in range(32):
            path = self.engine / f'file-{index}.mbt'
            path.write_bytes(f'fixture-{index}'.encode())
            self.published['files'].append({'path': path.name, 'bytes': path.stat().st_size, 'sha256': sha(path)})
        self.consumer = self.root / 'consumer'
        self.tree = {'modules': [
            {'name': self.published['module'], 'version': '0.1.0', 'source': {'kind': 'registry'}, 'workspace_member': False},
            {'name': 'moonffi-example/counter-lab', 'source': {'kind': 'local', 'path': str(self.consumer)}},
            {'name': 'moonbitlang/async', 'version': '0.22.5', 'source': {'kind': 'registry'}, 'workspace_member': False}]}
        self.packages = {'nodes': [{'module': self.published['module'], 'rel': name} for name in ('core', 'runner')]}

    def test_matching_identity_and_resolution(self):
        validate_identity(self.published)
        check_installed(self.engine, self.archive, self.published)
        check_resolution(self.tree, self.packages, self.consumer, self.published)

    def test_archive_content_mismatch(self):
        self.archive.write_bytes(b'different archive')
        with self.assertRaisesRegex(ValueError, 'archive identity'):
            check_installed(self.engine, self.archive, self.published)

    def test_installed_source_content_mismatch(self):
        (self.engine / 'file-0.mbt').write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError, 'content differs'):
            check_installed(self.engine, self.archive, self.published)

    def test_missing_and_extra_files(self):
        for change in ('missing', 'extra'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temporary:
                engine = Path(temporary)
                for file in self.engine.iterdir():
                    (engine / file.name).write_bytes(file.read_bytes())
                if change == 'missing':
                    (engine / 'file-0.mbt').unlink()
                else:
                    (engine / 'unexpected.mbt').write_bytes(b'extra')
                with self.assertRaisesRegex(ValueError, 'file set'):
                    check_installed(engine, self.archive, self.published)

    def test_local_engine_cannot_stand_in_for_registry(self):
        for alteration in ({'source': {'kind': 'local'}}, {'workspace_member': True}, {'version': '0.2.0'}):
            with self.subTest(alteration=alteration):
                tree = copy.deepcopy(self.tree)
                tree['modules'][0].update(alteration)
                with self.assertRaisesRegex(ValueError, 'approved registry'):
                    check_resolution(tree, self.packages, self.consumer, self.published)

    def test_private_engine_package_is_rejected(self):
        self.packages['nodes'].append({'module': self.published['module'], 'rel': 'fixtures'})
        with self.assertRaisesRegex(ValueError, 'outside core/runner'):
            check_resolution(self.tree, self.packages, self.consumer, self.published)

    def test_duplicate_package_identity_is_rejected(self):
        self.published['files'][1] = self.published['files'][0]
        with self.assertRaisesRegex(ValueError, 'duplicate package path'):
            validate_identity(self.published)

    def test_wrong_consumer_location_is_rejected(self):
        self.tree['modules'][1]['source']['path'] = str(self.root / 'another-consumer')
        with self.assertRaisesRegex(ValueError, 'new local workspace'):
            check_resolution(self.tree, self.packages, self.consumer, self.published)

    def test_different_dependency_resolution_is_rejected(self):
        for alteration in ({'version': '0.22.6'}, {'source': {'kind': 'local'}}):
            with self.subTest(alteration=alteration):
                tree = copy.deepcopy(self.tree)
                tree['modules'][2].update(alteration)
                with self.assertRaisesRegex(ValueError, 'async must resolve'):
                    check_resolution(tree, self.packages, self.consumer, self.published)


if __name__ == '__main__':
    unittest.main()
