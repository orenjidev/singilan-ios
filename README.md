# Singilan iOS

Native SwiftUI prototype of Singilan Na, an offline-first bill-splitting app for iPhone.

## Prototype features

- Create, edit, duplicate, archive, and delete bills
- Assign people per item with equal or weighted splitting
- Record individual payments and calculate paid, owed, and remaining balances
- Add credits and service charges as bill line items
- View per-bill and cross-bill summaries
- Attach a payment QR image
- Export summaries as CSV or PNG and share through iOS
- Persist invoices locally as JSON with undo and redo support

## Requirements

- Xcode with the iOS 17 SDK or newer
- Swift 5.9 or newer

## Run

Open `Singilan-App.xcodeproj` in Xcode, select an iPhone simulator, and run the `Singilan-App` scheme.

Domain tests can also be run from Terminal:

```sh
swift test
```

The current prototype is intentionally offline-first. `APIClient.swift` is the integration boundary for connecting the native app to the Singilan Na backend in the next phase.
