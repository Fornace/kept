# Kept

Receipts and warranties, kept.

Photograph a receipt, or hand Kept a PDF, and it reads the shop, the date and the total on device.
Then it counts down the two dates that cost money: the last day to return the thing, and the day its
warranty ends.

- iPhone and Mac from one SwiftUI multiplatform project, iOS 26 / macOS 26, built with Xcode 27.2.
- Vision for the document read, Apple Intelligence (Foundation Models) for interpreting the receipt
  when the device has it, SwiftData for the store, WidgetKit and App Intents for the surfaces,
  UserNotifications for the reminders.
- No account, no server, no analytics. The photo never leaves the device.

## Build

```
xcodebuild -project Kept.xcodeproj -scheme Kept -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' build

xcodebuild -project Kept.xcodeproj -scheme Kept -configuration Debug \
  -destination 'platform=macOS' build
```

Signing: the project is set up for Fornace s.r.l. (team 2V6YSU4HFB). App Groups are declared for the
widget snapshot; a local unsigned build falls back to the app's own Application Support directory,
which the store asks the file system about rather than assuming.

## Layout

- `Kept/` app target: `Desk/`, `Library/`, `Detail/`, `Capture/`, `Review/`, `Extraction/`, `Model/`,
  `Intents/`, `Notifications/`, `Platform/`, `Components/`, `Settings/`.
- `KeptKit/` local package: coverage maths, the widget snapshot, categories, palette. Shared by the
  app and the widget, and testable on its own.
- `KeptWidgets/` widget extension: small, medium and lock-screen deadline widgets.
- `tools/seed/` builds a store from real receipt photographs with the app's own reader, for captures.
- `AppStore/` listing copy and screenshots.

## Support

Open an issue: https://github.com/Fornace/kept/issues
