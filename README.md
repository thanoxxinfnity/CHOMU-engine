# CHoMU Engine + Chomu Games

**Website:** https://chomu-engine.vercel.app

CHoMU Engine is an Android game editor based on **Godot Engine 4.7.2** (MIT License), with GDScript support. This branch (`chomu-release`) holds the website, the Chomu City game project and the engine branding patches.

## Downloads (direct APK, 1 click)

| App | Version | Size | Download |
|---|---|---|---|
| CHoMU Engine (Android editor, arm64) | 1.0 | 158.5 MB | [CHoMU_Engine_v1.0.apk](https://huggingface.co/tertrxcuvuvjvj/chomu-releases/resolve/main/CHoMU_Engine_v1.0.apk?download=true) |
| Chomu City (game) | 0.1 | 38.7 MB | [ChomuCity_v0.1.apk](https://huggingface.co/tertrxcuvuvjvj/chomu-releases/resolve/main/ChomuCity_v0.1.apk?download=true) |

APKs are hosted on Hugging Face (GitHub limits files to 100 MB): https://huggingface.co/tertrxcuvuvjvj/chomu-releases
On Android, allow "Install unknown apps" for your browser when prompted.

**Coming soon:** Chomu Haveli (horror game) · CHoMU Shader Pack

## What's in this branch

| Folder | Contents |
|---|---|
| `website/` | Static animated site (HTML/CSS/JS, no build step). Deployed on Vercel. Drop `website/assets/chomucity_gameplay.mp4` to replace the screenshot with gameplay video, or `website/assets/hero.mp4` for a hero background video. |
| `chomu-city/` | Chomu City v0.1 Godot project. Open `project.godot` in CHoMU Engine / Godot 4.7. |
| `engine-patches/` | `chomu-branding.patch` (`git apply` on top of Godot `4.7.2-stable`), `BUILD_NOTES.md`, build scripts and branding scripts. |

### Rebuild the engine
```bash
git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git
cd godot && git apply ../engine-patches/chomu-branding.patch
# then follow engine-patches/BUILD_NOTES.md
```

## Credits & licenses
- **Godot Engine** © Juan Linietsky, Ariel Manzur and contributors — MIT License (https://godotengine.org/license). CHoMU Engine is not affiliated with the Godot Foundation.
- **Kenney** asset kits (CC0) — https://kenney.nl
- **Poly Haven** textures & HDRI (CC0) — https://polyhaven.com
- Audio from OpenGameArt (CC0): GGBotNet, IgnasD
- Full list: `chomu-city/CREDITS.txt`

---
