# Object Builder mechanics — batch 03

Batch 03 contains the standalone source packages for mechanics **41–60**:

- `physics/`: collision, movement blocking, push/pull, mass, gravity, bounce, rolling, sliding, physics material.
- `interaction/`: interaction eligibility, pickup, activate, open/close, toggle, use, range, prompt, hold interaction.

The compressed tar archive is stored as nine Base64 text segments:
`batch_03.tar.gz.b64.part00`, `part01`, `part02a`, `part02b`, and `part03` through `part07`.

## Reassemble on Windows (PowerShell)

Run inside this folder:

```powershell
$parts = @(
  "batch_03.tar.gz.b64.part00",
  "batch_03.tar.gz.b64.part01",
  "batch_03.tar.gz.b64.part02a",
  "batch_03.tar.gz.b64.part02b",
  "batch_03.tar.gz.b64.part03",
  "batch_03.tar.gz.b64.part04",
  "batch_03.tar.gz.b64.part05",
  "batch_03.tar.gz.b64.part06",
  "batch_03.tar.gz.b64.part07"
)
$base64 = ($parts | ForEach-Object { Get-Content -Raw $_ }) -join ""
[IO.File]::WriteAllBytes("batch_03.tar.gz", [Convert]::FromBase64String($base64))
tar -xzf batch_03.tar.gz -C ..\mechanics
```

Extract into `addons/object_builder/mechanics/` so the final paths become:
- `addons/object_builder/mechanics/physics/`
- `addons/object_builder/mechanics/interaction/`

Do not extract into this batch storage directory. Package preload paths are rooted at `res://addons/object_builder/mechanics/`.

Each package includes its manifest, module entrypoint, component scripts, smoke test, and `INTEGRATION_REQUEST.md`. Capability status remains `Planned` until the host Object Builder binds scene nodes and integrated tests pass.

Static structure and archive integrity were checked in the generation environment. Godot smoke tests were not executed because the Godot binary was unavailable. Review each `INTEGRATION_REQUEST.md` before connecting host APIs.
