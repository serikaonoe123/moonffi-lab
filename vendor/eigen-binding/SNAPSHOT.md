# Binding snapshot

Copied without source modifications from local `moonbit-eigen` commit
`f7037a92cae92ac1c0e54e3bfa03b2e2e0e9f8ae`, whose working tree was clean.
The four binding source files and their MIT license are preserved verbatim.
`moon.pkg` is a new, Windows/MSVC package configuration for this module.

Eigen headers are the already fetched libigl/eigen snapshot
`1f05f51517ec4fd91eed711e0f89e97a7c028c0e` (version macros: 3.3.90).
The original SOURCE.txt and COPYING files are preserved. `manifest.json`
records SHA-256 hashes of all imported source and license files.
The manifest is an integrity record, not an independent upstream verification.

These files are pre-existing work, not new MoonFFI engine implementation.
Comments describing older validation refer to the source project. In
particular, ASan validation in that project does not establish ASan coverage
in MoonFFI Lab. No network fetch or access to the sibling checkout is needed
to build this snapshot.
