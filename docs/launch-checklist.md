# Launch checklist

Everything left before Status for Slack is public. Audited on 2026-11-14 against `seo-custom-domain` (32ad1e5), the live site, the Vercel project and App Store guidance.

**Who acts:** **[You]** means App Store Connect, the Slack app settings, accounts or anything else only you can sign in to. **[Code]** means a change in this repo, then a commit, build or deploy.

## Blockers

These block approval or leave the launch broken. Do them in order.

1. ~~**[You] Merge the open work into `main`.**~~ Done on 2026-11-14: PR #1 merged into `landing-page`, and `landing-page` merged into `main`. Merge PR [LauraBeatris/slack-status-watch#1](https://github.com/LauraBeatris/slack-status-watch/pull/1) (`seo-custom-domain` → `landing-page`; it's no longer a draft and has no conflicts), then merge `landing-page` into `main`. Until then:
   - Production on Vercel runs `seo-custom-domain`, which isn't on any shared branch. A deploy from `main` or `landing-page` would drop the custom domain redirects in `web/vercel.json` and the new SEO.
   - `AppStore/listing.md` on `main` still has the rejected subtitle, "Set it from your Apple Watch".
2. ~~**[Code] Declare UserDefaults in both privacy manifests.**~~ Done in e2b21e8. The demo store in `Packages/SlackStatusKit/Sources/SlackStatusKit/DemoWorkspace.swift` uses `UserDefaults`, a required-reason API. `Apps/Phone/PrivacyInfo.xcprivacy` and `Apps/Watch/PrivacyInfo.xcprivacy` both have an empty `NSPrivacyAccessedAPITypes`. Add `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`. Without it, App Store Connect flags the build (ITMS-91053) and can refuse it. Build 4 added the demo, so it's the first build affected.
3. ~~**[Code] Upload a new build.**~~ Done on 2026-11-14: build 5 (1.0.0) uploaded to App Store Connect. The manifest fix needs a new binary:
   - Bump `CURRENT_PROJECT_VERSION` in `project.yml` from 4 to 5 and run `xcodegen`. Keep `MARKETING_VERSION` at 1.0.0.
   - Archive the `Status` scheme in Release and upload with `ExportOptions.plist`.
   - In `AppStore/listing.md`, the review notes say "build 4 adds a demonstration mode". Change it to the build you submit.
4. **[You] Fix the App Store Connect metadata the last review rejected.** Copy it from `AppStore/listing.md`:
   - Subtitle: `One-tap status from your wrist` (30/30 characters).
   - Keywords: the new list without `apple watch` (93/100 characters).
   - Reply to the 5.2.5 rejection in Resolution Center when you resubmit.
5. **[You] Fill in App Review Information** (App Store Connect → version → App Review Information):
   - Demo account email and password for `statusforslackreview.slack.com`. Before submitting, sign in with them once to confirm they still work.
   - Contact name, email and phone.
   - Paste the notes from `AppStore/listing.md`.
