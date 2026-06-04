.PHONY: build run bundle install clean

# Quick dev build + run (debug, runs in foreground).
run:
	swift run

build:
	swift build -c release

# Package into AgentMeter.app
bundle:
	./scripts/bundle.sh release

# Build the bundle and copy it to /Applications, then (re)launch it.
install: bundle
	@pkill -x AgentMeter || true
	rm -rf /Applications/AgentMeter.app
	cp -R AgentMeter.app /Applications/AgentMeter.app
	open /Applications/AgentMeter.app
	@echo "✓ installed to /Applications and launched"

clean:
	rm -rf .build AgentMeter.app
