## 1.1.1

* Migrate to built-in Kotlin: the Kotlin Gradle Plugin is now only applied on Android Gradle Plugin (AGP) versions below 9.0. AGP 9.0+ removed support for plugins applying KGP directly, which broke builds for apps on Flutter 3.44+ (see flutter/flutter#181383). The plugin still builds on Flutter 3.41–3.43.

## 1.1.0

* Update minimum SDK constraints: Dart >=3.11.0, Flutter >=3.41.0
* Verified compatibility with Flutter 3.41.6

## 1.0.0

* Stable release — version aligned with all packages

## 0.4.3

* Use UUID for photo references instead of incrementing counter
* Clear photo metadata cache on `deinitialize()`
* Validate coordinate ranges, radius, and photo dimensions — return `FlutterError` for invalid values

## 0.4.2

* Remove all `print()` debug statements from native plugin
* Replace force unwraps (`!!`) with safe null checks that return `FlutterError` instead of crashing
* Add `requireClient()` guard — returns `CLIENT_NOT_INITIALIZED` error if called before `initialize()`

## 0.4.1

* Fix: session token was not cleared after `fetchPlace()`, causing subsequent autocomplete searches to reuse a stale token and break session billing boundaries. The token is now invalidated after every `fetchPlace()` call.

## 0.4.0

Initial release of `google_places_sdk_plus_android`.

* Full Google Places API (New) support — exclusively targets the new API
* Removed `useNewApi` parameter from `initialize()` and `updateSettings()`
* Serializes all new Places API (New) fields: primaryType, primaryTypeDisplayName, shortFormattedAddress, editorialSummary, googleMapsUri, googleMapsLinks, timeZone, postalAddress, currentOpeningHours, secondaryOpeningHours, and all boolean service attributes
* Serializes complex types: paymentOptions, parkingOptions, evChargeOptions, fuelOptions, accessibilityOptions, priceRange
* Serializes AI/generative summaries: generativeSummary, reviewSummary, neighborhoodSummary, evChargeAmenitySummary
* Serializes relational data: subDestinations, containingPlaces, addressDescriptor, consumerAlerts
* authorAttributions, flagContentUri, and googleMapsUri in photo metadata
* Photo metadata cached on the Android side

> Forked from [flutter_google_places_sdk](https://pub.dev/packages/flutter_google_places_sdk) by Matan Shukry.
