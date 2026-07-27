# Herdr outer-window title plugins

| Plugin | Approach | Title behavior and limits |
| --- | --- | --- |
| [`rjyo/herdr-window-title-sync`](https://github.com/rjyo/herdr-window-title-sync) | Bun; macOS and Linux | Reads Codex and Claude JSONL state and can derive agent, prompt, tab, and workspace data. The output format is hardcoded. |
| [`paulrobello/par-herdr-plugins/terminal-title-sync`](https://github.com/paulrobello/par-herdr-plugins/tree/main/plugins/terminal-title-sync) | Bun; privacy-focused | Chooses the first available value in the order agent title → tab → workspace → agent. The output format is hardcoded. |
| [`filoozom/herdr-title`](https://github.com/filoozom/herdr-title) | Prebuilt Rust binary; no runtime dependencies; Herdr ≥ 0.7.5 | Shows worktree/workspace, activity, and optionally hostname. Configuration is boolean-only, so it cannot express an arbitrary format. The locally installed Herdr is 0.7.4, so this also requires an upgrade. |
| [`mikevalstar/herdr-machine-title`](https://github.com/mikevalstar/herdr-machine-title) | POSIX shell; `jq` optional | Emits the hardcoded form `herdr@host · workspace`. |
| [`aclima01/herdr-powershell-title-sync`](https://github.com/aclima01/herdr-powershell-title-sync) | PowerShell | Windows port of the window-title sync approach. |
| [`Only-Moon/herdr-window-title-sync`](https://github.com/Only-Moon/herdr-window-title-sync) | Custom fork | Has a duplicate plugin ID and stale README; not recommended. |
| [`dkarter/dotfiles/config/herdr/plugins/workspace-title`](https://github.com/dkarter/dotfiles/tree/master/config/herdr/plugins/workspace-title) | Two files using zsh and `jq`; unlisted plugin | Sets only a workspace label. This is the smallest and easiest pattern to adapt. |

[`aarsh21/herdr-tab-title`](https://github.com/aarsh21/herdr-tab-title) changes Herdr's internal tab labels, not the outer terminal window title, so it does not solve this requirement.

## Conclusion

None of the reviewed plugins exposes arbitrary formatting such as `HERDR - <repo[branch]>`. The smallest fit is to adapt the minimal zsh + `jq` workspace-title plugin and add branch lookup plus the desired fixed prefix.
