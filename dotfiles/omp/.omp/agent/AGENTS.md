# Gateway tools

- Use the `litellm-tools` MCP gateway for Linear, Context7, and SearXNG. Do not install duplicate connections to those services.
- For Linear workflows, read the matching installed Linear skill and use the gateway's Linear tools. Keep mutations within the user's requested scope; tool availability is not authorization.
- For library/API documentation, use Context7: resolve the library ID first unless an exact ID is supplied, then query documentation matching the project's installed version. Do not assume a version is supported when the result does not identify it.
- Prefer the gateway's SearXNG tools for general web research and readable URL fetching. Cite sources. If unavailable, use the built-in web tools and state the limitation when relevant.
- Keep Context Mode local for large-output processing and indexed retrieval; it complements the gateway rather than replacing it.
- Reuse `~/.config/env/bin/litellm-mcp-headers` for gateway authentication. Never print its output or store its credential in configuration, logs, or notes. Its MCP credential is separate from the model provider's `LITELLM_API_KEY`.

# h-cloud cluster: kubectl, flux, talosctl

Cluster access needs no credentials from the user. `~/Dev/h-cloud/scripts/cluster-auth.sh` decrypts the Talos CA (sops, age key from rbw) and writes a short-lived kubeconfig and talosconfig into `$XDG_RUNTIME_DIR/h-cloud` (tmpfs). `~/.kube/config` has no h-cloud context.

- In zsh, `kubectl`, `flux`, `helm`, `helmfile`, `talosctl` and `k9s` are wrapped and authenticate on their own. Just run them.
- If a call prints "h-cloud: no cluster credentials" or falls back to `localhost:8080`, authenticate in the same command: `eval "$(~/Dev/h-cloud/scripts/cluster-auth.sh env)" && kubectl …`. Every tool call is a fresh shell, so the exports don't carry over.
- If the script fails because rbw is locked, ask the user to run `rbw unlock`. Don't look for the age key or a kubeconfig elsewhere, and don't ask for one.
- Never print, copy or commit the kubeconfig, talosconfig, age key or Secret values (`get secret -o yaml`, `.data`).
- Read freely: `get`, `describe`, `logs`, `events`, `flux get`. Changes go through Git in `~/Dev/h-cloud`: Flux applies them on its interval and Stakater Reloader restarts pods whose ConfigMaps or Secrets changed, so wait for that instead of running `flux reconcile` or restarting pods. Mutate the cluster directly (`apply`, `edit`, `delete`, `scale`, `rollout restart`, `exec`) only when the user asks.
