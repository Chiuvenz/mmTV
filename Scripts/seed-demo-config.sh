#!/bin/zsh
# Merge living-room demo entries + native HA controls + Jellyfin media library into Application Support.
# Safe: keeps existing entries (e.g. BiliTVMac); only adds missing demo titles / config blocks.
set -euo pipefail

CONFIG_DIR="${HOME}/Library/Application Support/mmTV"
CONFIG="${CONFIG_DIR}/configuration.json"
EXAMPLE="$(cd "${0:A:h:h}" && pwd)/Config/configuration.example.json"
IINA="/Applications/IINA.app"
QT="/System/Applications/QuickTime Player.app"
ZELDA_BOTW="/Volumes/mmTV Media/Games/Zelda/Zelda - Breath of the Wild.app"
ZELDA_TOTK="/Volumes/mmTV Media/Games/Zelda/Zelda - Tears of the Kingdom.app"
MEDIA_MOVIES="/Volumes/mmTV Media/Media/Movies"
MEDIA_TV="/Volumes/mmTV Media/Media/TV"

mkdir -p "${CONFIG_DIR}"
# Ensure real library folders exist when the volume is mounted (do not invent other roots).
if [[ -d "/Volumes/mmTV Media" ]]; then
  mkdir -p "${MEDIA_MOVIES}" "${MEDIA_TV}"
fi

if [[ ! -f "${CONFIG}" ]]; then
  printf '%s\n' '{"schemaVersion":1,"entries":[],"disabledModules":[],"tvMode":true}' > "${CONFIG}"
fi

export MMTV_SEED_CONFIG="${CONFIG}"
export MMTV_SEED_EXAMPLE="${EXAMPLE}"
export MMTV_SEED_BOTW="${ZELDA_BOTW}"
export MMTV_SEED_TOTK="${ZELDA_TOTK}"
export MMTV_SEED_IINA="${IINA}"
export MMTV_SEED_QT="${QT}"
export MMTV_SEED_MOVIES="${MEDIA_MOVIES}"
export MMTV_SEED_TV="${MEDIA_TV}"

python3 <<'PY'
import json, os, shutil, uuid
from pathlib import Path

config_path = Path(os.environ["MMTV_SEED_CONFIG"])
example_path = Path(os.environ["MMTV_SEED_EXAMPLE"])
botw = os.environ["MMTV_SEED_BOTW"]
totk = os.environ["MMTV_SEED_TOTK"]
iina = os.environ["MMTV_SEED_IINA"]
qt = os.environ["MMTV_SEED_QT"]
movies = os.environ["MMTV_SEED_MOVIES"]
tv = os.environ["MMTV_SEED_TV"]

cfg = json.loads(config_path.read_text())
example = json.loads(example_path.read_text())

cfg.setdefault("schemaVersion", 1)
cfg.setdefault("entries", [])
cfg.setdefault("disabledModules", [])
cfg.setdefault("tvMode", True)

existing_titles = {e.get("title") for e in cfg["entries"]}
existing_bundles = {e.get("applicationBundleID") for e in cfg["entries"] if e.get("applicationBundleID")}

def add_app(title, module, location, bundle, notes, verified=False, arguments=None, kind="application"):
    if title in existing_titles:
        return False
    if bundle and bundle in existing_bundles:
        return False
    if kind == "application" and not Path(location).exists():
        print(f"skip missing app: {location}")
        return False
    entry = {
        "id": str(uuid.uuid4()),
        "title": title,
        "module": module,
        "kind": kind,
        "location": location,
        "arguments": arguments or [],
        "notes": notes,
        "tvInteractionVerified": verified,
    }
    if bundle:
        entry["applicationBundleID"] = bundle
    cfg["entries"].append(entry)
    existing_titles.add(title)
    if bundle:
        existing_bundles.add(bundle)
    print(f"added: {title}")
    return True

add_app("塞尔达 旷野之息", "games", botw, "org.nxnative.01007ef00011e000",
        "seed-demo-config：外置盘 BOTW", True)
add_app("塞尔达 王国之泪", "games", totk, "org.nxnative.0100f2c0115b6000",
        "seed-demo-config：外置盘 TOTK", True)

if "Jellyfin Web" not in existing_titles:
    cfg["entries"].append({
        "id": str(uuid.uuid4()),
        "title": "Jellyfin Web",
        "module": "video",
        "kind": "executable",
        "location": "/usr/bin/open",
        "arguments": ["http://127.0.0.1:8096"],
        "notes": "seed-demo-config：系统浏览器打开 Jellyfin；壳内优先 mediaLibrary 卡片",
        "tvInteractionVerified": False,
    })
    print("added: Jellyfin Web → http://127.0.0.1:8096")

add_app("IINA", "video", iina, "com.colliderli.iina",
        "seed-demo-config：单文件播放兜底", False)
add_app("QuickTime Player", "video", qt, "com.apple.QuickTimePlayerX",
        "seed-demo-config：系统播放器兜底", False)

ha = cfg.get("homeAssistant")
ex_ha = example["homeAssistant"]
if not isinstance(ha, dict):
    ha = dict(ex_ha)
    print("added homeAssistant (uiMode=controls, useMock=true)")
else:
    ha.setdefault("baseURL", ex_ha["baseURL"])
    ha.setdefault("token", "REPLACE_WITH_LONG_LIVED_TOKEN")
    ha.setdefault("useMock", True)
    ha.setdefault("controls", ex_ha["controls"])
    ha.setdefault("uiMode", "controls")
    ha.setdefault("dashboardPath", "/")
    # Prefer native controls for living-room remote demo; Lovelace stays optional.
    if ha.get("uiMode") == "lovelace":
        ha["uiMode"] = "controls"
        print("switched homeAssistant.uiMode lovelace → controls")
    print("kept existing homeAssistant; ensured native-controls keys")
cfg["homeAssistant"] = ha

ml = cfg.get("mediaLibrary")
ex_ml = example["mediaLibrary"]
if not isinstance(ml, dict):
    ml = dict(ex_ml)
    print("added mediaLibrary jellyfin →", movies, "·", tv)
else:
    ml.setdefault("provider", "jellyfin")
    ml.setdefault("baseURL", "http://127.0.0.1:8096")
    ml.setdefault("embedInShell", True)
    ml.setdefault("libraryRoots", [movies, tv])
    print("kept existing mediaLibrary; ensured required keys")
cfg["mediaLibrary"] = ml

backup = Path(str(config_path) + ".seed-backup")
shutil.copy2(config_path, backup)
config_path.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
os.chmod(config_path, 0o600)
print(f"wrote {config_path}")
print(f"backup {backup}")
print("Next: ensure Jellyfin is Launch’d (http://127.0.0.1:8096) with Movies/TV library roots.")
print("HA: native controls first — set baseURL + token + entity IDs; uiMode=lovelace only if you want the optional dashboard card.")
PY
