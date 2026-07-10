## 1.1.3

* Fix Android build failure `cannot find symbol ... FlutterGooglePlacesSdkPlugin` in `GeneratedPluginRegistrant.java` (issue #36). The 1.1.1/1.1.2 migration decided whether to apply the Kotlin Gradle Plugin (KGP) from the AGP major version alone, assuming AGP 9.0+ always means built-in Kotlin compiles the plugin's Kotlin. But Flutter 3.44+ ships with built-in Kotlin **disabled** by default (`android.builtInKotlin=false` in the app's `gradle.properties`), even on AGP 9.0+. In that configuration KGP was skipped *and* built-in Kotlin was off, so the plugin's Kotlin was never compiled. The plugin now applies KGP unless the app has actually opted in to built-in Kotlin (`android.builtInKotlin=true`), which is the correct signal and keeps working on AGP 8.x and AGP 9.0+.

## 1.1.2

* Fix Android build failure `Could not find method kotlin()` on Flutter 3.44+ / AGP 9.0+ (issue #34). The 1.1.1 built-in-Kotlin migration still relied on the top-level `kotlin { }` Groovy accessor, which is not registered when Kotlin is provided by Flutter's built-in Kotlin rather than the `kotlin-android` plugin. The `jvmTarget` is now set via the typed `KotlinAndroidProjectExtension`, configured once the Kotlin plugin is present, so the build works on both AGP 8.x and AGP 9.0+.

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
