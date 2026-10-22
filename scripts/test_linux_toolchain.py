"""Offline regression checks for the archive installer; no downloaded tool is executed."""
import io
import json
from pathlib import Path
import stat
import tarfile
import tempfile
import unittest
import zipfile

from linux_toolchain import archive_path, check_file_manifest, extract, install, prepare_executables, sha, source_identity


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_regular_tar_preserves_bytes(self):
        path = self.root / 'valid.tar'
        with tarfile.open(path, 'w') as archive:
            directory = tarfile.TarInfo('.')
            directory.type = tarfile.DIRTYPE
            archive.addfile(directory)
            item = tarfile.TarInfo('./bin/tool')
            item.mode, item.size = 0o755, 4
            archive.addfile(item, io.BytesIO(b'data'))
        extract(path, self.root / 'out')
        self.assertEqual((self.root / 'out/bin/tool').read_bytes(), b'data')

    def test_invalid_paths_are_refused(self):
        for name in ('../outside', '/absolute', 'a/../../outside', 'C:/file', 'a\\file', '.'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                archive_path(name)

    def test_zip_link_is_refused_before_any_extraction(self):
        path = self.root / 'link.zip'
        with zipfile.ZipFile(path, 'w') as archive:
            archive.writestr('safe', b'first')
            link = zipfile.ZipInfo('link')
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(link, 'safe')
        with self.assertRaises(ValueError):
            extract(path, self.root / 'out')
        self.assertFalse((self.root / 'out/safe').exists())

    def test_tar_link_is_refused_before_any_extraction(self):
        path = self.root / 'link.tar'
        with tarfile.open(path, 'w') as archive:
            link = tarfile.TarInfo('link')
            link.type, link.linkname = tarfile.SYMTYPE, 'outside'
            archive.addfile(link)
        with self.assertRaises(ValueError):
            extract(path, self.root / 'out')
        self.assertFalse((self.root / 'out').exists())

    def test_duplicate_normalized_tar_paths_are_refused(self):
        path = self.root / 'duplicate.tar'
        with tarfile.open(path, 'w') as archive:
            for name in ('./file', 'file'):
                item = tarfile.TarInfo(name)
                item.size = 1
                archive.addfile(item, io.BytesIO(b'x'))
        with self.assertRaises(ValueError):
            extract(path, self.root / 'out')

    def test_content_mismatch_never_extracts_or_executes(self):
        archive = self.root / 'bundle.tar.gz'
        archive.write_bytes(b'incorrect content')
        expected = sha(archive)
        lock = self.root / 'lock.json'
        lock.write_text(json.dumps({'bootstrap': {'platform': 'linux-x86_64', 'archives': [
            {'file': archive.name, 'kind': 'toolchain', 'bytes': 1, 'sha256': '0'*64}]}}))
        with self.assertRaises(ValueError):
            install(lock, self.root / 'installation', self.root / 'evidence', self.root, True)
        self.assertFalse((self.root / 'installation').exists())
        self.assertEqual(sha(archive), expected)
        result = json.loads((self.root / 'evidence/failure.json').read_text())
        self.assertEqual(result['stage'], 'archives')
        self.assertEqual(result['accepted_archives'], [])

    def test_existing_destination_is_preserved(self):
        destination = self.root / 'existing'
        destination.mkdir()
        (destination / 'marker').write_text('keep')
        with self.assertRaises(ValueError):
            install(self.root / 'missing-lock', destination, self.root / 'evidence', inspect_only=True)
        self.assertEqual((destination / 'marker').read_text(), 'keep')
        self.assertFalse((self.root / 'evidence').exists())

    def test_core_identity_excludes_generated_bundle_cache(self):
        core = self.root / 'core'
        core.mkdir()
        (core / 'source.mbt').write_text('source')
        original = source_identity(core)
        (core / '_build').mkdir()
        (core / '_build/generated').write_text('cache')
        self.assertEqual(source_identity(core), original)
        (core / 'source.mbt').write_text('changed source')
        self.assertNotEqual(source_identity(core), original)

    def test_manifest_hex_case_preserves_byte_identity(self):
        (self.root / 'source').write_bytes(b'unchanged')
        digest = sha(self.root / 'source')
        for expected in (digest, digest.lower()):
            check_file_manifest(self.root, [{'path': 'source', 'sha256': expected}])
        (self.root / 'source').write_bytes(b'changed')
        with self.assertRaises(ValueError):
            check_file_manifest(self.root, [{'path': 'source', 'sha256': digest.lower()}])

    def test_executable_modes_require_matching_binary_content(self):
        (self.root / 'bin').mkdir()
        tool = self.root / 'bin/moon'
        tool.write_bytes(b'not executed')
        before = tool.stat().st_mode
        with self.assertRaises(ValueError):
            prepare_executables(self.root, {'components': {'moon': 'example'}, 'binary_sha256': {'moon': '0'*64}})
        self.assertEqual(tool.stat().st_mode, before)


if __name__ == '__main__':
    unittest.main()
