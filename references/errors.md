# Errors

## Three body shapes

1. `{ "success": false, "error": { "message": "..." } }`
2. `{ "success": false, "error": "Invalid API key" }`, sometimes with `"code": "INSUFFICIENT_CREDITS"`: here `error` is a string.
3. Bare `{ "error": "No file uploaded" }` from the upload routes.

Read the message as: `.error.message` if `error` is an object, else `.error` if it is a string, else `.message`.

## Codes and what to tell the user

| Status | Code | Meaning | Tell the user |
|--------|------|---------|---------------|
| 400 | - | missing or invalid field (`Prompt is required`, `At least one reference image is required`) | fix the request |
| 401 | - | bad or missing `x-api-key` (`Invalid API key`, `Authentication required`) | check the key |
| 402 | `SUBSCRIPTION_INACTIVE` | no active paid plan | generation needs a paid DesignerBox plan |
| 403 | `INSUFFICIENT_CREDITS` | not enough AI credits for this request | check `usage`; pick a cheaper model or fewer images |
| 403 | `MODEL_ACCESS_RESTRICTED` | the model is not on the user's plan | pick another model |
| 403 | `PROHIBITED_USE_NOT_ACCEPTED` | the account has not accepted the Prohibited Use Policy | the account owner accepts it in the DesignerBox app, then retry |
| 404 | - | asset not found | check the id |
| 429 | `RATE_LIMITED` | too many requests | wait, then retry |
| 500 | - | also returned for a malformed asset id | validate ids as 24 lowercase hex characters |

The 402 and the policy 403 are checked before any credits are reserved.
