#!/bin/sh
# Builds the pitch harness for the Mac: SGRTimePitch.m as the tweak compiles it, and main.m.
set -e
cd "$(dirname "$0")"
mkdir -p build
xcrun clang -fobjc-arc -O2 -I ../../tweak/Sources -framework Foundation -framework AudioToolbox \
    main.m ../../tweak/Sources/Redesigned/Player/SGRTimePitch.m -o build/pitch
