---
layout: page
title: ChronoSum — Support
permalink: /chrono-sum/support
---

*Last updated: May 24, 2026*

Need help with **ChronoSum**? This page is the official support channel for the app.

## Contact

Email: [tiagoharris@gmail.com](mailto:tiagoharris@gmail.com?subject=ChronoSum%20Support)

Please include:

- Device model (e.g. iPhone 15, iPad Pro 11")
- iOS / iPadOS version
- App version (Settings tab inside the app → Version, or App Store listing)
- A short description of the issue and steps to reproduce
- Screenshots or a screen recording if possible

We aim to reply within **2 business days**.

## Frequently Asked Questions

### How do I add a duration to the tape?
Tap the keypad to type a duration — digits plus `h` and `m`. For example, **1**, **h**, **3**, **0** gives `1h30`. Then press **+** or **−** to commit it. The first entry on the tape is always an implicit add; subsequent entries use whichever sign you queued next.

### Why is there a `+` (or `−`) chip next to the draft?
That chip shows the **sign that will be applied to the next entry you commit**, exactly like a physical calculator. Press `+` or `−` after typing a number to commit it *and* queue the new sign for the next one. Press `=` to commit using the currently-queued sign.

### What's the difference between `=` and `+` ?
`+` commits the current draft *and* queues `+` for the next entry. `=` commits the current draft using whatever sign is already queued, without changing it. If you only want to do a single duration with no continuation, `=` is fine.

### How do I edit or delete an entry?
**Tap** a row to load it back into the draft for editing — change the value or the operator, then press `+`/`−`/`=` to save. **Swipe left** on a row to delete it. **Swipe right** on a row to flip its `+` ↔ `−`. The running total recomputes immediately.

### What does the orange **C** button do?
**C** clears everything instantly — the draft, every entry on the tape, and the queued operator. There is no confirmation, because the same action is also available with confirmation through the `…` menu in the top-right ("Clear all").

### How do I save a calculation?
Tap the **…** menu in the top-right of the Calculator → **Save**. The current tape is stored in your local History. Open the **History** tab to see saved calculations, tap any of them to load it back into the calculator.

### Can I edit a calculation that was loaded from History?
Yes — once loaded, the tape behaves like any other working calculation. Edits do not modify the original saved record. To keep the changes, save the calculation again from the `…` menu; this creates a new entry in History.

### How do I share a calculation?
Tap the **…** menu → **Share**. ChronoSum builds a plain-text arithmetic block (right-aligned values, separator line, total) and opens the iOS share sheet. Paste it into WhatsApp, Mail, Notes, or anywhere else.

### How are the durations parsed?
The keypad lets you type integers plus `h` and `m`. Examples: `1h30` = 1 hour 30 minutes, `90m` = 90 minutes, `2h` = 2 hours. A bare number (e.g. `45`) is interpreted as minutes by default; you can change that in **Settings → Plain number means → Hours**.

### How do I change the display format?
Open **Settings → Display format**. You can choose **Hours & minutes** (e.g. `3h 09m`), **Compact** (`3h09`), or **Decimal hours** (`3.15h`). The change applies everywhere — total, tape, history, and the shared text.

### What does the **plain number means** setting do?
It controls how a number with no `h` or `m` suffix is read. The default is **Minutes** (so `45` = 45 minutes). Set it to **Hours** if you usually punch in whole hours and want `8` to mean 8 hours.

### Does ChronoSum sync across my devices?
No. ChronoSum is intentionally **local-first**. Calculations and preferences stay on the device you entered them on. There is no iCloud sync, no account, and no backend.

### How do I back up my saved calculations?
The App's data is included in a standard **iCloud Backup** or **Finder/iTunes encrypted backup** of your device. Restoring the backup restores your saved calculations.

### Why did the app ask permission to track me?
On first launch, iOS shows the **App Tracking Transparency** prompt because the App displays banner ads via Google AdMob. Granting permission allows personalized ads; denying it switches to non-personalized ads. The App itself does not track you regardless of your choice. You can change the decision in **Settings → Privacy & Security → Tracking** at any time.

### How do I request a refund?
The App is currently free. If that changes in the future, App Store refunds are handled by Apple — visit [reportaproblem.apple.com](https://reportaproblem.apple.com) and select the purchase.

### The app crashes or freezes.
Force-quit the App and relaunch. If the issue persists, make sure iOS and the app are up to date, then email us with the details listed above.

## Privacy

See the [Privacy Policy](/chrono-sum/privacy) for details on what data the app does and does not collect.
