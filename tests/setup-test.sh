#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat >"$tmp/bin/secret-tool" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == store ]]; then
  read -r token
  printf '%s' "$token" >"${STORED_TOKEN_FILE:?}"
fi
EOF
cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
out=
while (($#)); do if [[ $1 == -o ]]; then out=$2; shift 2; else shift; fi; done
if [[ ${MOCK_STATUS:-200} == 200 ]]; then printf '[]\n' >"$out"; else printf '{"detail":"bad token"}\n' >"$out"; fi
printf '%s' "${MOCK_STATUS:-200}"
EOF
chmod +x "$tmp/bin/"*

run_setup() {
  printf '%s\n%s\n%s\n\n' 'acme' 'https://sentry.example' 'test-token' |
    PATH="$tmp/bin:$PATH" XDG_CONFIG_HOME="$tmp/config" STORED_TOKEN_FILE="$tmp/token" "$root/scripts/signal-setup"
}

MOCK_STATUS=401 run_setup >"$tmp/rejected-output" || true
[[ ! -e $tmp/config/omarchy/signal/config.json ]] || { printf 'rejected setup changed configuration\n' >&2; exit 1; }
[[ ! -e $tmp/token ]] || { printf 'rejected setup stored a credential\n' >&2; exit 1; }

MOCK_STATUS=200 run_setup >"$tmp/accepted-output"
jq -e '.organization == "acme" and .baseUrl == "https://sentry.example"' "$tmp/config/omarchy/signal/config.json" >/dev/null
[[ $(stat -c '%a' "$tmp/config/omarchy/signal/config.json") == 600 ]]
[[ $(<"$tmp/token") == test-token ]]
if grep -q 'test-token' "$tmp/accepted-output"; then printf 'setup echoed the credential\n' >&2; exit 1; fi

printf 'setup tests passed\n'
