#!/bin/zsh
set -euo pipefail

repo=${0:A:h:h}
cd "$repo"

./scripts/generate-g6-translated-fixture.sh
test "$(shasum -a 256 generated/g6/translation/functions/func_80001000.cpp | awk '{print $1}')" = \
  "$(cat fixtures/g6/func_80001000.sha256)"

arm_build=build/g6-semantics-arm64
x86_build=build/g6-semantics-x86_64
san_build=build/g6-semantics-sanitized-arm64

cmake -S . -B "$arm_build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0
cmake --build "$arm_build" --target kartpad_semantics_contract kartpad_translated_semantics_fixture
"$arm_build/kartpad_semantics_contract" | tee "$arm_build/result.txt"
"$arm_build/kartpad_translated_semantics_fixture" | tee "$arm_build/translated-result.txt"

arch -x86_64 /usr/bin/true
cmake -S . -B "$x86_build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0
cmake --build "$x86_build" --target kartpad_semantics_contract kartpad_translated_semantics_fixture
arch -x86_64 "$x86_build/kartpad_semantics_contract" | tee "$x86_build/result.txt"
arch -x86_64 "$x86_build/kartpad_translated_semantics_fixture" | tee "$x86_build/translated-result.txt"

sed 's/architecture=arm64/architecture=HOST/' "$arm_build/result.txt" > "$arm_build/normalized.txt"
sed 's/architecture=x86_64/architecture=HOST/' "$x86_build/result.txt" > "$x86_build/normalized.txt"
cmp "$arm_build/normalized.txt" "$x86_build/normalized.txt"
cmp "$arm_build/translated-result.txt" "$x86_build/translated-result.txt"

cmake -S . -B "$san_build" -G Ninja -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DCMAKE_CXX_FLAGS='-fsanitize=address,undefined -fno-omit-frame-pointer' \
  -DCMAKE_EXE_LINKER_FLAGS='-fsanitize=address,undefined'
cmake --build "$san_build" --target kartpad_semantics_contract kartpad_translated_semantics_fixture
ASAN_OPTIONS=detect_leaks=0 "$san_build/kartpad_semantics_contract"
ASAN_OPTIONS=detect_leaks=0 "$san_build/kartpad_translated_semantics_fixture"

xcrun clang++ -std=c++20 -O2 -I ref/upstream/dolphin/Source/Core \
  tools/dolphin_float_oracle.cpp \
  ref/upstream/dolphin/Source/Core/Common/FloatUtils.cpp \
  -o build/dolphin-float-oracle
build/dolphin-float-oracle > build/dolphin-float-oracle.txt
cmp fixtures/g6/dolphin-estimates.txt build/dolphin-float-oracle.txt

dotnet_bin=/opt/homebrew/opt/dotnet@8/bin/dotnet
"$dotnet_bin" test \
  build/wiicompiled-fpscr/translator/tests/Translator.Tests/Translator.Tests.csproj \
  -c Release

echo 'G6 PPC semantic differential: pass'
