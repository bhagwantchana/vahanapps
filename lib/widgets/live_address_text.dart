import 'package:dio/dio.dart';
import 'package:fleet_monitor/constant/api.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/networks/network_api.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

/// Renders a human-readable street address for a lat/lng instead of the raw
/// decimal pair like "30.88321, 75.83512". Falls back to the lat/lng on
/// geocoder errors (no internet, throttled, etc).
///
/// Caches results in-memory across the app lifetime keyed by a coarse
/// 4-decimal rounding (~11 m granularity) — same parked car asked from
/// 20 different places won't hit the geocoder repeatedly.
class LiveAddressText extends StatefulWidget {
  const LiveAddressText({
    super.key,
    required this.latitude,
    required this.longitude,
    this.style,
    this.maxLines = 2,
    this.placeholderText,
  });

  final double latitude;
  final double longitude;
  final TextStyle? style;
  final int maxLines;
  final String? placeholderText;

  @override
  State<LiveAddressText> createState() => _LiveAddressTextState();
}

class _LiveAddressTextState extends State<LiveAddressText> {
  static final Map<String, String> _cache = <String, String>{};

  // In-flight lookups shared across widget instances. A Map of futures (not
  // a Set of keys) so that when multiple list cells of the same vehicle
  // render at once, the late instances await the SAME future and still get
  // the result instead of returning early and staying on raw lat/lng.
  static final Map<String, Future<String>> _inFlight =
      <String, Future<String>>{};

  String? _resolved;

  String _cacheKey(double lat, double lng) {
    return '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
  }

  @override
  void initState() {
    super.initState();
    _resolveAddress();
  }

  @override
  void didUpdateWidget(covariant LiveAddressText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _resolved = null;
      _resolveAddress();
    }
  }

  Future<void> _resolveAddress() async {
    if (widget.latitude == 0 && widget.longitude == 0) {
      return;
    }

    final key = _cacheKey(widget.latitude, widget.longitude);
    final cached = _cache[key];
    if (cached != null) {
      if (mounted) setState(() => _resolved = cached);
      return;
    }

    final resolved = await _inFlight.putIfAbsent(
      key,
      () => _lookupAddress(widget.latitude, widget.longitude, key)
          .whenComplete(() => _inFlight.remove(key)),
    );

    // Guard against a stale-async overwrite: this State may have been
    // recycled to different coords while the shared lookup was running.
    // Only apply the result if it still matches the CURRENT position.
    if (resolved.isNotEmpty &&
        mounted &&
        key == _cacheKey(widget.latitude, widget.longitude)) {
      setState(() => _resolved = resolved);
    }
  }

  /// Runs the actual hybrid lookup for one coordinate bucket. Exactly one
  /// of these runs per key at a time (see [_inFlight]); returns '' when
  /// neither the server nor the native geocoder produced an address.
  static Future<String> _lookupAddress(
      double lat, double lng, String key) async {
    // Hybrid resolver:
    //  1. Try server-side /api/geocodeAddress (single source of truth so
    //     web users see the SAME string mobile shows). Bounded 2 s so a
    //     dead endpoint doesn't block the UI.
    //  2. If server fails (404, timeout, network), fall back to the
    //     native Flutter geocoder so the user never sees raw lat/lng.
    //  3. Push the locally-resolved address back to /api/cacheAddress
    //     so the web map can later read it.
    var resolved = '';
    try {
      final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';
      if (token.isNotEmpty) {
        final response = await NetworkApi().sendRequest.post(
          AppUrl.geocodeAddress,
          data: FormData.fromMap(<String, dynamic>{
            'lat': lat,
            'lng': lng,
          }),
          options: NetworkApi.buildOptions(authToken: token),
        );
        final body = response.data;
        if (body is Map &&
            body['flag'] == 1 &&
            body['data'] is Map &&
            body['data']['address'] is String &&
            (body['data']['address'] as String).trim().isNotEmpty) {
          resolved = (body['data']['address'] as String).trim();
        }
      }
    } catch (_) {
      // Server unreachable / endpoint not deployed yet — fall through to
      // native geocoder.
    }

    // Native geocoder fallback. Slightly different wording than server
    // (Google data vs Nominatim) but at least the user sees a real
    // address instead of "30.8197, 75.8587". On success we also push the
    // address to the server cache so the web map converges over time.
    if (resolved.isEmpty) {
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          // POI-resistant build. On both Android and iOS the platform
          // geocoder puts the nearest business name in `p.name` AND often
          // in `p.subLocality` too (India OSM/Google: shop owners tag a
          // business — e.g. "Planifry" — as the locality). So:
          //   • never use p.name
          //   • require a real CITY/STATE anchor (locality OR
          //     administrativeArea). Without one we'd only have a street
          //     or a POI token → better to show the coordinate than a
          //     misleading single word.
          //   • keep subLocality only WITH a city, never standing alone.
          final street = (p.street ?? '').trim();
          final subLocality = (p.subLocality ?? '').trim();
          final locality = (p.locality ?? '').trim();
          final admin = (p.administrativeArea ?? '').trim();

          final hasAnchor = locality.isNotEmpty || admin.isNotEmpty;
          if (hasAnchor) {
            final parts = <String>[
              if (street.isNotEmpty) street,
              if (subLocality.isNotEmpty && locality.isNotEmpty) subLocality,
              if (locality.isNotEmpty) locality,
              if (admin.isNotEmpty) admin,
            ];
            final cleaned = <String>[];
            for (final part in parts) {
              if (part.trim().length < 2) continue;
              if (cleaned.isNotEmpty &&
                  cleaned.last.toLowerCase() == part.toLowerCase()) {
                continue;
              }
              cleaned.add(part.trim());
            }
            resolved = cleaned.join(', ');
            if (resolved.isNotEmpty) {
              _pushAddressToServer(lat, lng, resolved);
            }
          }
        }
      } catch (_) {
        // Both server and native geocoder failed — UI shows lat/lng.
      }
    }

    if (resolved.isNotEmpty) {
      _cache[key] = resolved;
    }
    return resolved;
  }

  /// Background push to /api/cacheAddress when the native geocoder
  /// resolved an address that the server hadn't cached yet. Lets the web
  /// map eventually read the same string. Fire-and-forget.
  static final Set<String> _pushedKeys = <String>{};
  static Future<void> _pushAddressToServer(
      double lat, double lng, String address) async {
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_pushedKeys.contains(key)) return;
    _pushedKeys.add(key);
    try {
      final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';
      if (token.isEmpty) return;
      await NetworkApi().sendRequest.post(
        AppUrl.cacheAddress,
        data: FormData.fromMap(<String, dynamic>{
          'lat': lat,
          'lng': lng,
          'address': address,
        }),
        options: NetworkApi.buildOptions(authToken: token),
      );
    } catch (_) {
      _pushedKeys.remove(key); // allow retry next app run
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.placeholderText ??
        '${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}';
    return Text(
      _resolved ?? fallback,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
