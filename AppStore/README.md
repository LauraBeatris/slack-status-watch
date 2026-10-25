# App Store screenshots

- `iphone-6.9/`: the five branded iPhone screenshots at 1320 x 2868, upload as the 6.9" set. App Store Connect scales them down for smaller iPhones.
- `watch/`: plain Apple Watch captures at 416 x 496, upload as the watch set.
- `header/`: the product page header at 3840 x 1646, from `design/header.html`. Render it with `--window-size=3840,1646`.
- `raw/`: the simulator captures the slides are built from.
- `design/`: one HTML file per slide plus `style.css`.

Both apps have a debug-only `-screenshots` launch argument that loads the default presets, marks Lunch active and skips the network, so captures never touch a real Slack account.

To regenerate a slide after editing its HTML:

```sh
cd AppStore/design
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars --force-device-scale-factor=1 --window-size=1320,2868 --screenshot=../iphone-6.9/01-hero.png "file://$PWD/01-hero.html"
```
