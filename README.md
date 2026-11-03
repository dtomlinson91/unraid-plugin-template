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
| `BINARY_SRC` | `BINARY` | The file name in the archive or in the build, if it is not `BINARY`. A value with a `/` is the end of the path in the archive, for example `usr/bin/fastfetch`. |
| `INSTALL_DIR` | `/usr/local/bin` | The directory of the installed command. |
| `CARGO_ARGS` | | `cargo` only. More arguments for `cargo build`. |
| `VERSION_ARGS` | `--version` | The arguments that make the command print its version. |
| `VERSION_CHECK` | `yes` | Set to `no` if the version output does not contain the upstream version. |
| `TEST_CMD` | | A shell command to run after the test install. |
| `STATIC` | `yes` | Set to `no` to allow a dynamic binary. |

## Slackware packages for each Unraid base

Some tools have no static build, for example zsh. For these tools, the workflow `release-slackware.yml` repacks the official Slackware package. It makes one package for each Unraid base. The `.plg` installs the package for the running Unraid version, and it refuses other versions.

The plugin repo calls `release-slackware.yml` instead of `release.yml`. It has the inputs `force` and `dry_run`, but no `version`.

| Variable | Use |
|---|---|
| `NAME`, `TITLE` | The same as in `release.yml`. |
| `SLACK_PKG` | The Slackware package name, for example `zsh`. |
| `BINARY` | The full path of the command to test, for example `/bin/zsh`. |
| `BASES` | A bash array. Each line holds 4 fields: the Unraid version glob, the Slackware tree, the glibc version of that Unraid base, and the test image. |
| `UPSTREAM_URL` | The link in the release notes. |
| `MIRROR` | Optional. The Slackware mirror. The default is `https://slackware.osuosl.org`. |
| `VERSION_ARGS`, `TEST_CMD` | The same as in `release.yml`. |

```bash
BASES=(
  "6.12.* 15.0 2.37 aclemons/slackware:15.0"
  "7.3.* current 2.44 aclemons/slackware:current"
)
```

The workflow does these steps:

1. It finds the package of each base in `CHECKSUMS.md5` of the tree. A package in `patches/` comes before the main tree.
2. It stops if the `.plg` already has the same Slackware packages, unless `force` is true.
3. It downloads each package and checks the md5 and the GPG signature of the Slackware Linux Project.
4. It refuses a package that needs a newer glibc than its Unraid base has. The test images cannot find this problem, because `slackware:current` moves on after Unraid freezes its base.
5. It adds the README to each package and makes `<name>-<version>-x86_64-<plugin version>_<tree>.txz`.
6. It installs, runs and removes each package in the test image of its base.
7. It writes `<name>.plg` from `plugin-slackware.plg.tmpl`. The `.plg` downloads all packages to the flash drive, so the package for the next Unraid version is there before an OS update.

A new Unraid version needs a new line in `BASES`, then a release with `force`.

## Install a plugin

In the Unraid web UI, go to **Plugins > Install Plugin** and paste the URL of the `.plg`:

```
https://github.com/dtomlinson91/<name>/raw/main/<name>.plg
```

An old plugin with a version that starts with `v`, for example `v0.23.0`, sorts after a date. Update it from the shell with `plugin install <url> forced`.
