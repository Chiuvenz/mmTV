# BiliTV Mac adapter

This directory defines the independent adapter boundary for running the television-oriented BiliTV client on macOS. Upstream source or release binaries are not committed to mmTV.

`../../Scripts/fetch-bilitv.sh` downloads the pinned official v2.5.1 release, verifies its GitHub-published SHA-256 digest, and extracts it under the ignored `External/BiliTV/` directory. The fetched `.ipk` contains a 1920×1080 web application and a Node service.

The release cannot be wrapped in `WKWebView` alone. The inspected frontend calls `PalmServiceBridge`; the service imports `webos-service`, stores state under `/media/internal`, and starts a media proxy on `127.0.0.1:7654`. The implemented adapter in `../BiliTVMac/` replaces those platform seams while keeping the upstream UI, process and account data isolated from the mmTV host.

Implemented process boundary:

```text
mmTV --launch--> BiliTVMac.app (Electron, separate Bundle ID)
                    |-- upstream 1920x1080 television UI
                    |-- isolated PalmServiceBridge IPC shim
                    |-- adapted BiliTV service + loopback media proxy
                    `-- ~/Library/Application Support/BiliTVMac/state
```

On the MacBook development machine, automated smoke verification now covers service startup, a real Bilibili API response, 20 anonymous content cards, D-pad focus movement, starting a public video until media time advances, and returning to the list. The smoke run is muted; QR login, account persistence, audible output, physical remote control and Mac mini/television behavior remain target-device acceptance items.

The browser is context-isolated, has no Node integration, denies popups, external navigation and permission requests, and accepts only the pinned Luna service namespace. LAN casting from upstream is disabled. The adapter is arm64, ad-hoc signed for local testing, and is not a notarized public release. Upstream is MIT licensed; its notice is bundled from `../BiliTVMac/THIRD-PARTY-NOTICES.md`.

