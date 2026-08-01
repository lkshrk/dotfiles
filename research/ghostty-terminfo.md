# Ghostty terminfo on a remote Linux/Coder host

## Conclusions

- `~/.terminfo` is a supported ncurses user database. Ncurses searches `TERMINFO`, then `$HOME/.terminfo`, then `TERMINFO_DIRS`, then compiled-in/system locations. `tic -o "$HOME/.terminfo"` is the explicit, deterministic way to install there. The one caveat is that `$HOME/.terminfo` support can be omitted or restricted by an ncurses build, especially for privileged programs. [ncurses `terminfo(5)`](https://invisible-island.net/ncurses/man/terminfo.5.html#h3-Fetching-Compiled-Descriptions), [ncurses `tic(1m)`](https://invisible-island.net/ncurses/man/tic.1m.html)
- The shell does not matter. Terminfo lookup is performed by ncurses using the process environment and database paths; Bash versus Zsh does not change it. The relevant identity is the user running the TUI and that process's `HOME`/`TERMINFO`. Install as `coder` into `/home/coder/.terminfo` for `coder`; install system-wide only when other users or `sudo` also need it. Ghostty separately documents that `sudo` may discard `TERMINFO`. [ncurses `terminfo(5)`](https://invisible-island.net/ncurses/man/terminfo.5.html#h3-Fetching-Compiled-Descriptions), [Ghostty terminfo help](https://ghostty.org/docs/help/terminfo#sudo)
- Ghostty's documented remote install is:

  ```sh
  infocmp -x xterm-ghostty | ssh YOUR-SERVER -- tic -x -
  ```

  Ghostty says `tic` normally targets `/usr/share/terminfo`, but falls back to `$HOME/.terminfo` when that directory exists and the system database is not writable. A setup script should be more explicit:

  ```sh
  mkdir -p "$HOME/.terminfo"
  tic -x -o "$HOME/.terminfo" /path/to/xterm-ghostty.terminfo
  TERMINFO="$HOME/.terminfo" infocmp -x xterm-ghostty >/dev/null
  ```

  [Ghostty terminfo help](https://ghostty.org/docs/help/terminfo#ssh), [ncurses `tic(1m)`](https://invisible-island.net/ncurses/man/tic.1m.html)
- Do not run `tic` with `sudo` for a user-local install. That changes the effective user/environment and can install for root or system-wide. User-local installation needs no root privileges.
- `xterm-ghostty` is included system-wide only in ncurses `6.5-20241228` and newer, so older Linux images legitimately need the extra entry. [Ghostty terminfo help](https://ghostty.org/docs/help/terminfo)

## Robust setup behavior

1. First accept an existing entry:

   ```sh
   infocmp -x xterm-ghostty >/dev/null 2>&1
   ```

2. If missing and `tic` exists, compile a committed text-format terminfo source into the invoking user's `~/.terminfo`, then verify with `TERMINFO="$HOME/.terminfo" infocmp -x xterm-ghostty`. This is independent of the login shell and apt.
3. If `tic` is missing, a package-manager attempt may install it, but it must be serialized with other apt/dpkg work. The terminfo step itself should not depend on apt succeeding: report the missing compiler and use the fallback below.
4. If `tic` cannot be obtained, Ghostty's own behavior is to fall back to `TERM=xterm-256color`; Ghostty documents that this preserves broad compatibility but loses Ghostty-only capabilities such as styled/colored underlines. `ghostty +ssh` performs exactly this fallback when remote installation fails. [Ghostty SSH feature](https://ghostty.org/docs/features/ssh#terminfo-install), [Ghostty terminfo help](https://ghostty.org/docs/help/terminfo#ssh)
5. Do not make copying an arbitrary precompiled binary entry the primary fallback. Ncurses documents that compiled terminfo portability across Unix implementations is not guaranteed; text source compiled by the target's `tic` is the robust format. [ncurses `term(5)`](https://invisible-island.net/ncurses/man/term.5.html#h3-Binary-Format)

Ghostty can also automate the install through `ghostty +ssh` or `shell-integration-features = ssh-env,ssh-terminfo`. The shell wrapper affects how SSH is invoked, not whether an already-installed `~/.terminfo` entry works; Ghostty notes that the wrapper is absent from scripts, non-interactive shells, and tools that invoke `ssh` directly. [Ghostty SSH feature](https://ghostty.org/docs/features/ssh)

## Current repository finding

The current setup logic in `scripts/setup-coder-linux.sh` is conceptually correct: it installs as the current user with `tic -x -o "$HOME/.terminfo"`. It does not run because its required source file is absent:

```text
assets/terminfo/xterm-ghostty.terminfo
```

The function therefore takes its `"Ghostty terminfo source missing; continuing setup"` branch. `tests/coder-ghostty-terminfo.sh` also fails because no `tic` invocation occurs. This is the immediate cause; it is not a Bash/Zsh or user-install-location problem.

The missing source can be generated on this Mac from Ghostty's installed entry with the same official export mechanism:

```sh
infocmp -x xterm-ghostty > assets/terminfo/xterm-ghostty.terminfo
```

Ghostty's authoritative built-in definition is maintained in [`src/terminfo/ghostty.zig`](https://github.com/ghostty-org/ghostty/blob/main/src/terminfo/ghostty.zig); the exported text should be treated as a pinned generated asset and refreshed deliberately when Ghostty's entry changes.
