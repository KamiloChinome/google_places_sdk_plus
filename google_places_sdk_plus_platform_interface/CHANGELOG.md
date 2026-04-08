## 1.0.0

* Stable release
* Fix: `FetchPlaceResponse` internal factory class name corrected from `_FetchPlacePhotoResponseImage` to `_FetchPlaceResponse`

## 0.5.0

Initial release of `google_places_sdk_plus_platform_interface`.

* Full Google Places API (New) support — exclusively targets the new API
* Removed `useNewApi` parameter from `initialize()` and `updateSettings()`
* All Place fields from the new API (~45 fields) including primaryType, reviews, editorialSummary, service attributes, payment/parking/EV options, and more
* `PlaceField` enum covers all new API fields without v1/v2 distinction
* Support for `searchByText` and `searchNearby` operations
* `fetchPlacePhoto` uses photo reference-based approach

> Forked from [flutter_google_places_sdk](https://pub.dev/packages/flutter_google_places_sdk) by Matan Shukry.
