# PdfCraft: the one document reader

`modules/home/apps/media.nix`, package [`pkgs/pdfcraft/`](../../../pkgs/pdfcraft/package.nix). Upstream: <https://github.com/storytold/pdfcraft>.

## Why it is here

It replaced Papers on 18/11/2026. PdfCraft is a PDF reader AND editor written from scratch in pure
Rust (egui, rendering through wgpu), by the ArtCraft team: forms, annotations, signing, OCR,
merge/split. Papers only read. It is the ONE PDF reader and the `application/pdf` default.

**CBZ was dropped with Papers, on purpose.** PdfCraft's `.desktop` declares only
`application/pdf`, and nothing on the machine is the `.cbz` default anymore. One reader, not two.

## Why the release binary

Not in nixpkgs, and a source build means compiling a large Rust workspace on every bump. The
`linux-x86_64` tarball is already an FHS prefix (`bin/`, `share/`), links only glibc 2.35 and
`libgcc_s`, and dlopens the rest. The wrapper puts those on `LD_LIBRARY_PATH`: dbus, EGL/GL,
`libwayland-client`/`-egl`, xkbcommon and the X11 set the binary names as strings. It is built
WHOLE from unstable for the same glibc reason as [ZapFast](zapfast.md#why-the-release-binary-and-not-the-flake).

What comes along from the tarball:

- `pdfcraft-cli`, the headless tool (convert, combine, OCR, and `ui --control` to drive the app).
- `share/pdfcraft/models`, the ONNX models of the built-in OCR. The binary looks for them at
  `../share/pdfcraft/models` from itself, which the wrapper keeps true (`$out/bin`).

**The renderer is wgpu on GL**, not Vulkan: the binary names no `libvulkan`, and on the Arc B580
it logs `adapter: ... (IntegratedGpu, Gl)`. `PDFCRAFT_RENDERER=gl` skips wgpu altogether if a
driver bump ever breaks it.

**Help > Check for updates is inert**: it cannot rewrite the store. The bump is the updater.

## Updating

`update`/`upgrade` does it: `pdfcraft-bump` (the package's `passthru.updateScript`, see
[docs/notes/repo/version-bumps.md](../repo/version-bumps.md)) reads the tag from a HEAD on
`/releases/latest` and the sha256 from the release's signed `SHA256SUMS.txt`, so a no-op costs no
download. Upstream releases every few days, so it is always the latest release.
