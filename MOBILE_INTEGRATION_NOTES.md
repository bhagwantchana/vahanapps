# Fleet Monitor App Integration Notes

## Current app flow

- Login uses `https://fleetmonitor360.cloud/api/login`
- Dashboard uses `dashboard.maps_url` for the live multi-vehicle web map
- Vehicle detail uses `tracking_url` / `single_map_url`
- History opens `history_url`
- Alerts come from `/api/alerts`
- Alert tap opens the related vehicle detail by IMEI
- Profile reads from `/api/myProfile` and updates through `/api/profileUpdate`
- Push token sync uses `/api/saveFcmToken`
- Vehicle notification and parking/radius settings update through `/api/updateVehicleSettings`

## Notification setup

- Android manifest now includes `POST_NOTIFICATIONS`
- Firebase config files are already present:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- The app now syncs refreshed FCM tokens back to the API automatically

## Important iOS note

iOS push notifications still require Apple capability setup in Xcode / Apple Developer:

1. Enable `Push Notifications`
2. Enable `Background Modes`
3. Turn on `Remote notifications`
4. Ensure the Runner target has APNs enabled for the correct bundle id

Without that Apple-side setup, Android notifications will work but iOS pushes will not arrive.

## Maps

- This app is now aligned for web-link-based tracking, not embedded Google Maps screens
- Placeholder native Google Maps key wiring was removed from Android/iOS bootstrap
- If you later reintroduce embedded native maps, you will need to add the proper Maps API key again

## Suggested next app steps

1. Run `flutter pub get`
2. Run `flutter analyze`
3. Build and test Android login + notification flow
4. Test one live ignition alert, one overspeed alert, and one radius alert
5. If you need custom ignition sounds later, add them under app assets and wire them into notification handling
