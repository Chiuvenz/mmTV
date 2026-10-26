# BiliTVMac

BiliTVMac is mmTV's isolated macOS runtime for the television-oriented
[bili-webos](https://github.com/asdf17128/bili-webos) client. It is an independent
application (`com.mmtv.bilitv`), not a web view embedded in the mmTV process.

Build from the repository root:

```sh
./Scripts/build-bilitv.sh
```

The build pins and verifies upstream BiliTV v2.5.1, installs the locked Electron
toolchain, runs tests and the dependency audit, signs the arm64 application for
local execution, and performs an online anonymous playback smoke test. Output is
`dist/BiliTVMac-0.1.0-arm64.zip`.

The runtime keeps cookies and identity state in BiliTVMac's own Application
Support directory. Its browser has context isolation enabled and Node integration
disabled. IPC accepts only the pinned BiliTV Luna namespace; popups, external
navigation, permission prompts and the upstream LAN cast listener are disabled.

This is a development candidate with ad-hoc signing. QR login, audible playback,
physical remote behavior and Mac mini/television output still require target-device
acceptance. See `../BiliTV/README.md` for the platform adaptation boundary and
`THIRD-PARTY-NOTICES.md` for upstream attribution.
