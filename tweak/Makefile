TARGET := iphone:clang:latest:16.0
ARCHS := arm64
FINALPACKAGE := 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := spotifyglass

SG_VERSION := $(shell sed -n 's/^Version: //p' control)

# Every source under Sources/, so a new feature needs no Makefile edit. Shared/Flags/SGFlagList.m
# is generated from the IPA by scripts/extract-flags.py.
spotifyglass_FILES := $(shell find Sources -name '*.m' -o -name '*.x' -o -name '*.swift' | sort)
spotifyglass_CFLAGS := -fobjc-arc -ISources -DSG_VERSION=\"$(SG_VERSION)\"
spotifyglass_FRAMEWORKS := UIKit QuartzCore UniformTypeIdentifiers MediaPlayer CoreImage AudioToolbox AVFoundation CoreHaptics
# Runtime swizzling instead of Substrate so the dylib has no extra dependency inside the IPA.
spotifyglass_LOGOS_DEFAULT_GENERATOR := internal

include $(THEOS_MAKE_PATH)/tweak.mk

# The layers of Sources/ stay apart (scripts/check-layers.sh): an import across them fails the build.
# A copy of tweak/ made without the scripts beside it builds unchecked.
before-all::
	@if [ -x ../scripts/check-layers.sh ]; then ../scripts/check-layers.sh Sources; fi
