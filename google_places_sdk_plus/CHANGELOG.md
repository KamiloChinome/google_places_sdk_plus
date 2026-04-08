## 0.5.9

* Fix: iOS `internationalPhoneNumber` returned `null` instead of the actual value — `GMSPlace.phoneNumber` already provides the international format (updated `google_places_sdk_plus_ios` to `0.3.7`)

## 0.5.8

* Fix: iOS `rating` and `userRatingsTotal` could still return `0`/`0.0` on some places — uses direct value checks now (updated `google_places_sdk_plus_ios` to `0.3.6`)

## 0.5.7

* Fix: iOS `rating` and `userRatingsTotal` returned `0` instead of `null` when a place has no ratings (updated `google_places_sdk_plus_ios` to `0.3.5`)

## 0.5.6

* Document per-platform field availability in README
* Update desktop READMEs — `fetchPlace` and `fetchPlacePhoto` are fully supported
* Photo references now use UUIDs instead of incrementing counters (Android, iOS)
* Photo metadata cache is properly cleared on `deinitialize()` (Android, iOS)
* Input validation: coordinates, radius, and photo dimensions return `FlutterError` for invalid values

## 0.5.5

* Fix cross-platform inconsistencies between Android and iOS native plugins:
  * PriceLevel serialization now returns identical string values on both platforms
  * Error codes are now consistent across platforms (`API_ERROR_AUTOCOMPLETE`, `API_ERROR_PLACE`, etc.)
  * Removed all debug `print()` statements from native plugins
  * Replaced unsafe force unwraps with proper error handling that returns `FlutterError`

## 0.5.4

* Fix: expose `newSessionToken` parameter in `fetchPlace()` — it was already defined in the platform interface but missing from the public API, preventing users from explicitly controlling session lifecycle.

## 0.5.3

* Fix: exceptions thrown by the library (e.g. network errors, API errors) were propagated twice — once to the caller's `try-catch` and again as an unhandled exception reaching `PlatformDispatcher.onError` / Crashlytics. Removed erroneous `throw` in `_waitFor` so errors are only delivered through the returned Future.

## 0.5.2

* Fix: iOS build failure — `'flutter_google_places_sdk_ios-Swift.h' file not found`. Updated `google_places_sdk_plus_ios` to `0.3.1`.

## 0.5.1

* Improved README with fork context, full feature list, and additional usage examples.

## 0.5.0

Initial release of `google_places_sdk_plus`.

* Full Google Places API (New) support — exclusively targets the new API
* Removed deprecated `useNewApi` parameter from constructor and `updateSettings()`
* All Place fields from the new API (~45 fields) including reviews, editorial summaries, service attributes, EV charge options, and more
* Autocomplete predictions, place details, place photos, text search, and nearby search
* Multi-platform support: Android, iOS, Web, Linux, macOS, Windows (via federated plugins)

> Forked from [flutter_google_places_sdk](https://pub.dev/packages/flutter_google_places_sdk) by Matan Shukry.
