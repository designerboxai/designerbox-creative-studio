#!/usr/bin/env bash
# The four commands that spend credits or add files (generate, edit, upload,
# upload-url) must send NOTHING until called with the --confirm code from their
# own preview. A fake curl on PATH records every call, so each case proves
# whether a request went out. Usage: bash tests/confirm.sh   (no network, no key
# needed; DBX_BASH=/bin/bash runs the helper under bash 3.2)
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DBX="$HERE/designerbox"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
cat > "$WORK/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$CURL_LOG"
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out="$a"; prev="$a"; done
body='{"success":true,"data":{"viewUrl":"https://cdn.example.com/a.jpg","images":[]},"asset":{"_id":"x","viewUrl":"https://cdn.example.com/a.jpg"}}'
if [ -n "$out" ]; then printf '%s' "$body" > "$out"; echo 200; else printf '%s' "$body"; fi
EOF
chmod +x "$WORK/bin/curl"
export CURL_LOG="$WORK/curl.log" PATH="$WORK/bin:$PATH" DESIGNERBOX_API_KEY=apikey_dummy-not-a-key
printf 'png-one' > "$WORK/a.png"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n     %s\n' "$1" "$2"; }
calls() { if [ -s "$CURL_LOG" ]; then wc -l < "$CURL_LOG" | tr -d ' '; else echo 0; fi; }
run() { : > "$CURL_LOG"; OUT="$(cd "$WORK" && "${DBX_BASH:-bash}" "$DBX" "$@" 2>&1)"; RC=$?; }
code_of() { printf '%s' "$OUT" | sed -n 's/.*--confirm \([0-9a-f]\{12\}\).*/\1/p' | tail -1; }

# check NAME ARGS... : no code -> preview, wrong code -> refused, right code -> sent
check() {
  local name="$1"; shift
  run "$@"
  if [ "$RC" -eq 3 ] && [ "$(calls)" -eq 0 ] && [[ "$OUT" == *"PREVIEW (nothing was sent)"* ]]; then ok "$name: no --confirm previews, sends nothing"
  else bad "$name: no --confirm" "rc=$RC calls=$(calls) out=$OUT"; fi
  local code; code="$(code_of)"
  run "$@" --confirm 000000000000
  if [ "$RC" -eq 3 ] && [ "$(calls)" -eq 0 ] && [[ "$OUT" == *"does not match"* ]]; then ok "$name: wrong code refused, sends nothing"
  else bad "$name: wrong code" "rc=$RC calls=$(calls) out=$OUT"; fi
  run "$@" --confirm "$code"
  if [ "$(calls)" -gt 0 ] && [[ "$OUT" != *"PREVIEW"* ]]; then ok "$name: matching code sends the request"
  else bad "$name: matching code" "rc=$RC calls=$(calls) code=$code out=$OUT"; fi
}

check "generate"   generate --prompt "a mug" --model seedream-5 --count 1
check "edit"       edit --prompt "swap background" --ref 6a632e774973bcb3a23d6c3e --ref a.png
check "upload"     upload a.png
check "upload-url" upload-url https://example.com/a.jpg

# a code approves ONE exact operation
run generate --prompt "a mug" --count 1; C="$(code_of)"
run generate --prompt "a mug" --count 4 --confirm "$C"
if [ "$RC" -eq 3 ] && [ "$(calls)" -eq 0 ]; then ok "changed count invalidates the code"; else bad "changed count" "rc=$RC calls=$(calls)"; fi
run generate --prompt "a mug" --count 1; C="$(code_of)"
run edit --prompt "a mug" --ref a.png --confirm "$C"
if [ "$RC" -eq 3 ] && [ "$(calls)" -eq 0 ]; then ok "a generate code does not authorize an edit"; else bad "op binding" "rc=$RC calls=$(calls)"; fi
run edit --prompt "swap" --ref a.png; C="$(code_of)"
printf 'png-two' > "$WORK/a.png"
run edit --prompt "swap" --ref a.png --confirm "$C"
if [ "$RC" -eq 3 ] && [ "$(calls)" -eq 0 ]; then ok "swapped reference file invalidates the code"; else bad "file swap" "rc=$RC calls=$(calls)"; fi

# reads are not gated
run usage
if [ "$RC" -eq 0 ] && [ "$(calls)" -gt 0 ]; then ok "reads run without a code"; else bad "reads" "rc=$RC calls=$(calls)"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
