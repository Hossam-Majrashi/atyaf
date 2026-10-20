# AppImage icon fixtures

`appimage-icons.squashfs.gz.b64` and `appimage-icons.iso.gz.b64` are gzip/base64-encoded, tiny filesystem images created locally for icon-reader regressions. They contain only an original solid-color SVG, a fixture `.desktop` entry, an internal `.DirIcon` link, and an `AppRun` shell script that would create `$HOME/atyaf-icon-executed` if incorrectly executed. The SquashFS fixture also contains a deliberately damaged PNG. No downloaded application code or third-party logo is included.

The SquashFS image was generated with the installed appimagetool (Zstd compression); only its 4096-byte filesystem payload is retained, not its runtime. The ISO image was generated with `xorriso -as mkisofs -R`. `test/support/appimage_fixture.dart` adds a synthetic ELF64/AppImage identification header at test time. These fixtures are for data-only parsing and must not be launched. Neither generator is needed to run tests; the icon reader needs host `7zz` or `7z`.
