# Detecting system/base packages without snapshotting every installed package

<!-- markdownlint-disable MD013 -->

Date: 2026-07-19

## Recommendation

Stop persisting the complete onboarding inventory as hidden/system packages.

Package managers generally record **why a package is retained**—explicit request, dependency, group/profile, or unknown—not **whether it originally came with the operating system**. Installer-selected roots and packages deliberately installed later can therefore have the same `manual`/`explicit`/`userinstalled` marker.

Omni should instead build a compact desired-state set:

1. Omit packages marked dependency/automatic by the provider. Reinstalling their roots will restore them.
2. Omit recognized OS base/profile roots and their dependency closure.
3. Keep explicit/manual roots outside those base/profile closures.
4. Keep or review packages whose reason is external/unknown; never silently classify them as system packages.
5. Persist only user overrides and, if needed, compact detected profile identifiers—not every omitted package.

This changes the problem from the impossible question “who installed this package years ago?” to the useful question “which roots are required to recreate the user's environment?”

## Important distinction

These are separate dimensions and should not be collapsed into one `system` boolean:

```text
intent:     dependency | explicit | group/profile | external | unknown
role:       essential/protected | base/profile | ordinary
origin:     OS repository | third-party repository | local | unknown
management: omni | other | unknown
```

- `explicit` means “retain this package as a root,” not “a human chose it after OS installation.”
- `essential` or `base/profile` describes the package's role in a distribution, not its install reason.
- repository/vendor identifies where a package build came from, not why it was installed.
- leaves and orphans describe the current dependency graph, not provenance.

The current Omni provider queries already expose desired/retention roots for apt, DNF, pacman, apk, and zypper. The missing step is subtracting installer/base roots from those roots, not replacing the provider queries with a larger inventory.

## Recommended decision model

Use ordered evidence, not a score whose meaning becomes impossible to explain:

```text
if package is explicitly managed by Omni or explicitly included by the user:
    include
else if provider reason is dependency/automatic/weak-dependency:
    omit as derived dependency
else if package is essential/protected base content:
    omit as system base
else if package is in the closure of a recognized installed OS product/profile root:
    omit as profile expansion
else if provider reason is explicit/manual/user/world:
    include as a portable root
else:
    keep visible for review; default to include
```

Defaulting uncertain roots to include is intentional. A false “system” classification silently loses a tool on restore; a false “user” classification only adds some configuration noise.

Do not mutate provider metadata to make classification easier. Commands such as `apt-mark minimize-manual`, `pacman -D --asdeps`, `brew tab`, and `dnf5 mark` change package-manager behavior and must not be run during discovery.

## Provider-specific evidence

### Homebrew

Best portable roots:

```sh
brew list --installed-on-request
```

Homebrew directly exposes installed-on-request versus dependency state, and `brew leaves` can additionally restrict results to packages not required by another installed formula or cask. Its `tab` command can change this state, confirming that the marker is retention intent rather than immutable provenance. Homebrew's install receipt is stored per keg as `INSTALL_RECEIPT.json`. [Homebrew manpage](https://docs.brew.sh/Manpage), [Homebrew formula terminology](https://docs.brew.sh/Formula-Cookbook#homebrew-terminology)

Classification:

- Omit `--no-installed-on-request` packages as dependencies.
- Include installed-on-request formulae and casks.
- Treat a third-party tap as supporting user-intent evidence, but do not treat `homebrew/core` as system evidence.
- There is no macOS base closure to subtract from Homebrew: Homebrew content lives outside Apple's sealed OS and is not part of the macOS system volume.

