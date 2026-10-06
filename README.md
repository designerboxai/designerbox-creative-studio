# designerbox-creative-studio

A Claude Agent Skill for [DesignerBox](https://designerbox.ai). It lets an agent check AI credits and model prices, generate and edit images, and list, inspect, download and upload assets in a DesignerBox library, all through the DesignerBox REST API with a single API key.

## Install

Copy this directory into your skills location (for Claude Code, a `skills/` directory the harness scans), then set your key:

```bash
export DESIGNERBOX_API_KEY=<your key>   # create at https://designerbox.ai/account/api-keys
```

Image generation and editing need a paid DesignerBox plan. The bundled `designerbox` helper needs `curl` and `jq`. In an environment with no shell, every operation has a raw curl recipe in `references/`.

## Quick start

```bash
./designerbox usage                                   # credits used and limit
./designerbox models                                  # models and credits per image
./designerbox generate --prompt "a ceramic mug on linen, morning light" --model nano-banana-2 --aspect 4:5   # preview, sends nothing
./designerbox generate --prompt "a ceramic mug on linen, morning light" --model nano-banana-2 --aspect 4:5 --confirm <code>   # after approval
./designerbox edit --prompt "swap the background for a marble counter" --ref <assetId> --mode bgswap
./designerbox download <assetId> mug.jpg
```

Run `./designerbox help` for the full command list. `generate` and `edit` spend AI credits. `generate`, `edit`, `upload` and `upload-url` always print a preview first and run only when repeated with the `--confirm` code from that preview.

## What is in here

| Path | What |
|------|------|
| `SKILL.md` | Skill entry point: setup, the core loop, safety rules and a router to the references. |
| `designerbox` | Bash helper (curl + jq): strict id checks, https-only URLs, image/video-only uploads, one-line errors. |
| `references/` | Raw curl recipes: images (models, generate, edit), assets, usage, errors. |
| `tests/refusals.sh` | Runs every refusal path offline and proves no request is sent. |
| `tests/confirm.sh` | Proves generate, edit, upload and upload-url send nothing without a matching `--confirm` code. |

## Scope

Covers image generation and editing, credits and the asset library. Not covered: video and avatar generation, brand profiles, teams, designs and deleting assets (use the DesignerBox web app).

## License

MIT. See `LICENSE`.
