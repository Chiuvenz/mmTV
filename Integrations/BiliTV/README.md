# BiliTV Mac adapter

This directory defines the independent adapter boundary for running the television-oriented BiliTV client on macOS. Upstream source or release binaries are not committed to mmTV.

`../../Scripts/fetch-bilitv.sh` downloads the pinned official v2.5.1 release, verifies its GitHub-published SHA-256 digest, and extracts it under the ignored `External/BiliTV/` directory. The fetched `.ipk` contains a 1920×1080 web application and a Node service.

The release cannot be wrapped in `WKWebView` alone. The inspected frontend calls `PalmServiceBridge`; the service imports `webos-service`, stores state under `/media/internal`, and starts a media proxy on `127.0.0.1:7654`. The adapter must replace those five platform seams listed in `adapter-manifest.json` while keeping the upstream UI and account data isolated from the mmTV host.

Planned process boundary:

```text
mmTV --launch--> BiliTVMac.app
                    |-- WKWebView + PalmServiceBridge shim
                    |-- local IPC, loopback only
                    `-- BiliTV sidecar + Application Support state
```

The adapter is not marked usable until anonymous browsing, QR login, playback, sound, D-pad navigation, fullscreen, Home return, and clean shutdown pass on macOS. Upstream is MIT licensed; any distributed derivative must retain its license and attribution.

