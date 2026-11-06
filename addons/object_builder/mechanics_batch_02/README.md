# Object Builder mechanics — batch 02

This directory stores the second standalone mechanics batch as seven binary segments of one gzip-compressed tar archive.

## Contents

- `animation/`: mechanics 21–30 (idle, walk, run, attack, hit, death animations, blending, animation events, frame events, variants).
- `movement/`: mechanics 31–40 (move, walk, run, jump, dash, fly, swim, climb, teleport, patrol route).

The archive contains only these two package directories. Reassemble the seven downloaded parts, then extract the archive **into** `addons/object_builder/mechanics/` so the final paths are:
- `addons/object_builder/mechanics/animation/`
- `addons/object_builder/mechanics/movement/`

### Windows PowerShell

Run these commands from this directory:

```powershell
$parts = @(
  "batch_02.tar.gz.part00",
  "batch_02.tar.gz.part01",
  "batch_02.tar.gz.part02",
  "batch_02.tar.gz.part03",
  "batch_02.tar.gz.part04",
  "batch_02.tar.gz.part05",
  "batch_02.tar.gz.part06"
)
$out = [System.IO.File]::Create("batch_02.tar.gz")
foreach ($part in $parts) {
  $bytes = [System.IO.File]::ReadAllBytes($part)
  $out.Write($bytes, 0, $bytes.Length)
}
$out.Dispose()
tar -xzf batch_02.tar.gz -C ..\mechanics
```

Each package includes `module.cfg`, `module.gd`, component scripts, smoke tests, and `INTEGRATION_REQUEST.md`. The capability status remains `Planned` until the host Object Builder explicitly binds scene nodes and the integrated tests pass.

Static structure checks were performed. Godot was not available in the generation environment, so the smoke tests have **not** been run in Godot. See the package integration notes for required host contracts and limitations.
