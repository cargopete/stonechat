# App Store submission kit — stonechat

Paste-ready metadata + the reviewer notes that decide whether this app gets
approved. Bundle `com.stonechat.stonechat`, paid team TRG36N45GH.

---

## Listing copy

**Name:** `stonechat`
**Subtitle** (30 char): `Offline Bluetooth chat`

**Promotional text:**
> Chat with someone next to you over Bluetooth — no internet, no servers, no
> account. Just two phones talking directly, end-to-end encrypted.

**Description:**
> stonechat is offline, peer-to-peer messaging. Two phones talk directly to each
> other over Bluetooth — there is no server, no internet connection, and no
> account. Nothing you send ever leaves the two devices in the conversation.
>
> • No sign-up, no phone number, no email.
> • No servers — messages go straight from your phone to the other person's.
> • End-to-end encrypted (standard libsodium cryptography).
> • Works without any internet or mobile signal — handy when there's no Wi‑Fi,
>   no data, or you simply want a private, local conversation.
>
> How it works: open stonechat on two nearby iPhones with Bluetooth on. They
> discover each other, complete a secure handshake, and you can chat. Delivery is
> most reliable with at least one phone in the foreground.
>
> stonechat aims for casual, everyday privacy between two people who choose to
> connect. It is not a secure-messaging product hardened against determined
> forensic attackers.

**Keywords** (100 char):
`bluetooth,offline,chat,p2p,peer,nearby,messaging,private,encrypted,no internet,local`

**Support URL:** `https://stonechat-nbgn.vercel.app/support.html`
**Privacy Policy URL:** `https://stonechat-nbgn.vercel.app/privacy.html`
**Marketing URL** (optional): —

---

## Category, rating, privacy

- **Primary category:** Social Networking (Secondary: Utilities)
- **Age rating:** answer the questionnaire honestly. It's unrestricted 1:1
  communication with no content filtering (messages are end-to-end encrypted and
  never reach a server), so expect Apple to land it at **12+ or 17+** — that's
  fine; don't claim filtering you don't have.
- **App Privacy:** **"Data Not Collected"** (no servers, no analytics, nothing
  leaves the device).
- **Export compliance:** pre-answered in Info.plist
  (`ITSAppUsesNonExemptEncryption = false`) — standard exempt encryption.

---

## ⭐ App Review notes (paste into "Notes for Reviewer") — THE critical part

> IMPORTANT — HOW TO TEST THIS APP
>
> stonechat is an offline, peer-to-peer 1:1 chat that works ONLY over Bluetooth
> between two nearby iPhones. There is no server and no account, so it cannot be
> demonstrated on a single device or in the simulator (the simulator has no
> Bluetooth radio).
>
> To test:
> 1. Install stonechat on TWO physical iPhones.
> 2. Turn Bluetooth ON and grant the Bluetooth permission on both.
> 3. Open the app on both phones, kept within a few metres of each other.
> 4. They discover each other automatically and complete a handshake; you can
>    then send messages in both directions.
> Tip: keep at least one phone in the foreground with the screen on for the most
> reliable connection.
>
> A short demo video showing two iPhones exchanging messages is included with
> this submission. [If you'd like a live walkthrough, contact us and we'll
> arrange one.]
>
> Background Bluetooth: the app declares bluetooth-central and bluetooth-peripheral
> background modes solely to deliver messages while backgrounded — this is core
> functionality, not a workaround.
>
> Privacy/UGC: all content stays strictly between the two paired devices (no
> server, no public content, no discovery of strangers' content). A user only
> ever connects to a device that is physically next to them and that they choose
> to use; ending a session is as simple as closing the app or moving out of range.
>
> No login is required.

**→ Attach a demo video** (Chief, with two iPhones): 15–30s screen-recording of
two phones discovering each other and exchanging a message. This is the single
biggest factor in avoiding a "we were unable to review your app's features"
rejection (Guideline 2.1).

---

## Screenshots

The simulator has no Bluetooth, so a live conversation can't be captured there.
Options, best first:
1. **Two real iPhones** — screenshot an actual conversation (most honest/compelling).
2. **Dev seed** — insert demo messages into the local DB behind a `--dart-define`
   so the chat screen renders a populated conversation in the simulator (UI is
   real, data is seeded). Capture at 6.9" (1320×2868).
Either way: a few shots of the conversation view + the discovery/empty state.

---

## Checklist

1. ✅ Icon, iPhone-only, export-compliance flag
2. ✅ Privacy + support pages hosted
3. ⛔ Xcode signing: paid team + create App Group `group.com.stonechat`
4. ⛔ Archive → Distribute → Upload (Xcode Organizer)
5. 🟡 App Store Connect app record (`com.stonechat.stonechat`)
6. 🟡 Screenshots (two devices, or dev-seed)
7. 🟡 **Demo video** for review notes
8. 🟡 Listing: copy above, "Data Not Collected", category, age rating, URLs
9. ⛔ Submit for Review
