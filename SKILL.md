---
name: designerbox-creative-studio
version: 0.1.0
description: Generate and edit images with DesignerBox AI and manage the user's DesignerBox asset library through the DesignerBox REST API. Use when the user wants to create an image from a prompt, edit or restyle an existing image (background swap, style transfer, object removal, outpaint, product shots), check AI credit usage or model prices, or list, inspect, download or upload images and videos in their DesignerBox library, and has a paid DesignerBox account and API key.
metadata:
  requires:
    bins: [curl, jq]
    env: [DESIGNERBOX_API_KEY]
---

# DesignerBox Creative Studio

Drive a DesignerBox account programmatically: pick an image model, generate or edit images, and work with the asset library. Wraps the DesignerBox REST API with a per-user API key.

## Setup

1. The user creates an API key at https://designerbox.ai/account/api-keys. Image generation and editing need a paid plan.
2. Export it: `export DESIGNERBOX_API_KEY=<key>`
3. Base URL is `https://api-app.designerbox.ai/api/v1`. Auth header on every request: `x-api-key: $DESIGNERBOX_API_KEY`.

Two ways to use this skill:
- **Helper (recommended where a shell is available):** the bundled `designerbox` script (needs `curl` + `jq`). Run `./designerbox help`.
- **Raw curl (works anywhere):** every operation has a copy-paste recipe in `references/`.

## The core loop

1. **Check the budget**: `./designerbox usage` (credits used and limit) and `./designerbox models` (credits per image for each model).
2. **Generate**: `./designerbox generate --prompt "..." [--model nano-banana-2] [--aspect 16:9] [--count 1]`. Prints the new images' asset ids and URLs.
3. **Edit** an existing image: `./designerbox edit --prompt "..." --ref <assetId|https-url|image-file> [--mode bgswap]`. A local image file is uploaded to the library first.
4. **Use the result**: `./designerbox asset <id>` for details, `./designerbox download <id> out.jpg` to save it locally.

Every generated or edited image is saved to the user's library automatically.

## Safety

- **Generation and editing spend real AI credits** on the user's account. Before every `generate` or `edit`, tell the user the model, the image count and the cost (`creditsPerImage` x count from `./designerbox models`) and get a yes.
- **Uploads add files to the user's library and use storage.** Upload only files the user asked to add. A local file passed to `edit --ref` is uploaded to the library first and stays there, even if the edit then fails. The helper accepts images and video only, and `upload-url` and edit references must be https.
- The API key acts on the user's real account. Use a dedicated key, and never paste it into prompts, logs, URLs or files.
- The helper sends the key only to `https://api-app.designerbox.ai`. `download` fetches the asset's public https `viewUrl` without the key. Do not send the key to any other host.
- This skill never deletes anything.

## Traps the helper absorbs (handle them yourself with raw curl)

1. **Asset ids are 24-character lowercase hex.** A malformed id returns HTTP 500, not 404. Check the shape before putting an id in a path.
2. **`numberResults` outside 1-10 is silently turned into 1** and still succeeds. Validate the count yourself.
3. **An unknown `model` is refused**, so take ids from `GET /ai/image-models`, not from memory.
4. **Envelopes differ**: image lists use `{data, meta}`, video lists `{data, pagination}` and page by `skip`, uploads return a bare `{message, asset}`. Errors arrive as `{error:{message}}`, `{error:"...", code}` or a bare `{error}`.
5. **Report credits from `GET /usage/limits`.** `/usage/aicredits` shows a different limit that ignores plan overrides.

## When to read which reference

| Task | Read |
|------|------|
| Pick a model, generate or edit an image, edit modes, costs | `references/images.md` |
| List, inspect, download or upload assets | `references/assets.md` |
| Credits, storage, plan | `references/usage.md` |
| Error codes and what to tell the user | `references/errors.md` |

## Known limitations

- Video and avatar generation are not covered by this version.
- Not available with an API key (web app only): brand profiles, teams, designs, the gallery, deleting assets.
- The key acts on its account's default team.
