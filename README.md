# Signal

**Your production app broke. Know before your users tell you.**

Signal is a quiet [Sentry](https://sentry.io/) incident inbox built for the Omarchy Quattro bar. When production is healthy, it stays out of the way. When an issue regresses, the bar wakes up and puts the useful evidence one click away.

![Signal showing a regressed checkout error, event volume, affected users, and its 24-hour trend](preview.png)

<p align="center">
  <img src="demo.gif" alt="Keyboard navigation through a live Signal incident inbox" width="465">
</p>

## What it does

- Shows unresolved Sentry issues ordered by regression, severity, and recency
- Calls out regressions without turning every old issue into an alarm
- Summarizes event volume and affected users
- Draws a 24-hour event sparkline for each issue
- Filters the inbox by project
- Opens the full issue in Sentry
- Resolves or ignores the selected issue from the panel
- Works entirely from the keyboard: arrows, Enter, `X`, `I`, and `R`
- Includes a deterministic demo feed for screenshots and evaluation

Signal talks directly to Sentry with `curl`; it installs no daemon, runtime, or package. The normal refresh interval is five minutes, and opening the panel triggers an immediate refresh.

## Install

```bash
omarchy plugin add https://github.com/tsouth89/signal.git --enable
```

The public repository does not exist yet. During development, add this checkout by absolute path.

## Connect Sentry

Open Signal and choose **Connect Sentry**. The setup terminal asks for:

1. Your organization slug
2. Your Sentry origin (`https://sentry.io` unless self-hosted)
3. An authentication token

Recommended token scopes:

- `org:read`
- `project:read`
- `event:read`
- `event:write` for Resolve and Ignore

The token is written to Secret Service through `secret-tool`; it is never stored in the plugin directory or passed on a process command line. The organization and base URL are stored in `~/.config/omarchy/signal/config.json` with user-only permissions.

## Keyboard controls

| Key | Action |
| --- | --- |
| `↑` / `↓` | Select an issue |
| `Enter` | Open the issue in Sentry |
| `X` | Resolve the selected issue |
| `I` | Ignore the selected issue |
| `R` | Refresh |
| `Esc` | Close Signal |

Right-click the bar icon to refresh without opening the panel.

## Demo mode

Enable **Use demonstration data** in the bar-widget settings to display three realistic incidents without a Sentry account or network request. Actions are intentionally disabled in demo mode.

## Privacy and security

- No telemetry
- No privileged commands
- No install hooks
- No token in configuration files, logs, command arguments, or QML state
- Network requests go only to the configured HTTPS Sentry origin
- Organization slugs, issue IDs, and origins are validated before use
- API requests time out rather than accumulating in the shell

Community plugins execute unsandboxed inside `omarchy-shell`; inspect the source before enabling any plugin.

## Development

```bash
tests/run.sh
omarchy plugin validate .
```

The backend tests replace `curl` and Secret Service with local fakes. They never contact Sentry or mutate an account.

## Known limits

- Signal currently uses token authentication rather than browser OAuth.
- A first successful refresh establishes the regression baseline and does not notify; later newly regressed issue IDs trigger one aggregate notification.
- Sentry self-hosted installations must use an HTTPS origin without a path prefix.

## License

MIT
