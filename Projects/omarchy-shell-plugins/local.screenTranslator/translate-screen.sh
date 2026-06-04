#!/usr/bin/env bash
set -euo pipefail

image_path="${1:-}"
target_language="${2:-en}"

if [[ -z "$image_path" || ! -f "$image_path" ]]; then
  echo "Screenshot image not found." >&2
  exit 2
fi

if [[ -n "${SCREEN_TRANSLATOR_COMMAND:-}" ]]; then
  cmd="${SCREEN_TRANSLATOR_COMMAND//\{image\}/$image_path}"
  cmd="${cmd//\{target\}/$target_language}"
  bash -lc "$cmd"
  exit $?
fi

if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  model="${GEMINI_MODEL:-gemini-2.5-flash}"
  mime="image/png"
  image_b64="$(base64 -w 0 "$image_path")"
  prompt="Find only non-English text visible in this screenshot. For each coherent text block, return a JSON object with x, y, width, height, text, and translation fields. x/y/width/height must be pixel coordinates in the screenshot. translation must be concise English unless the requested target language is different: ${target_language}. Return ONLY a JSON array. If there are no non-English text blocks, return []."

  payload="$(jq -n \
    --arg prompt "$prompt" \
    --arg mime "$mime" \
    --arg data "$image_b64" \
    '{
      contents: [{
        parts: [
          { text: $prompt },
          { inline_data: { mime_type: $mime, data: $data } }
        ]
      }],
      generationConfig: {
        temperature: 0,
        responseMimeType: "application/json"
      }
    }')"

  curl -fsS "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent" \
    -H "x-goog-api-key: ${GEMINI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    | jq -r '.candidates[0].content.parts[0].text // "[]"'
  exit 0
fi

if command -v tesseract >/dev/null 2>&1; then
  ocr_text="$(tesseract "$image_path" stdout 2>/dev/null | sed '/^[[:space:]]*$/d' || true)"
  if [[ -z "$ocr_text" ]]; then
    echo "[]"
    exit 0
  fi

  if command -v trans >/dev/null 2>&1; then
    translated="$(printf '%s\n' "$ocr_text" | trans -brief ":${target_language}")"
  else
    translated="$ocr_text"
  fi
  jq -n --arg text "$ocr_text" --arg translation "$translated" \
    '[{x: 40, y: 40, width: 720, height: 220, text: $text, translation: $translation}]'
  exit 0
fi

cat >&2 <<'EOF'
No translator backend is configured.

Set GEMINI_API_KEY for image translation, or install tesseract plus translate-shell.
You can also set SCREEN_TRANSLATOR_COMMAND with {image} and {target} placeholders.
EOF
exit 1