On modern macOS, Apple separates and signs system content; user/third-party writable locations include `/Applications`, `/Library`, and `/usr/local`. This is a stronger boundary for Apple OS content than installer receipt names or onboarding timestamps. [Apple Platform Security: signed system volume](https://support.apple.com/guide/security/signed-system-volume-security-secd698747c9/web), [Apple System Integrity Protection](https://support.apple.com/en-us/102149)

Limitations:

- The installed-on-request marker can be edited with `brew tab`.
- A copied Homebrew prefix carries its receipts and therefore carries the old machine's retention decisions.
- A missing or old receipt should become `unknown`, not “dependency.”
- Install/upgrade time is weak evidence because upgrades create new kegs/receipts.

### apt/dpkg

Best intent signal:

```sh
apt-mark showmanual
apt-mark showauto
```

APT marks explicitly requested packages manual and their dependencies automatic. `minimize-manual` exists specifically to turn transitive dependencies of metapackages back into automatic packages after installation, demonstrating why `manual` alone is not OS provenance. Automatic state is stored separately in APT's `extended_states`. [apt-mark(8)](https://manpages.debian.org/unstable/apt/apt-mark.8.en.html)

Best base-role signals:

```sh
dpkg-query -W -f='${binary:Package}\t${Essential}\t${Priority}\n'
```

- `Essential: yes` is strong base-system evidence.
- priorities `required` and `important` are strong default/base evidence.
- `standard` is useful but weaker: Debian defines it as the default reasonably small command-line system.
- installed distribution metapackages/tasks can act as compact profile roots; compute their dependency closure dynamically rather than shipping a versioned list.

Debian Policy defines `Essential` as the minimal functionality that must always be available, and defines package priorities specifically to control minimal/default installations. [Debian Policy: essential packages](https://www.debian.org/doc/debian-policy/ch-binary.html#essential-packages), [Debian Policy: priorities](https://www.debian.org/doc/debian-policy/ch-archive.html#priorities)

Limitations:

- An installer can leave ordinary packages manual.
- Different Debian/Ubuntu variants and selected tasks have different initial roots.
- If `/var/lib/apt/extended_states` is missing after an import/recovery, auto/manual intent is incomplete.
- `/var/log/dpkg.log` is transaction evidence, not durable provenance; it is a normal log and logs may be rotated or removed. [dpkg(1) files](https://manpages.debian.org/trixie/dpkg/dpkg.1.en.html#FILES), [logrotate behavior](https://manpages.debian.org/trixie/logrotate/logrotate.conf.5.en.html)

### DNF/RPM

DNF5 has the richest reason model:

```text
user | dependency | weak dependency | group | external
```

It separately tracks installed groups and environments. `external` means another tool such as `rpm` installed the package; it does not mean the user deliberately wants the package in Omni. DNF5 also documents that rebuilding corrupted system state can lose install reasons and repository data. [DNF5 system state](https://dnf5.readthedocs.io/en/latest/misc/system-state.7.html)

Classification:

- Omit `dependency` and `weak dependency`.
- Include ordinary `user` roots.
- Treat installed OS environment/group membership as profile evidence. Prefer retaining a compact group/environment identity if Omni ever supports it; otherwise omit its package expansion from the portable package list.
- Review `external` rather than hiding it.
- With DNF4, `repoquery --userinstalled` is useful but less expressive; treat results as candidate roots, then subtract recognized base/group content. [DNF release notes for `--userinstalled`](https://dnf.readthedocs.io/en/stable/release_notes.html)

Protected and install-only packages are safety signals, not a complete OS manifest. DNF documents protected package configuration and that install-only packages such as kernels are exempt from autoremove. [DNF configuration reference](https://dnf.readthedocs.io/en/stable/conf_ref.html), [DNF5 autoremove](https://manpages.opensuse.org/Tumbleweed/dnf5/dnf5-autoremove.8.en.html)

RPM tags such as vendor, repository, and install time are corroborating evidence only. An official Fedora package can be intentionally installed by the user; a package's install time can be rewritten by an upgrade/reinstall. [RPM tag reference](https://rpm-software-management.github.io/rpm/manual/tags.html)

### pacman

Best intent signals:

```sh
pacman -Qe   # explicit roots
pacman -Qd   # dependency installs
pacman -Qm   # foreign packages
```

Pacman stores an explicit/dependency install reason and allows it to be changed with `--asexplicit`/`--asdeps`. A foreign package (`-Qm`) strengthens user-intent evidence but is not required for user intent. [pacman(8)](https://man.archlinux.org/man/pacman.8.en)

Base detection:

- `pacstrap` installs the `base` metapackage by default on a new system.
- Treat the installed `base` root and its dependency closure as system/base content.
- Kernel, firmware, bootloader, and role-specific initial roots remain variant-dependent and may need one-time review or a detected installation profile.

[pacstrap(8)](https://man.archlinux.org/man/pacstrap.8)

Limitations:

- `base`, kernel, and firmware are explicit roots, just like later user packages.
- Arch package groups are repository membership, not a durable receipt proving an installation profile.
- `/var/log/pacman.log` is useful supporting evidence, but it is configurable and may be absent after import. [pacman.conf(5)](https://man.archlinux.org/man/pacman.conf.5.en)
- Leaves/orphans only describe current dependencies; an explicit base root can also be a leaf.

### apk

Best intent and desired-state source:

```sh
cat /etc/apk/world
```

`/etc/apk/world` is already the compact desired system state: `apk add` and `apk del` add/remove constraints there, while dependencies are solver-derived. It may contain package constraints, virtual names, repository tags, pins, and negative constraints—not just plain package names. [Alpine package management: world](https://wiki.alpinelinux.org/wiki/Alpine_Linux_package_management#World)

Classification:

- Treat world entries as roots, not the entire installed database.
- Recognize `alpine-base` and platform roots such as kernel/boot packages as base/profile roots; omit their dependency closure.
- Include remaining ordinary world roots.
- Preserve constraint syntax if Omni serializes world semantics; reducing entries to bare package names can change resolution.

Alpine documents `alpine-base` as sufficient for a working base system, while actual installation modes can add kernel, boot, SSH, or time-sync roots. [Alpine bootstrapping](https://wiki.alpinelinux.org/wiki/Bootstrapping_Alpine_Linux), [Alpine installation overview](https://wiki.alpinelinux.org/wiki/Alpine_Linux%3AOverview)

Limitations:

- There is no separate “human” bit inside world; base and user roots coexist.
- Imported systems without the original world file have lost the strongest intent source.
- Minimal container images may not use the same root set as a normal `alpine-base` installation.

### zypper/libzypp

Best intent signals:

```sh
zypper packages --userinstalled
zypper packages --autoinstalled
zypper products -i
zypper patterns -i
```

Zypper distinguishes user-requested (`i+`) packages from solver-selected automatic (`i`) packages and exposes installed products and patterns. [zypper(8)](https://manpages.opensuse.org/Leap-16.0/zypper/zypper.8.en.html)

Classification:

- Omit automatic packages.
- Use installed base products/patterns as profile roots and omit their package closure.
- Include ordinary user-installed roots outside those closures.
- Review orphaned/unneeded results; they are lifecycle state, not provenance.

Important naming trap: `zypper packages --system` means installed packages not provided by any currently configured repository. It does **not** mean OS/base packages. It must not be used as Omni's `system` marker. [zypper system-package definition](https://manpages.opensuse.org/Leap-15.6/zypper/zypper.8.en.html#System_Packages)

Zypper keeps installation history in `/var/log/zypp/history` and supports transaction userdata, but this remains supporting evidence rather than a durable desired-state source. [zypper files and transaction userdata](https://manpages.opensuse.org/Leap-16.0/zypper/zypper.8.en.html)

## History, receipts, timestamps, and repository origin

Use these only to explain or break ties:

| Signal | Value | Why it is insufficient alone |
| --- | --- | --- |
| Provider install reason | Strong | Records retention intent, not whether the OS installer or a later human selected the root. |
| Essential/base/profile membership | Strong | Identifies system role, but profiles vary and can be user-installed later. |
| Omni's own install ledger | Strongest user evidence | Only applies after Omni begins recording its own actions. |
| Third-party/local origin | Medium positive user evidence | Often intentional, but may be installed by corporate images or automation. |
| Official OS repository/vendor | Almost no negative evidence | Users intentionally install official packages all the time. |
| Transaction history/command/user ID | Medium when complete | Logs/history may rotate, be pruned, or disappear during machine import; root/automation can represent either OS setup or user intent. |
| Install timestamp | Low | Upgrades/reinstalls can replace it; cloned images produce misleading clusters. |
| Leaf/orphan status | Low | Describes current graph reachability, not origin or user intent. |
| Present at onboarding | None | Most onboarding happens on established systems. |

DNF5's history is a good example of appropriate supporting data: it records command line, user, repository, action, and reason, but the durable current reason still lives in separate system state. [DNF5 history](https://dnf5.readthedocs.io/en/latest/commands/history.8.html)

## OS/image and container baselines

An exact base-image subtraction is excellent when an authenticated baseline is actually available; it should not become a maintained Omni list.

- `os-release` can expose `BUILD_ID`, `IMAGE_ID`, and `IMAGE_VERSION` for image-managed systems, but these fields are optional and explicitly may be absent on package-managed systems. They identify an image; they do not enumerate its packages. [os-release(5)](https://man.archlinux.org/man/core/systemd/os-release.5.en)
- A build-time SBOM can enumerate image contents, and provenance can identify the base image. Use an attached/verified SBOM plus image digest when the container runtime supplies them. [Docker SBOM attestations](https://docs.docker.com/build/metadata/attestations/sbom/), [Docker base-image provenance requirements](https://docs.docker.com/scout/policy/#no-base-image-data)
- Without provenance/attestation, inferring a container's original base from the live package database is not reliable. OCI image layers/history describe filesystem construction, not user package intent. [OCI image specification](https://github.com/opencontainers/image-spec/blob/main/config.md)

Recommended order for base evidence:

1. Verified image SBOM/base digest, when available.
2. Installed provider product/environment/pattern/metapackage closure.
3. Distro-defined essential/base metadata.
4. Versioned heuristic lists only as a last resort—and preferably never.

Static lists are costly and become wrong across OS releases, installation variants, OEM images, containers, and distribution upgrades. Dynamic closure from installed roots follows the actual machine and provider metadata.

## Imported machines and upgrades

Normal upgrades usually preserve provider intent metadata, but no adapter should assume it is complete:

- copied Homebrew kegs preserve their receipts;
- copied pacman local databases preserve explicit/dependency reason;
- copied `/etc/apk/world` preserves desired constraints;
- apt auto state, DNF system state, and libzypp auto state are separate from the underlying dpkg/RPM package database and can be omitted by partial imports or recovery tooling;
- DNF5 explicitly warns regenerated state may lack reason and repository data;
- provider commands allow reasons to be manually changed.

Therefore every adapter needs an `unknown` state. Missing metadata must not silently fall back to `system` or to onboarding-time presence.

## Confidence and risk table

| Evidence/result | Classification | Confidence | Main risk |
| --- | --- | ---: | --- |
| Omni recorded the user's install/include decision | user root | High | Local ledger was copied from another owner/machine. |
| Native dependency/auto/weak-dependency reason | derived; omit | High | User deliberately promoted or directly uses a dependency without marking it explicit. |
| Distro Essential or exact verified base-image membership | system/base; omit | High | Target restore uses a materially different distro/image profile. |
| Closure of detected base metapackage/product/environment/pattern | system/profile; omit | High–medium | The profile was added later by the user and should itself be represented as desired state. |
| Explicit/manual/world/userinstalled outside base closure | user root; include | Medium–high | OS installer selected an ordinary package as a root. |
| Group/profile reason without identifiable profile | review | Medium | Hiding may lose a deliberately selected desktop/server role. |
| Third-party repo/tap or foreign/local package | user root; include | Medium | Corporate/OEM provisioning installed it. |
| External/unknown reason | review; default include | Low | Adds config noise, but hiding risks data loss. |
| History/timestamp/leaf/onboarding presence only | do not classify | Low/none | Frequent false positives after upgrade, import, log rotation, or mature-system onboarding. |

## Minimal persistence model

Do not add a large classifier snapshot to the shared config.

**Shared config:** only portable desired package/profile roots, plus small user-authored include/exclude rules that the user explicitly wants to follow them across machines. Never auto-write the detected system/base inventory here.

**Local DB/state:** classifier version, detected OS/provider/profile identity, explicit Omni install/remove provenance, and host-specific review decisions. Provider reason and dependency evidence should normally be recomputed; cache it locally only for performance or auditability.

The minimum local durable state is:

```text
classifier_version
detected_profile_ids     # only when needed and stable
explicit_include_overrides
explicit_exclude_overrides
omni_managed_roots
```

Provider evidence should be recomputed read-only when scanning. Omni's own future install/remove actions can be recorded in the local provenance ledger, which becomes the strongest signal for packages Omni actually managed.

If a provider profile is meaningful desired state—Fedora environment, SUSE pattern, Alpine world constraint—represent that root directly when the configuration model supports it. Do not expand it into hundreds of package names merely to hide them again.

## Validation cases

Each provider adapter should be checked with small package-graph fixtures or disposable images:

1. fresh minimal/default installation;
2. default installation plus one explicit user tool and its dependencies;
3. explicit package that is also depended on by another root;
4. base/product/profile installation;
5. third-party/local package;
6. imported package database with reason metadata missing;
7. distribution upgrade with renamed/replaced packages;
8. container with verified base SBOM, and the same container without attestations.

The invariant is simple: restoring the selected roots on the same provider/profile must recreate all omitted dependencies, while no uncertain explicit root disappears silently.

## Final decision

Implement provider-specific **root classification**, not package-by-package “system provenance.”

- Reuse the existing manual/user-requested provider queries.
- Add provider base/profile detection and dependency closure.
- Preserve `unknown` and default it to visible/include.
- Store only overrides/profile identity, not the hidden inventory.
- Treat history, vendor, repository, timestamps, and leaves as explanation signals only.

There is no universally correct way to reconstruct original OS ownership on a mature or imported machine. The compact root model is both smaller and more correct because it aligns with what package managers can actually prove.
