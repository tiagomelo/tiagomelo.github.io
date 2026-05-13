---
layout: page
title: Weight & Balance Calculator — Support
permalink: /wb-calculator/support
---

*Last updated: May 13, 2026*

Need help with **Weight & Balance Calculator**? This page is the official support channel for the app.

## Contact

Email: [tiagoharris@gmail.com](mailto:tiagoharris@gmail.com?subject=W%26B%20Calculator%20Support)

Please include:

- Device model (e.g. iPhone 15, iPad Pro 11")
- iOS / iPadOS version
- App version (About tab inside the app, or App Store listing)
- Aircraft model and a description of the calculation you were performing
- A short description of the issue and steps to reproduce
- Screenshots or a screen recording if possible

We aim to reply within **2 business days**.

## Important Disclaimer

This app is a **calculation assistant only**. Always verify weight and balance using the official aircraft Pilot's Operating Handbook (POH) / Airplane Flight Manual (AFM) and current aircraft records before flight. The starter aircraft library uses approximate published values for instructional purposes — review and adjust every profile against the actual aircraft documents and current empty weight / empty arm before relying on the App for a real flight.

## Frequently Asked Questions

### What do the calculations actually do?
The App computes total weight, total moment, and center of gravity (CG) from the aircraft's empty weight and arm plus every station you load. It then checks whether the resulting (CG, weight) point falls inside the aircraft's certified envelope and reports **Within envelope**, **Out of envelope** (forward, aft, or overweight), accordingly.

### How do I add my own aircraft?
Open the **Aircraft** tab → tap **+** in the top-right corner. You can either pick a starter template from the built-in library (Cessna 152, Cessna 172 N/P/R/S, Piper PA-28-161 / PA-28-181, Piper PA-34-200 Seneca II, Diamond DA-40) and customize it, or start from a blank profile. Set the empty weight, empty arm, MTOW, the stations (name, arm, kind), and the envelope corner points. Save when done.

### The starter values don't match my aircraft's POH. What do I change?
The starter library uses approximate, instructional values. For a real aircraft you must update at least the **empty weight** and **empty arm** to match the current weighing / equipment list on file for that tail number. Envelope corners and station arms should also be cross-checked against the POH for the specific year and model.

### How do I edit an aircraft profile?
On the **Aircraft** tab, swipe left on the aircraft you want to edit and tap **Edit** (the blue pencil). You can rename, change empty weight / arm / MTOW, add or remove stations, and adjust envelope corners. Save to keep the changes.

### How do I delete an aircraft profile?
On the **Aircraft** tab, swipe left on the aircraft and tap **Delete** (the red trash). A confirmation dialog appears so you don't lose work by accident.

### What is a "station"?
A station is a fixed loading point on the aircraft (front seats, rear seats, fuel, baggage compartment, etc.) with a known arm in inches aft of datum. You add a value in kg or lb on the loading screen and the App multiplies it by the arm to compute the moment. Single-engine trainers typically have 3–5 stations; light twins like the PA-34 Seneca II have 6–7.

### My aircraft has separate forward and aft baggage compartments. Can I model both?
Yes. Add two separate stations of kind **Baggage**, each with its own arm. The App treats every station independently.

### Why is my loading point red / "Out of envelope"?
The (CG, weight) result falls outside the polygon you defined in the aircraft's envelope. The status badge tells you which limit was violated: *Forward CG limit*, *Aft CG limit*, or *Overweight*. Reduce the offending station's weight (commonly the forward / aft baggage or fuel) and recompute.

### How does the **Avgas converter** work?
The Avgas tab converts between Litres, US Gallons, IMP Gallons, kg, and lb using a standard 100LL density of **0.72 kg/L** at 15°C. Volume conversions use the exact factors (3.785411784 L/US gal, 4.54609 L/IMP gal). Results match the rounded values printed on most flight school conversion charts within typical pilot rounding.

### How do I export a loading calculation to PDF?
On the **Loading** screen for an aircraft, tap the share icon in the top-right corner. The App generates a one-page A4 PDF with the aircraft identity, station loading table, totals, CG, in/out-of-envelope status, the envelope chart, and a timestamp. The system share sheet then opens so you can save the file, print it, AirDrop it, email it, or send it to any other share destination.

### Does the app sync across my devices?
No. Weight & Balance Calculator is intentionally **local-first**. Aircraft profiles stay on the device you entered them on. There is no iCloud sync, no account, and no backend.

### How do I back up my aircraft profiles?
The App's data is included in a standard **iCloud Backup** or **Finder/iTunes encrypted backup** of your device. Restoring the backup restores your aircraft profiles.

### Why did the app ask permission to track me?
On first launch, iOS shows the **App Tracking Transparency** prompt because the App displays banner ads via Google AdMob. Granting permission allows personalized ads; denying it switches to non-personalized ads. The App itself does not track you regardless of your choice. You can change the decision in **Settings → Privacy & Security → Tracking** at any time.

### How do I request a refund?
The App is currently free. If that changes in the future, App Store refunds are handled by Apple — visit [reportaproblem.apple.com](https://reportaproblem.apple.com) and select the purchase.

### The app crashes or freezes.
Force-quit the App and relaunch. If the issue persists, make sure iOS and the App are up to date, then email us with the details listed above.

## Privacy

See the [Privacy Policy](/wb-calculator/privacy) for details on what data the app does and does not collect.
