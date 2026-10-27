# Integrations

Third-party app **adapters no longer live in this repository**.

mmTV is a launcher/shell: it opens standalone apps by Bundle ID. Adapter source, fetch/build/smoke scripts, and Electron runtimes are in:

**[Chiuvenz/mmTVAdapters](https://github.com/Chiuvenz/mmTVAdapters)** (`~/vibeCoding/mmTVAdapters`)

| App | Bundle ID | Launch args |
|---|---|---|
| BiliTVMac | `com.mmtv.bilitv` | `--tv-fullscreen` |

Build BiliTVMac there with `./Scripts/build-bilitv.sh`, install the `.app`, then use mmTV「看点什么」to detect and launch it.

In-shell modules that stay here: Music, Photos, Home (HA), Assistant (Hermes), plus Games/TVApps as generic launchers.
