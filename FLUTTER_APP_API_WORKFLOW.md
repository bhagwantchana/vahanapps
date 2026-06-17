# FleetMonitor360 Flutter App Workflow

Last updated: 2026-03-28

## Purpose

This document explains how the Flutter app is currently connected to the FleetMonitor360 backend, which files control each flow, and what to update when you change server, account, notification setup, or tracking links.

## Project Root

Flutter app root:

`C:\Users\jasha\Desktop\fleet_monitor\fleet_monitor`

Backend API root used by the app:

`G:\xamp\htdocs\fleetmonitor360_new\application\controllers\Api.php`

## Current Base API

The app currently points to:

`https://vahanconnect.com/api/`

This is defined in:

`lib/constant/api.dart`

Main endpoint constants:

- `login`
- `logout`
- `dashboard`
- `vehicleList`
- `vehicleTrack`
- `vehicleSettings`
- `updateVehicleSettings`
- `alerts`
- `markAlertRead`
- `myProfile`
- `profileUpdate`
- `saveFcmToken`
- `tripHistory`
- `renewPlans`

## App Architecture

The app follows this structure:

- `screens/` holds the main screens like splash, login, dashboard, profile, and vehicles.
- `widgets/` holds reusable UI pieces and the single vehicle tracking view.
- `repositorys/` makes the API calls.
- `cubits/` manages screen state and API result flow.
- `models/` maps API JSON into Dart objects.
- `services/local_notification.dart` manages Firebase Messaging and local notifications.
- `networks/network_api.dart` centralizes Dio config and auth headers.
- `constant/preferences.dart` and `constant/preferences_key.dart` store session values in shared preferences.

## Main User Flow

### 1. App Start

File:

`lib/main.dart`

Flow:

- Firebase is initialized.
- `CustomNotificationSoundService().initialize()` starts notification wiring.
- App launches with `SplashScreen.routeName`.

### 2. Splash Boot

File:

`lib/screens/splash_screen.dart`

Flow:

- Reads device token for notifications.
- Waits briefly for startup animation.
- Reads local session values:
  - `PreferencesKey.isLogin`
  - `PreferencesKey.token`
- Opens dashboard if the user already has a token.
- Opens login screen if session is missing.

### 3. Login

Files:

- `lib/providers/login_provider.dart`
- `lib/cubits/auth_cubit/auth_cubit.dart`
- `lib/repositorys/auth_repository.dart`

API:

- `POST /api/login`

Payload:

- `email`
- `password`
- `fcm_token`

Response use:

- reads `X-Auth-Token`
- reads `profile`
- reads `maps_url`

Local storage after success:

- login flag
- auth token
- user details used by the app

Important note:

The login repository immediately tries to sync FCM again through `saveFcmToken` if a token is already available.

### 4. Dashboard

Files:

- `lib/screens/dashboard.dart`
- `lib/screens/home_screen.dart`
- `lib/repositorys/home_repository.dart`

API:

- `POST /api/dashboard`

Dashboard response currently provides:

- `vehicleList`
- `vehicle_count`
- `maps_url`
- `legacy_maps_url`
- `unread_alert_count`
- `profile`

How the app uses it:

- `HomeScreen` loads `maps_url` inside `WebViewWidget`.
- Vehicle counters are calculated locally from returned vehicle records.
- Bell icon shows unread alert count.

## Vehicle Flow

### Vehicle List

Files:

- `lib/screens/vehicle_list.dart`
- `lib/repositorys/vehicle_repository.dart`

API:

- `POST /api/vehicleList`

Returned vehicle data is used for:

- vehicle name/number
- IMEI
- speed
- running or idle status
- primary tracking links
- settings flags

### Single Vehicle Tracking

Files:

- `lib/widgets/single_vehicle_track.dart`
- `lib/repositorys/single_track_repository.dart`

API:

- `POST /api/vehicleTrack`

Payload:

- `imei`

Backend behavior:

- validates that the vehicle belongs to the logged-in customer
- returns formatted vehicle record
- returns `settings`
- returns tracking URLs

Tracking URLs returned by backend:

- `tracking_url`
- `single_map_url`
- `google_tracking_url`
- `history_url`

How the app uses it:

- opens the vehicle's live map link inside a webview
- shows speed, engine state, battery, last update
- opens history URL externally
- updates notification and guard settings

## Vehicle Settings Flow

Files:

- `lib/widgets/single_vehicle_track.dart`
- `lib/repositorys/single_track_repository.dart`

API:

- `POST /api/updateVehicleSettings`

Main fields supported by backend:

- `vehicle_id`
- `imei`
- `v_notification`
- `v_overspeed`
- `geofence_lat`
- `geofence_lng`
- `geofence_radius`
- `guard_active`
- `guard_lat`
- `guard_lng`

Current app usage:

- toggle notifications on or off
- toggle parking guard on or off
- update overspeed limit
- update radius alert distance

Backend rules already present:

- if radius is `0`, geofence lat/lng are reset to `0.000000`
- if guard is off, guard lat/lng are reset to `0.000000`

## Alerts Flow

Files:

- `lib/widgets/alerts_screen.dart`
- `lib/repositorys/alerts_repository.dart`
- `lib/services/local_notification.dart`

APIs:

- `GET /api/alerts`
- `POST /api/markAlertRead`

Supported filters:

- `vehicle_id`
- `is_read`
- `alert_type`
- `limit`
- `offset`

Backend returns:

- alert records
- pagination meta
- unread count

Notification open behavior in the app:

- background or foreground notification tap opens dashboard
- dashboard tab index `2` is used for alerts

## Profile Flow

Files:

- `lib/screens/profile_screen.dart`
- `lib/repositorys/profile_repository.dart`

