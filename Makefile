# Elements, Align.
#
# The engine and its tests are a Swift package and need no Xcode at all, which
# is deliberate: the part of this product that has to be correct can be built
# and tested anywhere Swift runs, including Linux CI.

PACKAGE := Packages/ElementsAlign
PYMEEUS ?= /tmp/pymeeus/PyMeeus-0.5.12

.PHONY: help test build syntax fixtures vsop project apple-build clean

help:
	@echo "test      Build and test the engine (no Xcode required)"
	@echo "build     Build the engine only"
	@echo "syntax    Parse every Swift file with tree-sitter (no toolchain required)"
	@echo "fixtures  Regenerate golden test fixtures from the reference oracle"
	@echo "vsop      Regenerate the truncated VSOP87 Swift tables"
	@echo "project   Generate ElementsAlign.xcodeproj with XcodeGen (macOS)"
	@echo "apple-build  Inspect SDKs and compile both unsigned simulator apps (macOS)"

test:
	swift test --package-path $(PACKAGE)

build:
	swift build --package-path $(PACKAGE)

syntax:
	python3 Tools/syntaxcheck/check_swift_syntax.py Packages Apps

fixtures:
	python3 Tools/oracle/gen_fixtures.py $(PYMEEUS) \
		$(PACKAGE)/Tests/ElementsCoreTests/Fixtures/golden.json

vsop:
	python3 Tools/oracle/gen_vsop87.py $(PYMEEUS) \
		$(PACKAGE)/Sources/ElementsCore/Calendar/VSOP87Earth.swift

project:
	xcodegen generate

apple-build: project
	xcodebuild -version
	xcodebuild -showsdks
	xcodebuild -list -project ElementsAlign.xcodeproj
	xcodebuild -project ElementsAlign.xcodeproj -scheme ElementsAlignWatch \
		-configuration Debug -destination 'generic/platform=watchOS Simulator' \
		-derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
	xcodebuild -project ElementsAlign.xcodeproj -scheme ElementsAlign \
		-configuration Debug -destination 'generic/platform=iOS Simulator' \
		-derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build

clean:
	rm -rf $(PACKAGE)/.build ElementsAlign.xcodeproj
