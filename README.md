# Lumen

A SwiftUI iOS demo app styled as a rewards / cashback wallet. It packs about a dozen animations into one navigable app, and several screens gate their key action behind motion: a scratch-off you drag through, a card stack you swipe, a button that morphs into a loader. That combination is where selector-based UI test tools (Appium, Maestro, XCUITest) tend to flake, which is the reason this app exists.

There is no backend. All data is hardcoded mock data, with no auth and no networking. The app is the animation work.

The animations are adapted from the techniques in [Shubham0812/SwiftUI-Animations](https://github.com/Shubham0812/SwiftUI-Animations) and restyled into one product.

## Screens

- **Login**: a "LUMEN" wordmark that swirls in letter by letter, a bouncing tagline, focus-animated email and password fields, and a Sign In button that morphs into a spinner and then a checkmark before entering the app.
- **Wallet**: a count-up cashback balance, a depth-stacked deck of reward cards you drag to cycle, an auto-scrolling "trending" marquee, and a pulsing wifi-style sync indicator.
- **Offers**: a feed of cashback offers, each with a pop-and-burst like heart and an Add button whose icon flies to a cart badge. A refresh control fills a pill loader, then re-reveals the rows with a stagger. Tapping an offer opens the Redeem sheet.
- **Rewards**: the daily scratch-to-reveal card. Drag to scratch off the foil; past a threshold it reveals the prize with a confetti burst and a bouncing number, and a Claim button credits the balance. Shows a claimed state once redeemed.
- **Redeem**: a Confirm button that morphs into a determinate progress bar, then a self-drawing checkmark and confetti success state that credits the cashback.
- **Profile**: a gradient avatar header with stat chips, a light-switch that flips the whole app between dark and light, a rotating yin-yang round-up toggle, an infinity-shaped syncing loader, and sign-out.

## Animations

Text swirl, text bounce, animated login fields, submit-button morph, card swap, balance count-up, auto-scroller marquee, wifi signal, like button, add-to-cart fly, pill loader, scratch-to-reveal, confetti, progress button, self-drawing checkmark, light switch, yin-yang toggle, infinity loader.

## Tech

- SwiftUI, iOS 16.0+, no third-party packages.
- A `TabView` shell behind a login gate. `AppModel` (`ObservableObject`) holds all state and is injected with `@EnvironmentObject`.
- The animations are pure SwiftUI: `Canvas` for the scratch mask and confetti, `TimelineView` for the marquee, animated overlays for the fly-to-cart, `Shape` + `trim` for the checkmark, infinity loader, and yin-yang, plus `DragGesture`, `@FocusState`, and springs throughout.
- One screen per file under `Lumen/`. `LumenApp.swift` holds the app entry, theme, models, mock data, and shared components (`LumenSpinner`, `ConfettiView`); the rest are `Login`, `Wallet`, `Offers`, `Rewards`, `Redeem`, and `Profile`.

## Build

Open `Lumen.xcodeproj` in Xcode and run the `Lumen` scheme on any iOS Simulator.

The `Build` workflow in `.github/workflows/build.yml` compiles a Debug simulator `.app` and uploads it as the `Lumen-Simulator.app.zip` artifact on every push, pull request, or manual dispatch.

## Tests

The `tests/` folder holds the [Revyl](https://revyl.ai) test specs used to drive the app on a cloud device, one per flow (scratch reveal, wallet cards, offers, redeem, light switch, and a full animation tour), with a shared login module under `tests/modules/`. They are plain YAML describing each step in natural language, so they read as a walkthrough of what the app does even if you never run them.

## License

MIT. See [LICENSE](LICENSE).