APIs:

- `POST /api/myProfile`
- `POST /api/profileUpdate`

Profile payload includes:

- id
- first name
- last name
- email
- phone
- username
- address
- country/state/city ids
- image
- image URL
- multi map URL

Update profile currently supports:

- first name
- last name
- email
- image upload

## Notification and FCM Flow

Main file:

`lib/services/local_notification.dart`

Flow:

- requests notification permission
- initializes local notification channel
- wires Firebase background, foreground, and notification tap handling
- reads FCM token
- stores FCM token locally
- sends token to backend with authenticated request

Backend API:

- `POST /api/saveFcmToken`

Backend token storage logic:

- token is stored in `tbl_auth_tokens`
- Android uses `android_device_token`
- iOS uses `ios_device_token`
- Web uses `web_device_token`

This means the app does not read FCM from a separate user profile table. It is tied to the login token/session table.

## Map Strategy

The app is configured to use web links instead of native maps for live tracking.

Current behavior:

- dashboard uses backend `maps_url`
- single vehicle screen uses backend `tracking_url` or `single_map_url`
- history opens backend `history_url`

This is good for your current project because your web tracking pages already handle the complex live map logic.

## API Authentication

File:

`lib/networks/network_api.dart`

The app sends:

- `Accept: application/json`
- `X-Auth-Token: <token>` when a user is logged in

This auth token comes from login and is stored in shared preferences.

## Session Storage

Files:

- `lib/constant/preferences.dart`
- `lib/constant/preferences_key.dart`

Current keys:

- `isLogin`
- `token`
- `fcmToken`

When moving the app to another account or backend, verify these values are still written and cleared correctly during login/logout.

## Backend Methods Used By Mobile

Current public methods exposed from `Api.php`:

- `login`
- `dashboard`
- `vehicleList`
- `vehicleTrack`
- `vehicleSettings`
- `updateVehicleSettings`
- `myProfile`
- `profileUpdate`
- `logout`
- `tripHistory`
- `alerts`
- `markAlertRead`
- `drivers`
- `assignDriver`
- `fuelLogs`
- `maintenance`
- `saveFcmToken`
- `renewPlans`

The Flutter app currently uses only a subset of these. The unused ones are still available for future app expansion.

## What To Change If You Switch Server

### Change API base URL

Update:

`lib/constant/api.dart`

Example:

- local: `http://localhost/fleetmonitor360_new/api/`
- online: `https://vahanconnect.com/api/`

### Check profile image and map URLs

Backend builds full URLs using `base_url()`, so after moving to a new domain, verify:

- profile image URLs
- dashboard map URL
- single tracking URL
- history URL

If any of these open the wrong server, the backend `base_url` config needs correction.

### Check Firebase app files

Android:

- `android/app/google-services.json`

iOS:

- `ios/Runner/GoogleService-Info.plist`

If you change package name, Firebase project, or app ownership, these files must match the new app registration.

## What To Change If You Switch Account Ownership

When moving from one business account or database to another, re-check:

- base API domain in `lib/constant/api.dart`
- login user group and token generation on backend
- FCM token storage in `tbl_auth_tokens`
- vehicle ownership joins in backend queries
- map URLs returned in `dashboard()` and `vehicleTrack()`
- customer-to-vehicle ownership validation in `Map_model`

## Sound Workflow

Current app notification service allows notification sound playback through the OS notification channel, but custom per-vehicle ignition sound selection is not fully wired into the Flutter asset layer yet.

Available prepared sound assets on backend project side:

`G:\xamp\htdocs\fleetmonitor360_new\mobile_assets\vehicle_sounds`

If you want app-side custom ignition sounds later, the normal flow is:

- copy selected sound assets into Flutter `assets/`
- register them in `pubspec.yaml`
- detect alert type like ignition on or ignition off
- choose sound by vehicle type such as bike, activa, car, bus, or truck

## Build Notes

Current Windows build issue:

- `android/local.properties` still points to old Mac SDK paths
- Flutter SDK is not installed on this PC yet
- Android SDK is not installed on this PC yet

Once those tools are installed, update:

`android/local.properties`

Expected Windows-style values:

- `sdk.dir=C:\\Users\\<user>\\AppData\\Local\\Android\\Sdk`
- `flutter.sdk=C:\\flutter`

## Recommended Next Checks

Before final production APK testing, verify these flows in order:

1. Login
2. Dashboard map open
3. Vehicle list load
4. Single vehicle live track open
5. Profile fetch and profile image update
6. FCM token save after login
7. Foreground notification receive
8. Notification tap opens Alerts tab
9. Alert read status update
10. Vehicle settings update for overspeed, radius, and parking guard

## Quick File Reference

Important Flutter files:

- `lib/main.dart`
- `lib/constant/api.dart`
- `lib/networks/network_api.dart`
- `lib/repositorys/auth_repository.dart`
- `lib/repositorys/home_repository.dart`
- `lib/repositorys/vehicle_repository.dart`
- `lib/repositorys/alerts_repository.dart`
- `lib/repositorys/profile_repository.dart`
- `lib/repositorys/single_track_repository.dart`
- `lib/services/local_notification.dart`
- `lib/screens/home_screen.dart`
- `lib/widgets/single_vehicle_track.dart`

Important backend files:

- `application/controllers/Api.php`
- `application/controllers/FleetApi.php`
- `application/models/Alerts_model.php`
- `application/models/Map_model.php`

## Final Note

This app is already aligned to a web-link tracking strategy, which is a good fit for your project. The safest maintenance approach is:

- keep all business rules and tracking links generated by backend
- keep Flutter focused on login, dashboard, alerts, profile, and screen flow
- expand app endpoints only when a screen really needs native data beyond the web tracking pages
