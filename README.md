# Status for Slack

Set your Slack status from an Apple Watch. Tap a preset, done.

One workspace, Sign in with Slack once on the iPhone, presets you edit on the phone and tap on the watch.

## Layout

- `Packages/SlackStatusKit`: Slack client, presets, expiry math, emoji table, Keychain and preset file stores. Tested with Swift Testing, no simulator needed:

  ```sh
  cd Packages/SlackStatusKit && swift test
  ```

- `Apps/Phone`: token setup and preset list, sends both to the watch over WatchConnectivity.
- `Apps/Watch`: the preset list that calls Slack directly.
- `web`: the Vercel function that finishes Slack OAuth. It swaps the code for a user token with the client secret and bounces back to the app on the `statusforslack://` scheme, so the token never ships in a log or in the binary.
- `Status.xcodeproj` is checked in. `project.yml` is the XcodeGen spec it was generated from; run `xcodegen` after adding files or targets, or add them in Xcode and ignore the spec.

## Setup

1. Create a Slack app at <https://api.slack.com/apps> from `slack-app-manifest.json`. Its redirect URL points at the Vercel deployment.
2. Deploy `web` to Vercel and set `SLACK_CLIENT_ID` and `SLACK_CLIENT_SECRET` (Basic Information on the Slack app page) as environment variables.
3. Put the client ID in `SLACK_CLIENT_ID` in `project.yml` (or in the `Status` target's build settings) and run `xcodegen`. `SLACK_OAUTH_REDIRECT_URL` is the deployed callback.
4. In Xcode, sign into your Apple Developer account (Settings > Accounts) and pick the team on both targets.
5. Run the `Status` scheme on your iPhone and tap Sign in with Slack. The watch app receives the token the next time it opens.

Without a client ID the app still accepts a pasted `xoxp-` User OAuth Token under "Use a token instead".

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
