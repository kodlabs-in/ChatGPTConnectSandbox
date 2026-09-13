.PHONY: check format lint

SWIFT_SOURCES := ChatGPTConnectSandbox

check: lint

format:
	swift format --in-place --recursive --configuration .swift-format $(SWIFT_SOURCES)

lint:
	swift format lint --recursive --configuration .swift-format $(SWIFT_SOURCES)
	swiftlint lint --no-cache --strict --config .swiftlint.yml
