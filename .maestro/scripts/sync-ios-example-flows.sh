#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC="$REPO_ROOT/.maestro/enrichedMarkdownText/flows"
DST="$REPO_ROOT/.maestro/iosExample/enrichedMarkdownText/flows"
NATIVE_APP_ID="swmansion.enriched.markdown.ios.example"

COMMONMARK_EXCLUDE=(
  table_test
  task_list_test
  math_display_test
  highlight_test
  spoiler_test
  strikethrough_test
  underline_test
  inline_math_test
  header_table_combo_test
  paragraph_table_combo_test
  list_table_combo_test
  table_image_combo_test
  code_block_math_combo_test
  paragraph_math_combo_test
  task_list_ordered_list_combo_test
  highlight_bold_combo_test
  highlight_italic_combo_test
  highlight_spoiler_combo_test
  highlight_strikethrough_combo_test
  highlight_underline_combo_test
)

should_exclude() {
  local base="$1"
  for excluded in "${COMMONMARK_EXCLUDE[@]}"; do
    if [ "$base" = "$excluded" ]; then
      return 0
    fi
  done
  return 1
}

rm -rf "$DST"
mkdir -p "$DST"

while IFS= read -r -d '' file; do
  base="$(basename "$file" .yaml)"
  if should_exclude "$base"; then
    continue
  fi

  rel="${file#$SRC/}"
  out="$DST/$rel"
  mkdir -p "$(dirname "$out")"
  sed "s/swmansion.enriched.markdown.example/$NATIVE_APP_ID/g" "$file" > "$out"
done < <(find "$SRC" -name '*.yaml' -print0)

count="$(find "$DST" -name '*.yaml' | wc -l | tr -d ' ')"
echo "Synced $count CommonMark flows to $DST"
