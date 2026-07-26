# VahanConnect — Release 1.1.0 (build 44)

Native Google Maps overhaul of the owner app (`fleet_monitor`). One version
number drives **both** platforms from `pubspec.yaml: version: 1.1.0+44`:

| Platform | User-facing version | Build number | Source |
|---|---|---|---|
| Android | `versionName 1.1.0` | `versionCode 44` | `flutter.versionName/Code` → pubspec |
| iOS | `CFBundleShortVersionString 1.1.0` | `CFBundleVersion 44` | `$(FLUTTER_BUILD_NAME/NUMBER)` → pubspec |

Next release: bump `pubspec.yaml` (e.g. `1.1.1+45`) — that's the ONLY change,
both stores pick it up.

---

## What's New (store "release notes" — user-facing)

**English**
- Brand-new live map, now powered by Google Maps with a full-screen fleet view.
- Vehicles are colour-coded by status (moving / idle / stopped / offline) with
  registration-number labels — tap any vehicle for instant details.
- Status filter bar: tap Running / Idle / Stopped / Offline / Overspeed to see
  just those vehicles.
- Smooth, jitter-free live tracking with a real route trail and a 3D
  Navigation mode.
- New Overview dashboard with a status pie chart, live traffic layer,
  satellite view, map themes, live location sharing and a trip speed graph.
- Choose your home screen (Live Map or Overview) and control notifications
  (all alerts, or essential only) from Settings.
- Faster, lighter and battery-friendly.

**Short (Play Store single-line)**
> New Google Maps live tracking, status filters, 3D navigation, overview
> dashboard, trip speed graph and battery improvements.

---

## Pre-release checklist (do these FIRST)

1. **Google Cloud (same project as the web key):**
   - Enable **Maps SDK for Android** (done) **and Maps SDK for iOS**.
   - Billing ON.
   - For production create **restricted** keys and swap them in:
     - Android key → restrict to app `com.globynix.fleetmonitor` + release SHA-1
       → `android/app/src/main/res/values/strings.xml` (`google_maps_api_key`).
     - iOS key → restrict to bundle id `com.globynix.fleetMonitor`
       → `ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey`).
   - (Testing currently uses the single unrestricted key `AIzaSy…nr88`.)
2. **Superadmin → Settings:** set **Default Map Provider = Google Maps** and
   **Mobile Map Mode = In-App Native Map** (this is what turns on the new map).
3. **Web:** FTP `application/views/web/webmaps/userDevicesMaps.php` to production
   (declutter + fleet-zoom fix for the URL/WebView map mode).
4. Merge the git branches after device testing:
   - app repo → `feat/native-google-maps`
   - web repo → `feat/webmap-declutter-zoom`

---

## Android — Play Store

1. Build the bundle (already produced): `flutter build appbundle --release`
   → `build/app/outputs/bundle/release/app-release.aab`
   (signed with `android/key.properties` → `upload.jks`).
2. Play Console → **Production** (or Internal testing first) → **Create new release**.
3. Upload `app-release.aab`.
4. Paste the release notes above, review, **Roll out**.
5. Existing users get the update; in-app force-update (already wired via
   `in_app_update`) prompts them on open.

---

## iOS — CodeMagic → TestFlight → App Store (no Mac needed)

The repo already has `codemagic.yaml` (workflow **ios-testflight**, bundle
`com.globynix.fleetMonitor`, Flutter pinned `3.41.9`). CodeMagic runs
`pod install` on a cloud Mac — that pulls the GoogleMaps pod automatically.

1. Push this app repo (with `feat/native-google-maps` merged) to the connected
   **private** git repo CodeMagic watches.
2. One-time CodeMagic setup (see the header comment in `codemagic.yaml`):
   - App Store Connect API key named **Codemagic**.
   - `signing` group var **CERT_KEY_B64** (base64 of the distribution cert key).
   - App created in App Store Connect with bundle `com.globynix.fleetMonitor`
     (Apple ID `6768335248`).
3. Make sure the **iOS Maps key** is set in `AppDelegate.swift` and **Maps SDK
   for iOS** is enabled + billed (step 1 above).
4. CodeMagic → open **ios-testflight** → **Start new build**. It signs, builds,
   and uploads to **TestFlight**.
5. Test on TestFlight, then submit to the **App Store** with the release notes.
6. (Pending, unrelated to maps) iOS push needs the **APNs Auth Key** uploaded to
   the Firebase project for notifications to fire on iOS.

---

## iOS feature parity — confirmed

Every new feature is pure Dart / cross-platform plugins, so iOS gets the exact
same functionality as Android:

| Feature | iOS support |
|---|---|
| Native Google map (fleet + single) | `google_maps_flutter` (iOS ✓) |
| Status markers, clusters, reg labels, pulse | `dart:ui` bitmap compose (✓) |
| Nav mode / themes / traffic / satellite | google_maps_flutter APIs (✓) |
| Snapshot share | `path_provider` + `share_plus` (iOS ✓) |
| Overview pie / trip speed graph | `fl_chart` (✓) |
| Dashboard switch / notification filter | `shared_preferences` (✓) |

No Android-only API is used. Minimum iOS 15.0 (Podfile + project target).

---

## NOT in this release (separate follow-ups)

- **`fleet_vendor` (vendor app)** was **not** changed — it still uses its old
  map. If the vendor app should also get the native Google map, that's a
  separate port of the same widgets.
- Server-side notification filtering (current filter is app-side).
- Schools features (parent bus-ETA alerts, public live link, bus stops).
