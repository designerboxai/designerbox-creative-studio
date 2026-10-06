#!/usr/bin/env bash
# Every refusal path of the helper, run for real. A fake curl on PATH records any call,
# so each case also proves the refusal happened BEFORE a request was sent.
# Usage: bash tests/refusals.sh   (no network, no key needed; DBX_BASH=/bin/bash runs the helper under bash 3.2)
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DBX="$HERE/designerbox"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
cat > "$WORK/bin/curl" <<'EOF'
#!/bin/sh
echo "$@" >> "$CURL_LOG"
exit 99
EOF
chmod +x "$WORK/bin/curl"
export CURL_LOG="$WORK/curl.log"
export PATH="$WORK/bin:$PATH"
printf 'x' > "$WORK/notes.txt"
printf 'x' > "$WORK/pic.png"
printf 'x' > "$WORK/exists.jpg"
printf 'not an image' > "$WORK/evil.txt"
printf 'x' > "$WORK/evil.txt;x.png"
printf 'x' > "$WORK/clip.mp4"
ln -s "$WORK/elsewhere.jpg" "$WORK/dangling.jpg"

pass=0; fail=0
# expect_refusal NAME EXPECTED_STDERR_SUBSTRING [env KEY=VAL ...] -- ARGS...
expect_refusal() {
  local name="$1" want="$2"; shift 2
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  : > "$CURL_LOG"
  local err rc
  err="$(cd "$WORK" && env "${envs[@]}" "${DBX_BASH:-bash}" "$DBX" "$@" 2>&1 >/dev/null)"; rc=$?
  if [ "$rc" -ne 0 ] && [[ "$err" == *"$want"* ]] && [ ! -s "$CURL_LOG" ]; then
    pass=$((pass+1)); printf 'ok   %s\n' "$name"
  else
    fail=$((fail+1)); printf 'FAIL %s (rc=%s, curl calls=%s)\n     stderr: %s\n' "$name" "$rc" "$(wc -l < "$CURL_LOG" | tr -d ' ')" "$err"
  fi
}
K=DESIGNERBOX_API_KEY=apikey_dummy-not-a-key
NOKEY=DESIGNERBOX_API_KEY=

