# Assets

> Safety: upload only files the user asked to add (images and video), after they approve the exact file. Uploads count against storage. The `designerbox` helper previews each upload and needs its `--confirm` code; with raw curl it is on you. Use a dedicated API key and never echo it.

```bash
BASE=https://api-app.designerbox.ai/api/v1
```

Asset ids are 24-character lowercase hex (Mongo ObjectIds). Check `^[0-9a-f]{24}$` before putting one in a path: a malformed id returns HTTP 500.

## List

```bash
# images: page by ?page, at most 100 per page
curl -sS "$BASE/assets/images?page=1&limit=20" -H "x-api-key: $DESIGNERBOX_API_KEY"
# -> {success, data:[asset], meta:{page, limit, total, totalPages, hasNextPage, hasPrevPage}}

# videos: page by ?skip (NOT page)
curl -sS "$BASE/assets/videos?skip=0&limit=20" -H "x-api-key: $DESIGNERBOX_API_KEY"
# -> {success, data:[asset], pagination:{total, limit, skip, hasMore}}
```

## One asset

```bash
curl -sS $BASE/assets/<assetId> -H "x-api-key: $DESIGNERBOX_API_KEY"
# -> {success, data:{_id, displayName, originalName, type, size, width, height, prompt, modelName, folderId, tags, viewUrl, thumbUrl, createdAt, ...}}
```

`viewUrl` is the public https file URL (CloudFront); use it to download or as an edit reference. Prefer it over `url`, which can be a raw storage URL for some assets. A missing id returns 404 `{"success":false,"error":"Asset not found"}`.

`GET /assets/view/<assetId>` answers with a 302 redirect to the same file.

## Download

```bash
URL=$(curl -sS $BASE/assets/<assetId> -H "x-api-key: $DESIGNERBOX_API_KEY" | jq -r .data.viewUrl)
curl -sSfL --proto '=https' -o out.jpg "$URL"
```

## Upload a local file

Direct multipart, field `file`, up to 500 MB. Images and video only.

```bash
curl -sS -X POST $BASE/assets/upload/single \
  -H "x-api-key: $DESIGNERBOX_API_KEY" \
  -F "file=@hero.png;type=image/png"
# -> 201 {message, asset:{_id, viewUrl, ...}}   (no {success,data} wrapper)
```

Optional form fields: `displayName`, `description`, `prompt`, `width`, `height`, `folderId`.

## Import from a public URL

The DesignerBox server downloads the image itself, so the URL must be public.

```bash
curl -sS -X POST $BASE/assets/upload/url \
  -H "x-api-key: $DESIGNERBOX_API_KEY" -H 'Content-Type: application/json' \
  -d '{"imageUrl":"https://example.com/photo.jpg"}'
# -> 201 {message, asset:{...}}; an unreachable or non-image URL -> 400 {error:"We could not download a picture from that address."}
```

## Folders

`GET /folders/tree` -> `{success, data:[...]}` (the folder tree; empty array when there are none).