6. **[You] Confirm public distribution is on for the Slack app.** Confirmed on 2026-11-14: "Publicly Distributed". Still to do: the sign-in test from a second workspace below. At api.slack.com/apps → Status for Slack → Manage Distribution, it must say "Distributed". Without it, only your own workspace can sign in, and App Review's live-Slack path fails. Then sign in from a second workspace you don't own, on a Release build: it should land on the presets with the right workspace name.
7. **[You] Set the App Store Connect URLs.** Use `www.statusforslack.app` for all three (they're already in `AppStore/listing.md`):
   - Support URL: `https://www.statusforslack.app/support`
   - Marketing URL: `https://www.statusforslack.app`
   - Privacy Policy URL: `https://www.statusforslack.app/privacy`
8. **[You] Choose manual release.** In App Store Connect → version → Version Release, pick "Manually release this version". The App Store ID only exists after approval, and the site needs it before people arrive (see "After approval").

## iOS and watchOS app

- **[Code] Verified, nothing to do:** these are all in place.
  - `DEVELOPMENT_TEAM` (`NT9X9TFUK3`) and automatic signing are set in `project.yml`, and `Status.xcodeproj` matches it.
  - `ITSAppUsesNonExemptEncryption` is `false` in both Info.plists.
  - The pasted-token sign-in (`Apps/Phone/ContentView.swift`) and the `-screenshots` mode (`PhoneModel.swift`, `WatchModel.swift`) are wrapped in `#if DEBUG`, so Release builds don't have them.
  - There are no TODOs or FIXMEs in `Apps/` or `Packages/`.
  - `swift test` in `Packages/SlackStatusKit` passes (38 tests).
- **[You] Keep or drop the demo in the public release.** "Try the demo" ships in Release on both devices, on purpose: App Review needs it. Keeping it is fine and helps people try the app before connecting a workspace. If you drop it later, App Review needs another way past Slack's emailed code.
- **[You] Test on real devices.** Install the uploaded build through TestFlight on an iPhone with iOS 27 and a paired watch with watchOS 26 or later. Check:
  - Sign in syncs the token to the watch.
  - A watch tap sets the status in Slack.
  - Expiry clears the status.
  - "Set Status to Lunch" and "Clear Status" work in Siri on both devices.
  - Disconnect clears both devices and revokes the token in Slack.
- **[You] Check the deployment targets are what you want.** iOS 27.0 and watchOS 26.0 (`project.yml`, `Packages/SlackStatusKit/Package.swift`) leave out anyone still on iOS 26.

## Slack app

- **[You] Match the live Slack app to `slack-app-manifest.json`:**
  - Redirect URL: `https://status-for-slack.vercel.app/api/slack/callback`.
  - User scopes: `users.profile:read` and `users.profile:write`, with no bot scopes.
  - Token rotation: off.
  - Client ID: `3972288438658.12386965455574`, the same in `project.yml` and the Vercel `SLACK_CLIENT_ID`.
- **[You] Finish the Slack app's display info.** Slack shows it on the consent screen: add the app icon, a background colour, a short description and a long description in Basic Information → Display Information. **[Code]** Optionally, mirror them in the manifest's `display_information` (`long_description`, `background_color`) so a rebuild from the manifest keeps them.
- **[You] Keep the redirect URI on `vercel.app`.** The callback (`web/api/slack/callback.ts`) builds `redirect_uri` from its own origin, so it must stay where Slack has it registered. Moving it to `www.statusforslack.app` takes four steps: add the new URL in Slack, change `SLACK_OAUTH_REDIRECT_URL` in `project.yml`, ship a new build, and keep the old URL for older builds. That can wait until after launch.
- **[You] Decide on the Slack Marketplace (optional for GA).** Public distribution is enough for any workspace to sign in. A Marketplace listing adds discoverability, but Slack reviews it first: it checks a support email, privacy policy, icon and descriptions, and that the name uses "for Slack" only to mark a third-party integration, which "Status for Slack" does ([Slack's checklist](https://docs.slack.dev/slack-marketplace/is-your-slack-app-ready-for-the-slack-marketplace)).

## App Store

- **[You] Check App Information against `AppStore/listing.md`:**
  - Name: Status for Slack.
  - Categories: Productivity, then Business.
  - Age rating: 4+.
  - Price: free, all countries.
  - Copyright: `2026 Laura Serafim`.
- **[You] Answer App Privacy with "No, we do not collect data from this app".** Then publish the privacy answers. They have to be live before you submit.
- **[You] Reconsider the Content Rights answer.** The listing says the app does not access third-party content, but it reads and writes the user's Slack status. Answering "Yes" (with rights to use it) is the safer choice.
- **[You] Upload the screenshots.**
  - iPhone 6.9": the five files in `AppStore/iphone-6.9/`, in order.
  - Apple Watch: the two files in `AppStore/watch/`.
  - `AppStore/iphone-6.3/` is optional.
- **[You] Paste the promotional text and description** from `AppStore/listing.md`. "Apple Watch" in the description is allowed. The trademark rule was about the subtitle.
- **[You] Know the trademark risks.** The keywords still have `siri` and `shortcuts`, both Apple marks, and the name uses Slack's. Neither was flagged so far. If review raises it, drop `siri` from the keywords first.

## Web

- ~~**[Code] Update the privacy policy.**~~ Done on 2026-11-14. `web/public/privacy.html`:
  - Remove "To revoke the app's access on Slack's side, remove it under your Slack workspace's app settings". Since d158d19, Disconnect revokes the token itself.
  - Mention that demo mode keeps its simulated status on the device.
  - Add a contact email. A GitHub profile is the only contact on the privacy and support pages right now.
  - Update "Last updated" and the `privacy` `<lastmod>` in `web/public/sitemap.xml`.
- ~~**[Code] Update the support page.**~~ Done on 2026-11-14. `web/public/support.html`:
  - Add the same contact email.
  - Say that Disconnect also revokes access in Slack.
  - Explain "Try the demo".
- **[Code] Deploy to production after the web edits.** Run `vercel --prod` from `web/`, after asking. Deploy from the merged branch, not `seo-custom-domain`.
- **[You] Add the site to Google Search Console.** Add the `statusforslack.app` domain property (DNS TXT record) or the `https://www.statusforslack.app` URL-prefix property, then submit `https://www.statusforslack.app/sitemap.xml`.
- **Verified on 2026-11-14:**
  - `www.statusforslack.app`, `/privacy`, `/support`, `/og.png` and `/sitemap.xml` return 200.
  - The apex and `status-for-slack.vercel.app` 308 to `www`.
  - `status-for-slack.vercel.app/api/slack/callback` answers without redirecting to `www`.
  - Vercel has `SLACK_CLIENT_ID` (production and preview) and `SLACK_CLIENT_SECRET` (production, sensitive).
  - No secrets are in the Git history.
  - Preview deployments have no client secret, so sign-in only works in production. That's fine.

## Legal and support

- ~~**[Code] Add the copyright and Slack disclaimer to every page.**~~ Done on 2026-11-14. `web/public/privacy.html` and `web/public/support.html` have neither. Copy the footer from `web/public/index.html`: "© 2026 Laura Serafim. Status for Slack is an independent app and is not made by or affiliated with Slack Technologies." The App Store description and `README.md` already have the disclaimer.
- ~~**[You] Pick a public support email.**~~ Done on 2026-11-14: support@laurabeatris.com (a Resend inbox), now on the privacy and support pages. App Store Connect, Slack's display info and the web pages all need a way to reach you besides GitHub. GitHub issues are on and the repo is public, so "open an issue" works too.
- **[You] Know the domain trademark risk.** [Slack's brand terms](https://slack.com/terms-of-service/slack-brand) say not to register domains containing "slack". `statusforslack.app` does. It isn't a review blocker, but Slack could ask for it to change. Keep `status-for-slack.vercel.app` working as a fallback.
- **[You] Check that the name and copyright holder match.** The App Store copyright, the site footer and the JSON-LD author all say "Laura Serafim". Make sure it matches the name on your Apple Developer account, since the App Store shows that account name as the seller.

## After approval, before releasing

The App Store ID exists once the app is approved. Do these before you press Release:

1. **[Code] Replace both `https://apps.apple.com/app/id0000000000` placeholders in `web/public/index.html`** (lines 315 and 432) with the real ID.
2. **[Code] Add `<meta name="apple-itunes-app" content="app-id=…">`** to the `<head>` of `web/public/index.html`.
3. **[Code] Add the store link to the `MobileApplication` JSON-LD.** In `web/public/index.html`, add `downloadUrl` and `installUrl` with the App Store URL.
4. **[Code] Deploy to production** from `web/`, after asking.
5. **[You] Release the version** in App Store Connect. Then:
   - Check the product page is live in a few regions.
   - Check the site's buttons open it.
   - Test a sign-in from the App Store build.

## After launch

- **[You] Watch the Vercel logs.** In the first days, look at `/api/slack/callback` for `slack_unreachable` or `invalid_request` errors, and at App Store Connect crash reports.
- **[You] Re-check Search Console** a week later for indexing of `/`, `/support` and `/privacy`.
