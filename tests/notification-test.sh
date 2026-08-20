#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/config/omarchy/signal"
printf '{"organization":"acme","baseUrl":"https://sentry.example"}\n' >"$tmp/config/omarchy/signal/config.json"
printf '[{"id":"1","substatus":"regressed"}]\n' >"$tmp/first.json"
printf '[{"id":"1","substatus":"regressed"},{"id":"2","substatus":"escalating"}]\n' >"$tmp/second.json"

cat >"$tmp/bin/secret-tool" <<'EOF'
#!/usr/bin/env bash
printf 'test-token'
EOF
cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
out=
while (($#)); do if [[ $1 == -o ]]; then out=$2; shift 2; else shift; fi; done
cp "${MOCK_BODY_FILE:?}" "$out"
printf '200'
EOF
cat >"$tmp/bin/omarchy-notification-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${NOTIFY_LOG:?}"
EOF
chmod +x "$tmp/bin/"*

run_fetch() {
  PATH="$tmp/bin:$PATH" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" NOTIFY_LOG="$tmp/notifications" "$root/scripts/signal-api" --environment production --notify-escalating
}

MOCK_BODY_FILE="$tmp/first.json" run_fetch >/dev/null
[[ ! -e $tmp/notifications ]] || { printf 'first refresh must establish a quiet baseline\n' >&2; exit 1; }

MOCK_BODY_FILE="$tmp/second.json" run_fetch >/dev/null
[[ $(wc -l <"$tmp/notifications") -eq 1 ]] || { printf 'new attention issue should notify once\n' >&2; exit 1; }

MOCK_BODY_FILE="$tmp/second.json" run_fetch >/dev/null
[[ $(wc -l <"$tmp/notifications") -eq 1 ]] || { printf 'unchanged attention issues must not notify again\n' >&2; exit 1; }

printf 'notification tests passed\n'
