## 0.3.7

* Fix: `internationalPhoneNumber` was hardcoded as `nil` — now maps to `GMSPlace.phoneNumber` which already returns the international format

## 0.3.6

* Fix: `rating` and `userRatingsTotal` still returned `0`/`0.0` on some places — changed check from `userRatingsTotal == 0` to direct value checks (`rating > 0`, `userRatingsTotal > 0`)

## 0.3.5

* Fix: `rating` and `userRatingsTotal` returned `0` instead of `null` when a place has no ratings, causing inconsistency with Android

## 0.3.4

* Use UUID for photo references instead of incrementing counter
* Clear photo metadata cache on `deinitialize()`
* Validate coordinate ranges, radius, and photo dimensions — return `FlutterError` for invalid values

## 0.3.3

* Remove all `print()` debug statements from native plugin
* Fix PriceLevel serialization to return string values matching Android (e.g. `"PRICE_LEVEL_MODERATE"` instead of raw int `2`)
* Fix error codes: autocomplete now returns `API_ERROR_AUTOCOMPLETE` and fetchPlace returns `API_ERROR_PLACE` (both previously returned generic `API_ERROR`)
* Replace force unwraps (`as!`) with safe `guard let` checks that return `FlutterError` instead of crashing
* Fix implicitly unwrapped optional return type on `getSessionToken()`

## 0.3.2

* Fix: session token was not cleared after `fetchPlace()`, causing subsequent autocomplete searches to reuse a stale token and break session billing boundaries. The token is now invalidated after every `fetchPlace()` call.

## 0.3.1

* Fix: Corrected Swift generated header import in `FlutterGooglePlacesSdkIosPlugin.m` — was referencing old module name `flutter_google_places_sdk_ios` instead of `google_places_sdk_plus_ios`, causing `'flutter_google_places_sdk_ios-Swift.h' file not found` build error.

## 0.3.0

Initial release of `google_places_sdk_plus_ios`.

* Full Google Places API (New) support — exclusively targets the new API
* Removed `useNewApi` parameter from `initialize()`
* Migrated all iOS API calls from Legacy to New Places API:
  * `findAutocompletePredictions` uses `GMSAutocompleteRequest` + `fetchAutocompleteSuggestions`
  * `fetchPlace` uses `GMSFetchPlaceRequest` + `fetchPlace` with `placeProperties`
  * `fetchPlacePhoto` uses `GMSFetchPhotoRequest` + `fetchPhoto` with configurable `maxSize`
* Implements `searchByText` and `searchNearby`
* Implements `updateSettings` for runtime API key and locale changes
* Serializes all new Place fields including reviews, service attributes, and photo metadata
* Swift Package Manager (SPM) support via `Package.swift`

> Forked from [flutter_google_places_sdk](https://pub.dev/packages/flutter_google_places_sdk) by Matan Shukry.
