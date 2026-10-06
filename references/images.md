# Images: models, generate, edit

> Safety: `generate-image` and `edit-image` spend AI credits. Confirm the model, count and cost with the user before each call.

```bash
BASE=https://api-app.designerbox.ai/api/v1
```

## Models and prices

```bash
curl -sS $BASE/ai/image-models -H "x-api-key: $DESIGNERBOX_API_KEY" \
  | jq -r '.data.models[] | "\(.id)\t\(.creditsPerImage)\t\(.capabilities|join(","))"'
```

Response: `{success, data:{models:[...], count}}`. Each model has `id, name, provider, capabilities[], creditsPerImage, isDefault, aspectRatios[], maxReferenceImages, supportedEditModes`.

Capabilities decide what a model can do:
- `text-to-image`: usable with `generate-image`.
- `image-to-image` / `multi-reference`: usable with `edit-image` (up to `maxReferenceImages` references).
- `upscale`: upscaling only.

`supportedEditModes` is set only on some models (for example the Gemini ones): `default`, `style`, `bgswap`, `product_image`, `outpaint`, `inpaint_removal`, `inpaint_insertion`. It is `null` on the others; send no `editMode` to those.

The price list for every AI operation is public: `curl -sS $BASE/ai/credit-costs` (no key).

## Generate

```bash
curl -sS -X POST $BASE/ai/generate-image \
  -H "x-api-key: $DESIGNERBOX_API_KEY" -H 'Content-Type: application/json' \
  -d '{"prompt":"a ceramic mug on a linen tablecloth, soft morning light","model":"nano-banana-2","aspectRatio":"4:5","numberResults":1}'
```

Body: `prompt` (required), `model` (from the models list; omitted = the default model), `numberResults` (integer 1-10; any other value silently becomes 1), `aspectRatio` (one of the model's `aspectRatios`), `seed`.

Cost = `creditsPerImage` x `numberResults`, reserved before the provider is called.

Response: `{success, data:{images:[{id, url, ...}], message, metadata}}`. Each image is already saved as an asset; `id` is its asset id.

## Edit

```bash
curl -sS -X POST $BASE/ai/edit-image \
  -H "x-api-key: $DESIGNERBOX_API_KEY" -H 'Content-Type: application/json' \
  -d '{"prompt":"replace the background with a marble kitchen counter","model":"nano-banana-2","editMode":"bgswap","numberResults":1,
       "referenceImages":[{"imageUrl":"https://d1jvbmo0p8k2km.cloudfront.net/<file>.jpg","type":"raw"}]}'
```

Body: `prompt` (required), `referenceImages` (required, non-empty), `model`, `editMode`, `numberResults`.

Each reference is `{imageUrl, type, subjectType?, label?}`:
- `imageUrl` must be a public https image. Use an asset's `viewUrl` (`GET /assets/{id}`) for a library image, or upload a local file first (`references/assets.md`).
- `type`: `raw` (the image to edit; what the web app sends), `subject`, `style` or `mask`.
- `subjectType` (with `subject`): `person`, `animal` or `product`.
- `label`: a name you can mention in the prompt as `@<label>`.

The response has the same shape as generate, and the results are saved as assets.

The helper sends every `--ref` as `type: "raw"`. For subject, style or mask references, use raw curl.
