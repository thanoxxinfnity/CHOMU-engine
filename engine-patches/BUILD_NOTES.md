# CHoMU Engine — build notes (Android editor APK)

Fork of Godot Engine 4.7.2-stable (MIT). Release 1.0: "CHoMU Engine 1.0 (based on Godot 4.7.2)".

## Source
- `git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git godot` (in this dir)
- `python3 misc/scripts/install_swappy_android.py` (Swappy frame pacing, as official builds)
- Branding: `branding/install_user_brand.py` (user's logo from /workspace/work/chomu-brand; potrace-traced SVGs)
  plus C++/gradle edits listed below (see `git -C godot diff`).
  `branding/make_brand.py` / `install_brand.py` = earlier generated logo (superseded, not used).

## Toolchain (aarch64 Linux host!)
The NDK only ships x86_64 host binaries, so the NDK is used for sysroot/libc++/compiler-rt only:
- NDK **r29 = 29.0.14206865** (what Godot 4.7 requires, `platform/android/java/app/config.gradle`).
  sdkmanager refuses it on arm64 hosts → downloaded `https://dl.google.com/android/repository/android-ndk-r29-linux.zip`
  and unzipped to `/workspace/tools/android-sdk/ndk/29.0.14206865`.
- Native compiler: Debian `clang-21`/`lld-21`/`llvm-21` from apt.llvm.org (`deb http://apt.llvm.org/trixie/ llvm-toolchain-trixie-21 main`).
- In `ndk/.../toolchains/llvm/prebuilt/linux-x86_64/bin/` the x86 tools were moved to `bin_x86_orig/` and replaced:
  - `clang`, `clang++` = sh wrappers: `exec /usr/lib/llvm-21/bin/clang[++] --sysroot=<NDK>/toolchains/llvm/prebuilt/linux-x86_64/sysroot -resource-dir=/workspace/tools/clang21-android-resource -rtlib=compiler-rt -unwindlib=libunwind -Qunused-arguments "$@"`
  - `llvm-ar, llvm-ranlib, llvm-strip, llvm-objcopy, ld.lld, lld, llvm-nm, llvm-readelf, llvm-objdump` → symlinks to /usr/lib/llvm-21/bin.
  - `/workspace/tools/clang21-android-resource/include` → Debian clang 21 headers (NDK's arm_neon.h is from a different clang-21 snapshot and fails with "incompatible constant for this __builtin_neon function"); `lib` → NDK `lib/clang/21/lib` (Android compiler-rt builtins).
- aapt2: AGP's Maven aapt2 is x86_64 → use static aarch64 build from
  https://github.com/lzhiyong/android-sdk-tools/releases/download/35.0.2/android-sdk-tools-static-aarch64.zip
  at `/workspace/tools/sdk-tools-aarch64/build-tools/aapt2`, passed as `-Pandroid.aapt2FromMavenOverride=...`.
- scons: `pip install scons` (goes to ~/.local, may reset) → wrapper `/workspace/tools/bin/scons` = `python3 -m SCons` (gradle's lib module needs `scons` on PATH).
- JDK 17 `/workspace/tools/jdk17`; GRADLE_USER_HOME=/workspace/tools/gradle-home (persistent cache).

## Build
1. `./build_native.sh` →
   `scons platform=android target=editor arch=arm64 production=yes generate_apk=no swappy=yes -j2 -k`
   (production=yes ⇒ lto auto→none on Android; all standard modules on; Forward+/Mobile/Compatibility all enabled).
   Incremental: just re-run; output `godot/platform/android/java/lib/libs/tools/arm64-v8a/libgodot_android.so`.
2. `./build_apk.sh generateGodotEditor` (signing env vars set from chomu keystore; gradle strips the .so).
   Output APK under `godot/bin/android_editor_builds/`.
3. Copy to `/workspace/work/CHoMU_Engine_1.0.apk`, verify `apksigner verify --print-certs`, `aapt2 dump badging`.

## Signing
- Keystore `/workspace/tools/keys/chomu.keystore`, alias `chomuengine`, password in `/workspace/tools/keys/chomu.pass`
  (RSA 4096, 10000 days). Keep it: future versions must use the same key to update in place.

## Branding spots changed
See final report section in this file (appended after the build).
