# VahanConnect — Upcoming Features Roadmap
> Last Updated: 20 May 2026

---

## ✅ Recently Shipped (May 2026)

### ✅ 4. Multi-Language Support — DONE
- Punjabi, Hindi, English; user-selectable from Profile → Preferences
- `lib/cubits/settings_cubit/settings_cubit.dart` persists choice
- Strings table in `lib/l10n/app_strings.dart`

### ✅ 8. Geofence Alerts (client-side) — DONE
- Drawer → Geofence Zones
- Per-zone enable toggle, vehicle location picker
- Local notifications on entry/exit, evaluated on every dashboard refresh
- New files: `lib/models/geofence_zone.dart`, `lib/services/geofence_storage.dart`,
  `lib/services/geofence_monitor_service.dart`, `lib/screens/geofence_screen.dart`

### ✅ 9. Trip History Replay — DONE
- Drawer → Trip Replay
- Vehicle picker → today's track points → animated playback with play/pause + 1×/2×/4× speed
- New file: `lib/screens/trip_replay_screen.dart`

### ✅ 11. Dark Mode — DONE
- Profile → Preferences → Theme: System / Light / Dark
- `AppTheme.darkTheme` adapts AppBar, Scaffold, Card, inputs
- Note: many widgets still use hardcoded white colours — migrate incrementally

### ✅ 12. Quick Filter Chips (Vehicle List) — DONE
- Filters: All / Moving / Idle / Stopped / Offline / Low Battery
- Per-chip count badges, localised labels

### ✅ Home Map WebView refresh fix — DONE
- WebView loads once and stays, even though server regenerates encrypted token
- See `lib/screens/home_screen.dart::_initWebView`

---

## Phase 1 — Frontend Only (Still pending)

### 1. 📤 Share Location Button
- Vehicle card ਅਤੇ Vehicle detail screen ਵਿੱਚ "Share" ਬਟਨ
- Click ਕਰਨ 'ਤੇ WhatsApp/SMS ਰਾਹੀਂ Google Maps link ਸ਼ੇਅਰ ਹੋਵੇ
- Message format: Vehicle name, status, speed, address, map link
- `share_plus` package ਵਰਤਣਾ ਹੈ (already installed)

### 2. 🚨 Smart Alerts
- **Towing Alert** — Engine OFF ਪਰ Speed > 5 km/h (ਗੱਡੀ ਟੋਅ ਹੋ ਰਹੀ ਹੈ)
- **Night Driving Alert** — ਰਾਤ 11 PM ਤੋਂ 5 AM, ਗੱਡੀ ਚੱਲ ਰਹੀ ਹੈ
- **Long Idle Alert** — Engine ON + Speed 0 + 30 ਮਿੰਟ ਤੋਂ ਵੱਧ
- Client-side detection ਹਰ 30-second refresh 'ਤੇ
- New file: `lib/services/smart_alert_service.dart`

### 3. 📊 Multi-Vehicle Comparison
- 2-3 vehicles select ਕਰੋ ਅਤੇ side-by-side compare ਕਰੋ
- Speed, Battery, Distance, Engine status ਦੀ comparison
- Bar chart ਨਾਲ visual comparison
- Long-press ਨਾਲ multi-select mode
- New file: `lib/screens/vehicle_compare_screen.dart`

---

## Phase 2 — Backend API Required

### 5. ⛽ Fuel Analytics Dashboard
- Fuel level timeline chart
- Refill vs Drain events detection
- Per-vehicle fuel cost estimation
- Monthly consumption bar chart
- **Needs:** Backend API `POST /api/fuelAnalytics`
- **Needs:** Fuel sensor data from GPS devices (OR manual fuel entry)
- New files: `lib/screens/fuel_analytics_screen.dart`, `lib/repositorys/fuel_repository.dart`

### 6. 🏅 Driver Scorecard
- Driver leaderboard (ranking system)
- Radar chart — speed, braking, idle, distance, safety
- Color badges: 🟢 Excellent, 🟡 Good, 🔴 Needs Improvement
- Weekly/Monthly comparison
- **Needs:** Backend API `POST /api/driverScorecard`
- New file: `lib/screens/driver_scorecard_screen.dart`

### 7. 🕐 ETA Calculator
- Vehicle detail screen ਵਿੱਚ "ETA" ਬਟਨ
- Destination enter ਕਰੋ → estimated arrival time ਦਿਖੇ
- Current GPS location ਤੋਂ calculate
- **Needs:** Google Directions API Key (paid) ਜਾਂ OSRM (free)
- New file: `lib/widgets/eta_calculator_widget.dart`

---

## Notes
- Phase 1 ਦੇ features ਲਈ ਕੋਈ backend changes ਨਹੀਂ ਚਾਹੀਦੇ
- Phase 2 ਸ਼ੁਰੂ ਕਰਨ ਤੋਂ ਪਹਿਲਾਂ vahanconnect.com ਸਰਵਰ 'ਤੇ APIs ਬਣਾਉਣੀਆਂ ਪੈਣਗੀਆਂ
