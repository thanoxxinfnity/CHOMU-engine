#!/bin/bash
export ANDROID_HOME=/workspace/tools/android-sdk
export JAVA_HOME=/workspace/tools/jdk17
export CCACHE_DIR=/workspace/tools/ccache-cache
export CCACHE_MAXSIZE=15G
cd /workspace/work/chomu-engine/godot
echo "START $(date +%s)" >> ../native_times.log
/workspace/tools/bin/scons platform=android target=editor arch=arm64 production=yes generate_apk=no swappy=yes store_release=yes \
  c_compiler_launcher=/workspace/tools/bin/ccache-wrap cpp_compiler_launcher=/workspace/tools/bin/ccache-wrap -j2 -k "$@"
rc=$?
echo "END $(date +%s) rc=$rc" >> ../native_times.log
exit $rc
