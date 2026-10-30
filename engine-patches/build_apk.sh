#!/bin/bash
# Gradle step: package the Android editor APK (android flavor, release) signed with chomu keystore.
export ANDROID_HOME=/workspace/tools/android-sdk
export ANDROID_SDK_ROOT=/workspace/tools/android-sdk
export JAVA_HOME=/workspace/tools/jdk17
export PATH=$JAVA_HOME/bin:/workspace/tools/bin:$PATH
export GRADLE_USER_HOME=/workspace/tools/gradle-home
export GODOT_ANDROID_SIGN_KEYSTORE=/workspace/tools/keys/chomu.keystore
export GODOT_ANDROID_KEYSTORE_ALIAS=chomuengine
export GODOT_ANDROID_SIGN_PASSWORD="$(cat /workspace/tools/keys/chomu.pass)"
cd /workspace/work/chomu-engine/godot/platform/android/java
echo "START $(date +%s) $*" >> ../../../../gradle_times.log
nice -n ${NICE:-0} ./gradlew -Pandroid.aapt2FromMavenOverride=/workspace/tools/sdk-tools-aarch64/build-tools/aapt2 --no-daemon "$@"
rc=$?
echo "END $(date +%s) rc=$rc" >> ../../../../gradle_times.log
exit $rc
