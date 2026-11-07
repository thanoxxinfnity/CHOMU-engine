#!/usr/bin/env python3
"""CHoMU 1.5: stage the v1.5 content (v1.4 templates + Ultra Graphics Demo; Character Studio, CHoMU Systems snapshot, CHoMU Ultra) into the Android editor APK assets.

  templates/  7 v14 template zips (AINPCChat as an Android copy without the linux .so) + 640x360 thumbnails
              (from content/shots/*_1.png) + index.json (v13 format, descriptions updated to the realistic v14 pass,
              plus a builtin "Empty Project" entry with no zip; the picker always adds Empty Project itself).
  addons/     chomu_character_studio + chomu_systems + manifest.txt. project_dialog.cpp copies them into
              res://addons/ of every new project (not enabled; Project Settings > Plugins).
Usage: stage_v14.py <assets/chomu root>
"""
import json, os, shutil, subprocess, sys
from PIL import Image

V14 = '/workspace/work/chomu-v14'
TPL = f'{V14}/content/templates'
SHOTS = f'{V14}/content/shots'
V13_INDEX = '/workspace/work/chomu-v13/content/templates/index.json'
V15 = '/workspace/work/chomu-v15'
ADDON_SRC = {  # addon -> parent folder it is copied from
    'chomu_character_studio': f'{V14}/addons',
    'chomu_systems': f'{V15}/addons',  # snapshot taken for 1.5 (self-test 853/853)
    'chomu_ultra': f'{V15}/content/projects/UltraGraphicsDemo/addons',  # copy of chomu-ultra-graphics v0.1, one UI string changed
}
ADDONS = list(ADDON_SRC)
ENGINE = 'CHoMU Engine 1.5'
CACHE = '/workspace/work/chomu-engine/pkg_android_v14'  # Android AINPCChat copy (kept between runs)

DESC = {
    'FPSShooter': 'Realistic first-person shooter: sunset industrial yard of shipping containers, barriers and a loading dock (Poly Haven 2K PBR), assault-rifle view model with muzzle flash and reload, metallic combat-drone waves, health/ammo HUD.',
    'ThirdPersonAdventure': 'Realistic third-person adventure: spring-arm camera, rigged human hero (male/female, C to swap) with walk/run/sprint/jump, 12 collectible gems in a ruins meadow with real trees, boulders and grass.',
    'CarDriving': 'Realistic car driving: VehicleBody3D concept car with clear-coat paint and headlights, chase/bonnet cameras, wet asphalt circuit with barriers in an open area, speedometer, lap timer.',
    'Horror': 'Realistic horror: dark abandoned house built from Poly Haven props, flashlight with battery, volumetric fog, patrolling ghost on a navmesh, hide in wardrobes, jump scare, key + exit objective.',
    'OpenWorld': 'Realistic open world: 512 m Terrain3D valley with photoreal Poly Haven materials, scanned firs, trees, shrubs and rocks with LOD, HDRI sky with matching sun, realistic human explorer (GDScript terrain fallback).',
    'AnimeVFXArena': 'Anime VFX arena with realistic CC0 heroine (toon-shaded): blue energy orb, red slash barrage and a sphere-field ultimate with screen shake and bloom in a stone-ring arena; mobile fallback.',
    'UltraGraphicsDemo': 'CHoMU Ultra graphics showcase: lake valley with wind-blown grass and reeds, water with foam and refraction, wet stone plaza with puddles, gold and crate hero materials, atmospheric sky, fog and colour grading. Buttons switch Low / Medium / Mobile Ultra / PC Cinematic presets live; adaptive resolution on phones.',
    'AINPCChat': 'Offline AI NPC in a realistic shop: chat with Mehra the shopkeeper (realistic CC0 humans, 9 Poly Haven props) through a speech-bubble UI, powered by NobodyWho + a 398 MB Qwen2.5-0.5B GGUF downloaded on first run; scripted fallback.',
}
LINUX_SO = 'AINPCChat/addons/nobodywho/libnobodywho-godot-aarch64-unknown-linux-gnu-release.so'


def zip_list(z):
    out = subprocess.run(['unzip', '-Z1', z], capture_output=True, text=True, check=True).stdout
    return [l for l in out.splitlines() if l]


