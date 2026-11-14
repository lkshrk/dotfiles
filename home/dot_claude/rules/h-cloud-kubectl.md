# h-cloud cluster: kubectl, flux, talosctl

Cluster access needs no credentials from the user. `~/Dev/h-cloud/scripts/cluster-auth.sh` decrypts the Talos CA (sops, age key from rbw) and writes a short-lived kubeconfig and talosconfig into `$XDG_RUNTIME_DIR/h-cloud` (tmpfs). `~/.kube/config` has no h-cloud context.

- In zsh, `kubectl`, `flux`, `helm`, `helmfile`, `talosctl` and `k9s` are wrapped and authenticate on their own. Just run them.
- If a call prints "h-cloud: no cluster credentials" or falls back to `localhost:8080`, authenticate in the same command: `eval "$(~/Dev/h-cloud/scripts/cluster-auth.sh env)" && kubectl …`. Every tool call is a fresh shell, so the exports don't carry over.
- If the script fails because rbw is locked, ask the user to run `rbw unlock`. Don't look for the age key or a kubeconfig elsewhere, and don't ask for one.
- Never print, copy or commit the kubeconfig, talosconfig, age key or Secret values (`get secret -o yaml`, `.data`).
- Read freely: `get`, `describe`, `logs`, `events`, `flux get`. Changes go through Git in `~/Dev/h-cloud`: Flux applies them on its interval and Stakater Reloader restarts pods whose ConfigMaps or Secrets changed, so wait for that instead of running `flux reconcile` or restarting pods. Mutate the cluster directly (`apply`, `edit`, `delete`, `scale`, `rollout restart`, `exec`) only when the user asks.

This applies to me and to every subagent I dispatch.
