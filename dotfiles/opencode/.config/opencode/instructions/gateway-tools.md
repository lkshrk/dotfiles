# Gateway tools

- Use the `litellm-tools` MCP gateway for Linear, Context7, and SearXNG. Do not install duplicate connections to those services.
- For Linear workflows, read the matching installed Linear skill and use the gateway's Linear tools. Keep mutations within the user's requested scope; tool availability is not authorization.
- For library/API documentation, use Context7: resolve the library ID first unless an exact ID is supplied, then query documentation matching the project's installed version. Do not assume a version is supported when the result does not identify it.
- Prefer the gateway's SearXNG tools for general web research and readable URL fetching. Cite sources. If unavailable, use the built-in web tools and state the limitation when relevant.
- Keep Context Mode local for large-output processing and indexed retrieval; it complements the gateway rather than replacing it.
- The gateway credential reaches this process as `LITELLM_API_KEY`, injected by `~/.config/env/bin/opencode-local-agents`. Never print or fetch it (including through `~/.config/env/bin/local-agents-token`), and never store it in configuration, logs, or notes.
