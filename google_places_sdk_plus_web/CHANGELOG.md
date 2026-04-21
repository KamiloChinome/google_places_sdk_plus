## 1.1.1

* Fix `findAutocompletePredictions` on web: `locationBias` was being mapped to the JS `locationRestriction` property, causing hard-filtered (often empty) results instead of biased ranking. Now correctly sets `locationBias` on the underlying `AutocompleteRequest`. Thanks @elitree (#27, #28).

## 1.1.0

* Update minimum SDK constraints: Dart >=3.11.0, Flutter >=3.41.0
* Verified compatibility with Flutter 3.41.6

## 1.0.0

* Stable release — version aligned with all packages

## 0.4.0

Initial release of `google_places_sdk_plus_web`.

* Full Google Places API (New) support — exclusively targets the new API
* Removed `useNewApi` parameter from `initialize()` and `updateSettings()`
* Uses `Place.fetchFields` and `AutocompleteSuggestion` (no deprecated APIs)
* Places field mapping handled on the web-implementation side

> Forked from [flutter_google_places_sdk](https://pub.dev/packages/flutter_google_places_sdk) by Matan Shukry.
