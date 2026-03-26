# Baylan — Apple workspace build helpers
# Requires: XcodeGen (brew install xcodegen)

.PHONY: generate open clean resolve

## Generate BaylanIOS.xcodeproj from project.yml
generate:
	cd ios && xcodegen generate

## Open workspace after generation
open: generate
	open ios/BaylanIOS.xcodeproj

## Resolve Swift Package dependencies
resolve:
	cd shared && swift package resolve

## Clean derived data (use sparingly)
clean:
	rm -rf ~/Library/Developer/Xcode/DerivedData/BaylanIOS-*

## Run shared package tests (no simulator required)
test-core:
	cd shared && swift test

## Run all steps for a fresh checkout
bootstrap: resolve generate
	@echo "✓ BaylanIOS.xcodeproj generated. Run 'make open' to launch Xcode."