def android_npc_zip():
    src = f'{TPL}/AINPCChat.zip'
    os.makedirs(CACHE, exist_ok=True)
    dst = f'{CACHE}/AINPCChat.zip'
    stamp = f'{dst}.src'
    key = f'{os.path.getsize(src)}:{int(os.path.getmtime(src))}'
    if os.path.exists(dst) and os.path.exists(stamp) and open(stamp).read() == key:
        return dst
    shutil.copyfile(src, dst + '.tmp')
    subprocess.run(['zip', '-q', '-d', dst + '.tmp', LINUX_SO], check=True)
    names = zip_list(dst + '.tmp')
    assert LINUX_SO not in names, 'linux .so still in Android AINPCChat.zip'
    assert any(n.endswith('aarch64-linux-android-release.so') for n in names), 'android .so missing'
    os.replace(dst + '.tmp', dst)
    open(stamp, 'w').write(key)
    return dst


def stage_templates(root):
    out = os.path.join(root, 'templates')
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)
    v13 = {e['id']: e for e in json.load(open(V13_INDEX))['templates']}
    entries = [{
        'id': 'EmptyProject', 'name': 'Empty Project', 'builtin': True,
        'description': 'A blank project with the CHoMU Loading Screen addon, plus CHoMU Character Studio, CHoMU Systems and CHoMU Ultra (enable them in Project Settings > Plugins).',
        'engine': ENGINE, 'renderers': ['forward_plus', 'mobile', 'gl_compatibility'], 'files': 0,
    }]
    for tid in ['FPSShooter', 'ThirdPersonAdventure', 'CarDriving', 'Horror', 'OpenWorld', 'AnimeVFXArena', 'AINPCChat', 'UltraGraphicsDemo']:
        src = android_npc_zip() if tid == 'AINPCChat' else (f'{V15}/content/templates/{tid}.zip' if tid == 'UltraGraphicsDemo' else f'{TPL}/{tid}.zip')
        zname = f'{tid}.zip'
        shutil.copyfile(src, os.path.join(out, zname))
        names = zip_list(src)
        im = Image.open(f'{V15}/shots/{tid}_1.png' if tid == 'UltraGraphicsDemo' else f'{SHOTS}/{tid}_1.png').convert('RGB')
        im.thumbnail((640, 360), Image.LANCZOS)
        im.save(os.path.join(out, f'{tid}.png'), optimize=True)
        if tid == 'UltraGraphicsDemo':
            e = {'id': tid, 'name': 'Ultra Graphics Demo', 'renderers': ['mobile', 'forward_plus']}
        else:
            e = dict(v13[tid])
        size = os.path.getsize(src)
        e.update({'description': DESC[tid], 'zip': zname, 'size_bytes': size, 'size_mb': round(size / 1048576, 1),
                  'thumbnail': f'{tid}.png',
                  'screenshots': [f'../shots/{tid}_1.png', f'../shots/{tid}_2.png'],
                  'engine': ENGINE, 'files': sum(1 for n in names if not n.endswith('/')), 'zip_size': size})
        entries.append(e)
    json.dump({'version': '1.5', 'generated_by': 'CHoMU content build (v1.5, Android)', 'templates': entries},
              open(os.path.join(out, 'index.json'), 'w'), indent=1)
    size = sum(os.path.getsize(os.path.join(out, f)) for f in os.listdir(out))
    print(f'templates: {len(entries) - 1} zips + Empty Project entry staged ({size / 1e6:.1f} MB)')


def stage_addons(root):
    out = os.path.join(root, 'addons')
    if os.path.isdir(out):
        shutil.rmtree(out)
    rels = []
    for a in ADDONS:
        base = f'{ADDON_SRC[a]}/{a}'
        assert os.path.exists(f'{base}/plugin.cfg'), base
        for d, _, fs in os.walk(base):
            for f in sorted(fs):
                if f.endswith('.import'):
                    continue
                rel = os.path.relpath(os.path.join(d, f), ADDON_SRC[a])
                os.makedirs(os.path.dirname(os.path.join(out, rel)), exist_ok=True)
                shutil.copyfile(os.path.join(d, f), os.path.join(out, rel))
                rels.append(rel)
    rels.sort()
    open(os.path.join(out, 'manifest.txt'), 'w').write(
        '# CHoMU 1.5 bundled editor addons - copied into res://addons/ of new projects\n' + '\n'.join(rels) + '\n')
    print(f'addons: {len(rels)} files from {ADDONS}')


if __name__ == '__main__':
    root = sys.argv[1]
    stage_templates(root)
    stage_addons(root)
