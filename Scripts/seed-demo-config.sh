#!/bin/zsh
# Merge living-room demo entries + mock HA into Application Support configuration.
# Safe: keeps existing entries (e.g. BiliTVMac); only adds missing demo titles / HA block.
set -euo pipefail

CONFIG_DIR="${HOME}/Library/Application Support/mmTV"
CONFIG="${CONFIG_DIR}/configuration.json"
EXAMPLE="$(cd "${0:A:h:h}" && pwd)/Config/configuration.example.json"
USER_SHORT="$(whoami)"
MOVIES_DIR="${HOME}/Movies"
ZELDA_BOTW="/Volumes/mmTV Media/Games/Zelda/Zelda - Breath of the Wild.app"
ZELDA_TOTK="/Volumes/mmTV Media/Games/Zelda/Zelda - Tears of the Kingdom.app"
IINA="/Applications/IINA.app"
QT="/System/Applications/QuickTime Player.app"

mkdir -p "${CONFIG_DIR}"
if [[ ! -f "${CONFIG}" ]]; then
  printf '%s\n' '{"schemaVersion":1,"entries":[],"disabledModules":[],"tvMode":true}' > "${CONFIG}"
fi

export MMTV_SEED_CONFIG="${CONFIG}"
export MMTV_SEED_EXAMPLE="${EXAMPLE}"
export MMTV_SEED_MOVIES="${MOVIES_DIR}"
export MMTV_SEED_BOTW="${ZELDA_BOTW}"
export MMTV_SEED_TOTK="${ZELDA_TOTK}"
export MMTV_SEED_IINA="${IINA}"
export MMTV_SEED_QT="${QT}"

python3 <<'PY'
import json, os, shutil, uuid
from pathlib import Path

config_path = Path(os.environ["MMTV_SEED_CONFIG"])
example_path = Path(os.environ["MMTV_SEED_EXAMPLE"])
movies = os.environ["MMTV_SEED_MOVIES"]
botw = os.environ["MMTV_SEED_BOTW"]
totk = os.environ["MMTV_SEED_TOTK"]
iina = os.environ["MMTV_SEED_IINA"]
qt = os.environ["MMTV_SEED_QT"]

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
add_app("IINA", "video", iina, "com.colliderli.iina",
        "seed-demo-config：本机影片播放器", False)
add_app("QuickTime Player", "video", qt, "com.apple.QuickTimePlayerX",
        "seed-demo-config：系统播放器兜底", False)

if Path(iina).exists() and "本机影片夹" not in existing_titles:
    cfg["entries"].append({
        "id": str(uuid.uuid4()),
        "title": "本机影片夹",
        "module": "video",
        "kind": "executable",
        "location": "/usr/bin/open",
        "arguments": ["-a", "IINA", movies],
        "notes": f"seed-demo-config：打开 {movies}",
        "tvInteractionVerified": False,
    })
    print(f"added: 本机影片夹 → {movies}")

ha = cfg.get("homeAssistant")
if not isinstance(ha, dict):
    ha = example["homeAssistant"]
    print("added homeAssistant mock block (useMock=true; paste token later)")
else:
    ha.setdefault("baseURL", example["homeAssistant"]["baseURL"])
    ha.setdefault("token", "REPLACE_WITH_LONG_LIVED_TOKEN")
    ha.setdefault("useMock", True)
    ha.setdefault("controls", example["homeAssistant"]["controls"])
    print("kept existing homeAssistant; ensured required keys")
cfg["homeAssistant"] = ha

backup = Path(str(config_path) + ".seed-backup")
shutil.copy2(config_path, backup)
config_path.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
os.chmod(config_path, 0o600)
print(f"wrote {config_path}")
print(f"backup {backup}")
print("Next: set homeAssistant.token + useMock=false when HA is ready.")
PY
