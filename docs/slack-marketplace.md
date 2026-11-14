# Slack Marketplace submission

What to paste into **Submit to Slack Marketplace → Prepare & Submit** for the Status for Slack app (app ID `A0CHBSN88H5`, in the Status for Slack workspace). Slack's requirements are in [Slack Marketplace app guidelines and requirements](https://docs.slack.dev/slack-marketplace/slack-marketplace-app-guidelines-and-requirements).

## Before you submit

- **Install numbers.** Slack turns away apps on fewer than 10 active workspaces with fewer than 20 monthly active users. Active means used in the last 28 days, not counting sandboxes. Check **Manage Distribution → Installation Count**. Submit once both are met.
- **The app is on the App Store.** Slack's reviewers install it and test it, so it needs to be public, not TestFlight.
- **Add a collaborator.** Slack requires at least one besides you, under **Collaborators**.
- **Answer support email within 2 business days.** That's a listing requirement for support@laurabeatris.com.

## Listing

- **App name:** Status for Slack
- **Short description** (10 words or fewer): Set your Slack status from your Apple Watch
- **Pricing:** Free
- **Landing page:** https://www.wriststatus.com
- **Direct install URL:** https://status-for-slack.vercel.app/api/slack/install (302s to `slack.com/oauth/v2/authorize`)
- **Support page:** https://www.wriststatus.com/support
- **Privacy policy:** https://www.wriststatus.com/privacy

**Long description.** It leads with what changes in Slack, since Slack wants "meaningful in-Slack functionality":

```
Keep your team up to date on where you are, without opening Slack.

Status for Slack sets your Slack status from your Apple Watch. Tap a preset like Lunch, In a meeting or Focusing, and your status and emoji change in Slack right away, so your teammates see it next to your name in messages, DMs and your profile.

:alarm_clock: Clears itself. Every preset has an expiry, from 15 minutes to 4 hours or a time of day, so Slack never shows "In a meeting" at midnight.

:iphone: Presets you control. Start with Lunch, In a meeting, Focusing, Away and Out of office, or make your own on your iPhone with any Slack emoji.

:speaking_head_in_silhouette: Siri and Shortcuts. Say "Set Status to Lunch" or "Clear Status", or set your Slack status from any Shortcuts automation, like when a Focus mode turns on.

:lock: Private by design. The app only asks to read and set your own status. Your sign-in stays in the Keychain on your iPhone and Apple Watch. No accounts, no analytics, no tracking.

How it works: add Status for Slack to your workspace, install the free iPhone and Apple Watch app from the App Store, and sign in with Slack.

Status for Slack is an independent app and is not made by or affiliated with Slack Technologies.
```

## Scopes

Both are user scopes, because the app changes the signed-in person's own status, which only a user token can do.

- **`users.profile:write`:** sets and clears the person's status text, emoji and expiry when they tap a preset on Apple Watch, ask Siri or run a Shortcut.
- **`users.profile:read`:** reads the person's current status when they open the app, so the watch shows which preset is active even if they changed it from Slack on another device.

The app uses no bot token, no events and no other scopes.

## Security answers

- **Token storage:** the user token is stored only in the Keychain on the person's iPhone and Apple Watch. The server never stores or logs it. It hands the token to the app in a URL fragment, and web installs discard it.
- **OAuth `state`:** the app checks a random state on every sign-in. Website installs check the state against an HttpOnly, Secure, SameSite cookie.
- **TLS:** everything runs over HTTPS on Vercel, which uses TLS 1.2 or later.
- **Request verification:** the app receives no events, slash commands or interactivity from Slack, so it has no request-verification endpoint. The only incoming request is the OAuth redirect.
- **Disconnect:** calls `auth.revoke`, then deletes the token from both devices.

## Testing instructions for Slack's reviewers

```
Status for Slack sets your own Slack status from an iPhone and Apple Watch app.

1. Open https://www.wriststatus.com and click "Add to Slack" (or use the direct install URL). Approve the two profile permissions. You land on a confirmation page.
2. Install "Status for Slack" from the App Store on an iPhone: https://apps.apple.com/app/id6826875571
3. Open the app, tap "Sign in with Slack", and choose the same workspace.
4. Without an Apple Watch: say "Set Status to Lunch" to Siri on the iPhone (or run the "Set Status" action in the Shortcuts app). Your Slack status changes to Lunch with a hamburger emoji and clears after 1 hour. Say "Clear Status" to clear it.
5. With an Apple Watch: open Status on the watch and tap a preset. A checkmark marks the active preset.
6. On the iPhone, tap a preset to change its emoji, text or expiry. The change is used the next time you set it.
7. "Disconnect" in the iPhone app revokes the token in Slack and signs out on both devices.

Support: support@laurabeatris.com
```

## Images (required) and video (recommended)

Slack wants 1600 × 1000 PNG or JPG images under 2 MB that **show the app in Slack**. Capture Slack on a Mac with the window at that size, with the status set from the watch:

1. A Slack conversation where your name shows the 🍔 status emoji, with the watch (or a watch screenshot) tapping Lunch beside it.
2. Your Slack profile showing "In a meeting · Clears in 1 hour".
3. The status gone from Slack after it expired. Pair it with the preset's expiry on the iPhone.
4. Siri on the iPhone saying "Set Status to Lunch", next to the status in Slack.
5. Slack's install screen with the two profile permissions.

Video: 30–90 seconds on YouTube, public, captions on, ads off. It should show a watch tap, then the status appearing in Slack on a Mac.
