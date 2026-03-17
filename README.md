# FileConverter

FileConverter is a macOS menu bar app with a Finder extension that lets you convert files directly from the Finder right-click menu.

## Features

- Convert documents, images, media, and tabular files from Finder
- Finder context menu: `Convert to...`
- Optional SVG vectorization pipeline for raster images (`potrace`, optional `vpype`)
- First-run onboarding flow

## Install (for end users)

1. Open the installer DMG.
2. Drag `FileConverter.app` to `Applications`.
3. Open `FileConverter.app` from `Applications`.
4. Follow onboarding and enable the Finder extension in System Settings.

## Dependencies

Some conversions require external tools:

- `ffmpeg`
- `pandoc`
- `imagemagick` (`magick`)
- `potrace` (for raster -> SVG)
- `vpype` (optional SVG cleanup)
- `LibreOffice` (`soffice`)

Suggested install commands:

```bash
brew install ffmpeg pandoc imagemagick potrace
brew install --cask libreoffice
brew install pipx
pipx install vpype
```

## Build (local)

```bash
xcodebuild -project FileConverter.xcodeproj -scheme FileConverter -configuration Release -derivedDataPath build_release build
```

## Package DMG

```bash
./scripts/create_dmg.sh ./build_release/Build/Products/Release/FileConverter.app FileConverter-Installer.dmg
```

## Notes

- Finder extension behavior depends on macOS extension state and signing.
- If Finder menu state gets stale, restart Finder:

```bash
killall Finder
```
