# Changelog

## 1.0.2 - 2026-10-08

- Colors work again on Qt 6.12. QtQuick now ships its own `Color` type, which hid the
  shell's `Color` palette and left colors undefined. The plugin reads it as
  `Commons.Color`, the same change Omarchy made for its own shell.

## 1.0.1 — 2026-08-21

- Render all remote Sentry fields as bounded plain text, including project filters and confirmations
- Cap API responses at 5 MiB and connection probes at 1 MiB
- Reject symbolic links in plugin-owned configuration, cache, and notification state paths
- Atomically replace notification baselines and validate HTTPS permalinks before opening them

## 1.0.0 — 2026-08-20

- Native bar inbox for unresolved Sentry issues
- Lifecycle, project, search, environment, and sort filtering
- Regression and escalation notifications with quiet baselining
- Resolve and Archive actions with confirmation
- Secret Service credential storage and stdin-only authorization headers
- Organization-scoped offline cache and rate-limit-aware errors
- Keyboard navigation, demo mode, and submission-ready preview assets
- Curl configuration isolation, strict HTTPS origins, transactional reconnects, and HTTPS-only issue links
- Origin-scoped caches with stale fallback for transport, rate-limit, and Sentry 5xx failures
- Keyboard-accessible filters, auto-scrolling selection, busy-state guards, and safe dialog cleanup
