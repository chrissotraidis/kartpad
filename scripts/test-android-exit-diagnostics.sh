#!/usr/bin/env bash
set -euo pipefail
repo="$(git rev-parse --show-toplevel)"
source "$repo/scripts/android-toolchain-versions.sh"
jdk="$repo/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home"
cache="$HOME/.gradle/caches/modules-2/files-2.1"
jar() { rg --files --hidden --no-ignore "$cache/$1" | awk '/\.jar$/ && !/-(sources|javadoc)\.jar$/ {print; exit}'; }
compiler="$(jar org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.21)"
stdlib="$(jar org.jetbrains.kotlin/kotlin-stdlib/2.2.21)"
annotations="$(jar org.jetbrains/annotations/13.0)"
reflect="$(jar org.jetbrains.kotlin/kotlin-reflect/2.2.0)"
coroutines="$(jar org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0)"
json="$(jar org.json/json/20240303)"
out="$repo/.android-bootstrap/exit-host-tests"
mkdir -p "$out"
"$jdk/bin/java" -cp "$compiler:$stdlib:$annotations:$coroutines:$reflect" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler \
  -no-stdlib -no-reflect -jvm-target 17 -classpath "$stdlib:$json" -d "$out/tests.jar" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadDiagnosticExport.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadExitDiagnostics.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadExitTraces.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadTombstoneSummary.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadBoundedRead.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadRendererDiagnostics.kt" \
  "$repo/android/app/src/main/java/dev/kartpad/android/KartPadCharacterGraphicsTest.kt" \
  "$repo/tests/android_identity/AtomicFile.kt" \
  "$repo"/tests/android_exit/*.kt
"$jdk/bin/java" -cp "$out/tests.jar:$stdlib:$json" dev.kartpad.android.ExitDiagnosticsTestsKt
