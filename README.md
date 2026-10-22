# Status for Slack

Set your Slack status from an Apple Watch. Tap a preset, done.

Personal tool: one workspace, a user token you paste once on the iPhone, presets you edit on the phone and tap on the watch.

## Layout

- `Packages/SlackStatusKit`: Slack client, presets, expiry math, emoji table, Keychain and preset file stores. Tested with Swift Testing, no simulator needed:

  ```sh
  cd Packages/SlackStatusKit && swift test
  ```

- `Apps/Phone`: token setup and preset list, sends both to the watch over WatchConnectivity.
- `Apps/Watch`: the preset list that calls Slack directly.
- `Status.xcodeproj` is checked in. `project.yml` is the XcodeGen spec it was generated from; run `xcodegen` after adding files or targets, or add them in Xcode and ignore the spec.

## Setup

1. Create a Slack app at <https://api.slack.com/apps> from `slack-app-manifest.json`, install it to your workspace and copy the User OAuth Token (`xoxp-…`).
2. In Xcode, sign into your Apple Developer account (Settings > Accounts) and pick the team on both targets.
3. Run the `Status` scheme on your iPhone. Paste the token. The watch app receives it the next time it opens.

## Emoji table

`SlackEmojiTable.swift` is generated from [emoji-data](https://github.com/iamcal/emoji-data) (MIT):

```sh
swift Scripts/generate-emoji-table.swift path/to/emoji.json > Packages/SlackStatusKit/Sources/SlackStatusKit/SlackEmojiTable.swift
```

## App icon

`Scripts/generate-app-icon.swift` draws the icon. The burger is from [Noto Emoji](https://github.com/googlefonts/noto-emoji) (`Scripts/icon-assets/burger.png`, licensed as in `Scripts/icon-assets/LICENSE`). Regenerate with:

```sh
swift Scripts/generate-app-icon.swift Apps/Phone/Assets.xcassets/AppIcon.appiconset/icon.png Scripts/icon-assets/burger.png
cp Apps/Phone/Assets.xcassets/AppIcon.appiconset/icon.png Apps/Watch/Assets.xcassets/AppIcon.appiconset/icon.png
```
