.PHONY: build test cli icon app run dmg install clean

build:
	swift build

test:
	swift run DiskPulseSelfTest

cli:
	swift build -c release --product diskpulse

icon:
	swift scripts/make-icon.swift Resources/AppIcon.icns

app:
	./scripts/build-app.sh

run: app
	open dist/DiskPulse.app

dmg: app
	./scripts/make-dmg.sh

install:
	@test -d dist/DiskPulse.app || (echo "error: dist/DiskPulse.app not found. Run 'make app' first." >&2; exit 1)
	install -d /Applications /usr/local/bin
	rm -rf /Applications/DiskPulse.app
	ditto dist/DiskPulse.app /Applications/DiskPulse.app
	install -m 755 dist/DiskPulse.app/Contents/Resources/diskpulse /usr/local/bin/diskpulse

clean:
	swift package clean
	rm -rf dist
