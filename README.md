# unraid-plugin-template

A shared GitHub Actions workflow that builds and releases the `unraid-<name>` plugins of dtomlinson91.
Each plugin installs one static binary on Unraid. The binaries do not use the Unraid glibc, so one build runs on Unraid 6.9.2, 6.12 and 7.x.

## What the workflow does

1. It finds the upstream version: the `version` input, or the latest upstream release.
2. It stops if the `.plg` already has that version, unless `force` is true.
3. It gets the binary: a static release asset of the upstream project, a download URL, or a `cargo` build for the musl target.
4. It makes sure that the binary is a static x86-64 ELF file.
5. It makes the Slackware package with `makepkg` in a Slackware 14.2 container.
6. It installs the package, runs the binary and removes the package in Slackware 14.2 and Slackware current containers.
7. It writes `<name>.plg` from `plugin.plg.tmpl` and keeps the change history of the old `.plg`.
8. It commits the `.plg`, pushes the tag, creates the GitHub release and pushes the default branch.

With `dry_run: true`, the workflow stops after step 7 and keeps the package as a workflow artifact.

## Versions and names

- The plugin version is the release date, for example `2026.11.01`. A second release on the same day gets a letter: `2026.11.01a`. The Unraid plugin manager compares versions with `strcmp`, so a date sorts correctly and an upstream version such as `0.15.0` does not.
- The release tag is the plugin version.
- The package is `<name>-<upstream version>-x86_64-<plugin version>.txz`. The plugin manager does not download a file that already exists on the flash drive, so each release needs a new file name.
- The `.plg` holds the SHA256 of the package. The plugin manager checks it after a download. An inline script checks it again at each install and at each boot.

## A plugin repo

| File | Contents |
|---|---|
| `plugin.conf` | The settings of the plugin. See the table below. |
| `description.md` | The text for the Unraid Plugins page. The package installs it as `README.md`. |
| `.github/workflows/release.yml` | Calls the shared workflow. It runs every Monday and from the Actions tab. |
| `usr/` | Optional. Files to add to the package, for example the icon at `usr/local/emhttp/plugins/<name>/images/<name>.png`. |
| `<name>.plg` | Written by the workflow. Do not edit it. Change `plugin.plg.tmpl` in this repo. |

`plugin.conf` is a shell file:

| Variable | Default | Use |
|---|---|---|
| `NAME` | | The plugin name, for example `unraid-bat`. It is the same as the repo name. |
| `TITLE` | | The tool name for the Plugins page and the release title. |
| `UPSTREAM` | | The upstream GitHub repo, for example `sharkdp/bat`. |
| `BINARY` | | The name of the installed command. |
| `SOURCE` | `asset` | `asset`, `url` or `cargo`. |
| `ASSET` | | `asset` only. The release asset name. `{tag}` and `{version}` are replaced. |
| `URL` | | `url` only. The download URL. `{tag}` and `{version}` are replaced. |
| `LATEST_CMD` | | A shell command that prints the latest upstream tag. It replaces the GitHub latest release. |
| `UPSTREAM_URL` | the GitHub release | The link in the release notes. |
| `BINARY_SRC` | `BINARY` | The file name in the archive or in the build, if it is not `BINARY`. |
| `INSTALL_DIR` | `/usr/local/bin` | The directory of the installed command. |
| `CARGO_ARGS` | | `cargo` only. More arguments for `cargo build`. |
| `VERSION_ARGS` | `--version` | The arguments that make the command print its version. |
| `VERSION_CHECK` | `yes` | Set to `no` if the version output does not contain the upstream version. |
| `TEST_CMD` | | A shell command to run after the test install. |
| `STATIC` | `yes` | Set to `no` to allow a dynamic binary. |

## Install a plugin

In the Unraid web UI, go to **Plugins > Install Plugin** and paste the URL of the `.plg`:

```
https://github.com/dtomlinson91/<name>/raw/main/<name>.plg
```

An old plugin with a version that starts with `v`, for example `v0.23.0`, sorts after a date. Update it from the shell with `plugin install <url> forced`.
