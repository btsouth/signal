#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/config/omarchy/signal"
printf '{"organization":"acme","baseUrl":"https://sentry.example"}\n' >"$tmp/config/omarchy/signal/config.json"

cat >"$tmp/bin/secret-tool" <<'EOF'
#!/usr/bin/env bash
printf 'test-token'
EOF
cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
out=
while (($#)); do
  if [[ $1 == -o ]]; then out=$2; shift 2; else shift; fi
done
printf '[{"id":"12","shortId":"WEB-12","title":"Boom","level":"error","status":"unresolved","count":"4","userCount":2,"project":{"slug":"web"}}]\n' >"$out"
printf '200'
EOF
chmod +x "$tmp/bin/secret-tool" "$tmp/bin/curl"

result=$(PATH="$tmp/bin:$PATH" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" "$root/scripts/signal-api" --environment production)
jq -e '.state == "ready" and .organization == "acme" and .issues[0].shortId == "WEB-12"' <<<"$result" >/dev/null

cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
chmod +x "$tmp/bin/curl"
stale=$(PATH="$tmp/bin:$PATH" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" "$root/scripts/signal-api" --environment production)
jq -e '.state == "ready" and .stale == true and .issues[0].shortId == "WEB-12"' <<<"$stale" >/dev/null

demo=$("$root/scripts/signal-api" --demo)
jq -e '.state == "ready" and .demo == true and (.issues | length) == 3' <<<"$demo" >/dev/null

unset_result=$(XDG_CONFIG_HOME="$tmp/missing" "$root/scripts/signal-api")
jq -e '.state == "setup"' <<<"$unset_result" >/dev/null

printf 'backend tests passed\n'
