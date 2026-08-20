#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/config/omarchy/signal"
printf '{"organization":"acme","baseUrl":"https://sentry.example"}\n' >"$tmp/config/omarchy/signal/config.json"

cat >"$tmp/bin/secret-tool" <<'EOF'
#!/usr/bin/env bash
printf '%s' "${MOCK_TOKEN:-test-token}"
EOF
cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
out=
headers=
while (($#)); do
  case "$1" in
    -o) out=$2; shift 2 ;;
    -D) headers=$2; shift 2 ;;
    *) shift ;;
  esac
done
printf 'HTTP/2 %s\r\nx-sentry-rate-limit-limit: 40\r\nx-sentry-rate-limit-remaining: 2\r\nx-sentry-rate-limit-reset: 2000000000\r\n\r\n' "${MOCK_STATUS:-200}" >"$headers"
if [[ ${MOCK_STATUS:-200} == 200 ]]; then printf '[]\n' >"$out"; else printf '{"detail":"mock failure"}\n' >"$out"; fi
printf '%s' "${MOCK_STATUS:-200}"
EOF
chmod +x "$tmp/bin/secret-tool" "$tmp/bin/curl"

run_api() {
  PATH="$tmp/bin:$PATH" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" "$root/scripts/signal-api" "$@"
}

ready=$(run_api --environment production)
jq -e '.state == "ready" and .rateLimit.remaining == 2 and .rateLimit.limit == 40' <<<"$ready" >/dev/null

limited=$(MOCK_STATUS=429 run_api --environment production)
jq -e '.state == "ready" and .stale == true and (.message | contains("rate-limited"))' <<<"$limited" >/dev/null

unavailable=$(MOCK_STATUS=503 run_api --environment production)
jq -e '.state == "ready" and .stale == true and (.message | contains("temporarily unavailable"))' <<<"$unavailable" >/dev/null

auth=$(MOCK_STATUS=401 run_api --environment staging || true)
jq -e '.state == "error" and (.message | contains("rejected the token"))' <<<"$auth" >/dev/null

permission=$(MOCK_STATUS=403 run_api --action resolve --issue 12 || true)
jq -e '.state == "error" and (.message | contains("lacks permission"))' <<<"$permission" >/dev/null

invalid_token=$(MOCK_TOKEN='bad token' run_api || true)
jq -e '.state == "error" and (.message | contains("invalid format"))' <<<"$invalid_token" >/dev/null

invalid_limit=$(run_api --limit 1000 || true)
jq -e '.state == "error" and (.message | contains("Issue limit"))' <<<"$invalid_limit" >/dev/null

invalid_sort=$(run_api --sort random || true)
jq -e '.state == "error" and (.message | contains("sort order"))' <<<"$invalid_sort" >/dev/null

for invalid_origin in 'https://user@example.com' 'https://example.com/path' 'https://example.com?query' 'https://example.com:70000' 'https://-bad.example' 'https://bad..example'; do
  printf '{"organization":"acme","baseUrl":"%s"}\n' "$invalid_origin" >"$tmp/config/omarchy/signal/config.json"
  invalid=$(run_api || true)
  jq -e '.state == "error" and (.message | contains("invalid Sentry URL"))' <<<"$invalid" >/dev/null
done

printf 'backend error tests passed\n'
