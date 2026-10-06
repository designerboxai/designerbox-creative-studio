# Usage, credits and plan

```bash
curl -sS https://api-app.designerbox.ai/api/v1/usage/limits -H "x-api-key: $DESIGNERBOX_API_KEY"
```

```jsonc
{ "success": true, "data": {
    "subscriptionTier": "basic", "isTrial": false,
    "aiCredits": { "limit": 100000, "current": 0, "exceeded": false },
    "storage":   { "limit": 10240, "current": 2.52, "exceeded": false }   // megabytes
} }
```

Remaining credits = `aiCredits.limit - aiCredits.current`. Before a generation, compare that with the cost (`creditsPerImage` x count from `GET /ai/image-models`).

Use `/usage/limits`, not `/usage/aicredits`: the latter reports a base `limit` that ignores plan overrides, so the two can disagree.

Credit prices for every AI operation, no key needed: `GET /ai/credit-costs` -> `{success, data:{<category>:{label, cost, operations[]}}}`. Image models are priced per image in the models list.
