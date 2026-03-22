# FileConverter

<img width="576" height="556" alt="Screenshot 2026-03-17 at 23 46 45" src="https://github.com/user-attachments/assets/5af82af4-f183-409d-a919-be6a72543376" />

[https://frozono9.github.io/FileConverter/](url)

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

## Production DMG (Recommended for Website Distribution)

For reliable installs from your own website, use Apple signing + notarization.

1. Sign in to your Apple Developer account and install your `Developer ID Application` certificate in Keychain Access.
2. Create a notarytool keychain profile once:

```bash
xcrun notarytool store-credentials FileConverterNotary \
	--apple-id "YOUR_APPLE_ID" \
	--team-id "YOUR_TEAM_ID" \
	--password "APP_SPECIFIC_PASSWORD"
```

3. Run the release script:

```bash
export DEVELOPER_ID_APP_CERT="Developer ID Application: YOUR NAME (TEAMID)"
export NOTARY_PROFILE="FileConverterNotary"
./scripts/release_notarized_dmg.sh
```

Output: `FileConverter-Installer.dmg` signed, notarized, and stapled.

This DMG opens with the normal drag-to-Applications flow, and on first launch the app shows onboarding automatically.

## Notes

- Finder extension behavior depends on macOS extension state and signing.
- If Finder menu state gets stale, restart Finder:

```bash
killall Finder
```
