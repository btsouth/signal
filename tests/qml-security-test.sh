#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
qml="$root/Signal.qml"

# Every Text owned by Signal must explicitly opt out of QML's rich-text auto
# detection. Shared shell components must receive only plugin-authored strings.
text_blocks=$(grep -Ec '(^|[[:space:]])Text \{' "$qml")
plain_blocks=$(grep -c 'textFormat: Text.PlainText' "$qml")
[[ $text_blocks == "$plain_blocks" ]] || {
  printf 'every Signal Text block must use Text.PlainText (%s Text, %s plain)\n' "$text_blocks" "$plain_blocks" >&2
  exit 1
}
! grep -Eq 'confirmDialog\.message.*issue\.' "$qml"
! grep -Eq 'meta:.*signal\.message' "$qml"
! grep -Eq 'text: modelData === "all"' "$qml"

printf 'QML security tests passed\n'