expect_refusal "missing key"                 "set DESIGNERBOX_API_KEY"   "$NOKEY" -- usage
expect_refusal "key with header injection"  "does not look like"       "DESIGNERBOX_API_KEY=$(printf 'apikey_x\nX-Evil: 1')" -- usage
expect_refusal "unknown command"             "unknown command"           "$K" -- frobnicate
expect_refusal "asset id path traversal"     "invalid asset id"          "$K" -- asset ../../users
expect_refusal "asset id with query"         "invalid asset id"          "$K" -- asset "6a632e774973bcb3a23d6c3e?x=1"
expect_refusal "asset id uppercase hex"      "invalid asset id"          "$K" -- asset 6A632E774973BCB3A23D6C3E
expect_refusal "asset id 23 chars"           "invalid asset id"          "$K" -- asset 6a632e774973bcb3a23d6c3
expect_refusal "download bad id"             "invalid asset id"          "$K" -- download nope
expect_refusal "download no overwrite"       "refusing to overwrite"     "$K" -- download 6a632e774973bcb3a23d6c3e exists.jpg
expect_refusal "download dangling symlink"    "refusing to overwrite"     "$K" -- download 6a632e774973bcb3a23d6c3e dangling.jpg
expect_refusal "download to -"               "starting with -"           "$K" -- download 6a632e774973bcb3a23d6c3e -
expect_refusal "assets limit over 100"       "--limit must be"           "$K" -- assets --limit 101
expect_refusal "assets page not int"         "--page must be"            "$K" -- assets --page 1abc
expect_refusal "assets page leading zero"    "--page must be"            "$K" -- assets videos --page 08
expect_refusal "assets unknown flag"         "unknown flag"              "$K" -- assets --folder x
expect_refusal "upload non-media"            "only image and video"      "$K" -- upload notes.txt
expect_refusal "upload ; in name (curl -F)"  "rename it without"        "$K" -- upload "evil.txt;x.png"
expect_refusal "edit ref ; in name"          "rename it without"         "$K" -- edit --prompt hi --ref "evil.txt;x.png"
expect_refusal "upload missing file"         "no such file"              "$K" -- upload missing.png
expect_refusal "upload-url http"             "refusing non-https"        "$K" -- upload-url http://example.com/a.png
expect_refusal "upload-url file scheme"      "refusing non-https"        "$K" -- upload-url file:///etc/passwd
expect_refusal "generate no prompt"          "--prompt is required"      "$K" -- generate --model nano-banana-2
expect_refusal "generate count 0"            "--count must be"           "$K" -- generate --prompt hi --count 0
expect_refusal "generate count 11"           "--count must be"           "$K" -- generate --prompt hi --count 11
expect_refusal "generate model with slash"   "invalid value"             "$K" -- generate --prompt hi --model "a/b"
expect_refusal "generate bad aspect"         "--aspect must"             "$K" -- generate --prompt hi --aspect wide
expect_refusal "generate bad seed"           "--seed must"               "$K" -- generate --prompt hi --seed -1
expect_refusal "generate flag no value"      "--prompt needs a value"    "$K" -- generate --prompt
expect_refusal "edit no ref"                 "at least one --ref"        "$K" -- edit --prompt hi
expect_refusal "edit http ref"               "--ref must be"             "$K" -- edit --prompt hi --ref http://example.com/a.png
expect_refusal "edit non-image file ref"     "only image files"          "$K" -- edit --prompt hi --ref notes.txt
expect_refusal "edit video file ref"         "only image files"          "$K" -- edit --prompt hi --ref clip.mp4
expect_refusal "edit bad mode"               "invalid value"             "$K" -- edit --prompt hi --ref pic.png --mode "x y"
expect_refusal "edit 11 refs"                "at most 10"                "$K" -- edit --prompt hi $(for i in 1 2 3 4 5 6 7 8 9 10 11; do printf -- '--ref pic.png '; done)
expect_refusal "edit good+bad ref, no upload" "--ref must be"            "$K" -- edit --prompt hi --ref pic.png --ref nope

# the key must never be a curl argument (argv is visible to every local user via ps)
: > "$CURL_LOG"
(cd "$WORK" && env "$K" "${DBX_BASH:-bash}" "$DBX" usage >/dev/null 2>&1)
if [ -s "$CURL_LOG" ] && ! grep -q "apikey_dummy-not-a-key" "$CURL_LOG" && grep -q -- "-H @-" "$CURL_LOG"; then
  pass=$((pass+1)); echo "ok   key not in curl argv"
else fail=$((fail+1)); echo "FAIL key not in curl argv: $(cat "$CURL_LOG")"; fi

# every curl must start with -q so a user's ~/.curlrc (verbose, location-trusted) cannot print or forward the key
: > "$CURL_LOG"
(cd "$WORK" && env "$K" "${DBX_BASH:-bash}" "$DBX" usage >/dev/null 2>&1; env "$K" "${DBX_BASH:-bash}" "$DBX" costs >/dev/null 2>&1)
if [ "$(wc -l < "$CURL_LOG" | tr -d ' ')" -ge 2 ] && ! grep -qv '^-q ' "$CURL_LOG"; then
  pass=$((pass+1)); echo "ok   curl always called with -q first"
else fail=$((fail+1)); echo "FAIL curl -q first: $(cat "$CURL_LOG")"; fi

# base URL is hardcoded: no env var can redirect the key to another host
if grep -nE 'BASE=.*\$' "$DBX" >/dev/null; then fail=$((fail+1)); echo "FAIL base URL is overridable"; else pass=$((pass+1)); echo "ok   base URL hardcoded"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
