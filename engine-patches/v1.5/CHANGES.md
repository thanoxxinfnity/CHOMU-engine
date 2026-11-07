# CHoMU Engine 1.5 — engine-side changes (on top of 1.4.1)

- `core/version.h`: `#define CHOMU_VERSION "1.5"` (startup banner, About, window title).
- `platform/android/java/editor/build.gradle`: versionName `1.5`, versionCode offset +10 (40702510; 1.4.1 was 40702505).
- `editor/project_manager/project_dialog.cpp`: Empty Project description lists CHoMU Ultra next to Character Studio and Systems.
- `engine-patches/chomu_store/chomu_store.gd`: `STORE_VERSION := "1.5"`; embedded via `gen_headers.py` into `editor/chomu/chomu_store_data.h`.
- Content staging: `stage_v15.py` bundles 8 templates (7 from 1.4 + Ultra Graphics Demo) and three addons
  (`chomu_character_studio`, `chomu_systems` snapshot, `chomu_ultra`) into `assets/chomu/` of the Android editor.
  The Linux zip carries the addons and the Ultra template in `chomu_assets/` next to the binary.
- Template source: `templates/UltraGraphicsDemo/`. Addon sources: `addons/`.
