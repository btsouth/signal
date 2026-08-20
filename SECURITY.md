# Security policy

## Supported version

Security fixes are provided for the latest Signal release.

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability. Use GitHub's **Report a vulnerability** link in this repository's Security tab so credentials, reproduction details, and affected data remain private.

Include the Signal version, Omarchy version, expected behavior, observed behavior, and the smallest safe reproduction you can provide. Do not include a live Sentry token, DSN secret, incident payload, or customer data.

You should receive an acknowledgement within 72 hours. Confirmed issues will be coordinated privately until a fix is available.

## Credential reminder

Signal stores Sentry tokens in Secret Service, not repository or plugin files. If you believe a token was exposed, revoke it in Sentry immediately; do not wait for the vulnerability review.
