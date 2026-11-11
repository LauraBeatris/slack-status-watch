# App Store screenshots

- `iphone-6.9/`: the five branded iPhone screenshots at 1320 x 2868, upload as the 6.9" set. App Store Connect scales them down for smaller iPhones.
- `watch/`: plain Apple Watch captures at 416 x 496, upload as the watch set.
- `header/`: the product page header at 3840 x 1646 and the search results image at 3840 x 2560, from `design/header.html` and `design/search-results.html`. Render each with its size as `--window-size`.
- `raw/`: the simulator captures the slides are built from.
- `design/`: one HTML file per slide plus `style.css`.

Both apps have a debug-only `-screenshots` launch argument that loads the default presets, marks Lunch active and skips the network, so captures never touch a real Slack account.

To regenerate a slide after editing its HTML:

```sh
cd AppStore/design
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars --force-device-scale-factor=1 --window-size=1320,2868 --screenshot=../iphone-6.9/01-hero.png "file://$PWD/01-hero.html"
```

The landing page's share card comes from `design/og.html`, a six second loop of the watch tapping through the presets. Open the file in a browser to watch it. One command renders it to `web/public/og.mp4` (the `og:video`) and its first frame to `web/public/og.png` (the `og:image`), both at 1200 x 630:

```sh
node Scripts/render-og-video.mjs
```

It needs Chrome, Node 22 or later and Xcode's `swift`. Keep the loop seamless: the first frame is the poster, so the card has to end the way it starts.
