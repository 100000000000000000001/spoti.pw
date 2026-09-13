# Entry points; the real work is in scripts/. IPA defaults to the first file in ipa/.
IPA ?= $(firstword $(wildcard ipa/*.ipa))

# What goes on the phone is the mod alone. FLEX is the inspector `make trees` reads the screens
# through, so it rides along only when it is asked for: make install FLEX=1. (A make target cannot
# take --flex; make would read that as an option of its own.)
FLEX ?= 0
FLEX_ARG := $(if $(filter 0,$(FLEX)),--no-flex,)

# A local install is renamed and re-iconed so it is told apart from the released app on the home
# screen. It writes its own file, so publish's SKIP_BUILD=1 (newest *-glass.ipa) never picks it up.
DEV_NAME ?= spoti.dev
DEV_ICON ?= docs/icon.png

.PHONY: build release install publish push trees log flags
build:    ## FLEX + glass IPA into out/
	./scripts/pipeline.sh $(IPA)
release:  ## glass only, no FLEX
	./scripts/pipeline.sh $(IPA) --no-flex
install:  ## build, sign with your certificate, push to the phone on USB (FLEX=1 to take FLEX too)
	./scripts/pipeline.sh $(IPA) --install $(FLEX_ARG) --name "$(DEV_NAME)" --icon "$(DEV_ICON)" -o out/spoti.dev.ipa
publish:  ## VERSION=0.15.0 NOTES="..." : build, upload to catbox, write the site's release.json, print the link
	./scripts/publish.sh stage "$(IPA)" "$(VERSION)" "$(NOTES)"
push:     ## commit and push the staged release in both repos (after testing the link)
	./scripts/publish.sh push
trees:    ## record per-screen view trees into trees/ (needs a FLEX build on the phone)
	./scripts/record-trees.py
log:      ## stream the tweak's log lines from the phone
	./scripts/dump-log.sh
flags:    ## regenerate tweak/Sources/Features/Flags/SGFlagList.m, Spotify's remote-config flags, from the IPA
	./scripts/extract-flags.py $(IPA)
