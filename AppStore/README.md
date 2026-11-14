# App Store assets

- `iphone-6.9/` (1320 x 2868) and `iphone-6.3/` (1206 x 2622): the five iPhone screenshots.
- `watch/` (416 x 496): plain Apple Watch captures.
- `header/`: the product page header and search results image, from `design/header.html` and `design/search-results.html`.
- `design/`: one HTML file per image plus `style.css`. `og.html` is the landing page's share card (`web/public/og.mp4` and `og.png`).
- `raw/`: the simulator captures the slides are built from.
- `listing.md`: the store listing copy.

Launch either app with `-screenshots` (debug builds) to load the default presets with Lunch active and no network calls.

Render a slide with headless Chrome at its size as `--window-size`:

```sh
cd AppStore/design
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars --force-device-scale-factor=1 --window-size=1320,2868 --screenshot=../iphone-6.9/01-hero.png "file://$PWD/01-hero.html"
```
