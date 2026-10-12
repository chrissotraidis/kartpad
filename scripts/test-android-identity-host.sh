#!/usr/bin/env bash
set -euo pipefail
repo="$(git rev-parse --show-toplevel)"
jdk="${KARTPAD_TEST_JDK:-$repo/.android-bootstrap/jdk-17.0.20.1+1/Contents/Home}"
cache="$HOME/.gradle/caches/modules-2/files-2.1"
jar() { rg --files --hidden --no-ignore "$cache/$1" | awk '/\.jar$/ && !/-sources\.jar$/ && !/-javadoc\.jar$/ {print; exit}'; }
compiler="$(jar org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.21)"
stdlib="$(jar org.jetbrains.kotlin/kotlin-stdlib/2.2.21)"
annotations="$(jar org.jetbrains/annotations/13.0)"
reflect="$(jar org.jetbrains.kotlin/kotlin-reflect/2.2.0)"
coroutines="$(jar org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0)"
json="$(jar org.json/json/20240303)"
out="$repo/.android-bootstrap/identity-host-tests"
mkdir -p "$out"
clang++ -std=c++20 -dynamiclib -I"$jdk/include" -I"$jdk/include/darwin" -I"$repo/runtime/include" -I"$repo/vendor/runtimes/android/runtime/include" \
  "$repo/android/app/src/main/cpp/kartpad_mii_jni.cpp" -o "$out/libidentity-test.dylib"
clang++ -std=c++20 -I"$repo/runtime/include" "$repo/runtime/tests/android_identity_fixtures.cpp" -o "$out/fixtures"
"$out/fixtures" "$out"
"$jdk/bin/java" -cp "$compiler:$stdlib:$annotations:$coroutines:$reflect" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler \
  -no-stdlib -no-reflect -jvm-target 17 -classpath "$stdlib:$json" -d "$out/tests.jar" \
  "$repo/tests/android_identity/AtomicFile.kt" "$repo/tests/android_identity/Os.kt" "$repo/tests/android_identity/IdentityTests.kt" \
  "$repo/tests/android_identity/PublicationTests.kt" \
  "$repo/tests/android_identity/SaveTests.kt" \
  "$repo/tests/android_identity/RatingTests.kt" \
  "$repo/tests/android_identity/RatingStorageTests.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadRatingStorage.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadRatingCompanion.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadIdentityStorage.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadAtomicFile.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadSaveStorage.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadMiiStorage.kt"
"$jdk/bin/java" -cp "$out/tests.jar:$stdlib:$json" dev.kartpad.android.IdentityTestsKt "$out/libidentity-test.dylib" "$out"
