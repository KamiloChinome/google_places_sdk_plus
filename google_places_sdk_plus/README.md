# google_places_sdk_plus

[![pub package](https://img.shields.io/pub/v/google_places_sdk_plus.svg)](https://pub.dev/packages/google_places_sdk_plus)
[![Tests](https://github.com/KamiloChinome/google_places_sdk_plus/actions/workflows/tests.yml/badge.svg)](https://github.com/KamiloChinome/google_places_sdk_plus/actions/workflows/tests.yml)

A Flutter plugin for the [Google Places API (New)](https://developers.google.com/maps/documentation/places/web-service/op-overview) using native SDKs on each platform.

Originally forked from [`flutter_google_places_sdk`](https://github.com/matanshukry/flutter_google_places_sdk). This package extends the original with full Places API (New) coverage, migrates away from deprecated endpoints, and is independently maintained.

## Features

- Full Places API (New) support (~45 Place fields, 30+ place types)
- Autocomplete predictions
- Place details
- Place photos
- Search by text
- Search nearby
- Native SDK on Android and iOS, REST/HTTP on desktop, Maps JS API on web
- All platforms: Android, iOS, Web, Linux, macOS, Windows

## Installation

```yaml
dependencies:
  google_places_sdk_plus: ^1.0.0
```

## Quick Start

```dart
import 'package:google_places_sdk_plus/google_places_sdk_plus.dart';

// Initialize
final places = FlutterGooglePlacesSdk('YOUR_API_KEY');

// Autocomplete
final predictions = await places.findAutocompletePredictions('pizza');

// Place Details
final place = await places.fetchPlace(
  predictions.predictions.first.placeId,
  fields: [PlaceField.DisplayName, PlaceField.Location],
);

// Search by text
final results = await places.searchByText(
  'restaurants near Central Park',
  fields: [PlaceField.DisplayName, PlaceField.Rating],
);

// Search nearby
final nearby = await places.searchNearby(
  locationRestriction: CircularBounds(
    center: LatLng(lat: 40.7128, lng: -74.0060),
    radius: 500,
  ),
  fields: [PlaceField.DisplayName, PlaceField.PriceLevel],
);
```

## Place Photos

`fetchPlacePhoto` returns a `FetchPlacePhotoResponse`, a sealed union with **two variants** depending on the platform:

| Platform | Variant | Description |
|----------|---------|-------------|
| **iOS** | `FetchPlacePhotoResponse.image(Image)` | Raw image bytes (the iOS SDK returns `UIImage`, no URL available) |
| **Android, Web, Desktop** | `FetchPlacePhotoResponse.imageUrl(String)` | Resolved photo URL |

**You must handle both variants.** Using Freezed's `when` ensures compile-time safety:

```dart
final place = await places.fetchPlace(
  placeId,
  fields: [PlaceField.PhotoMetadatas],
);

final photoMetadata = place.place?.photoMetadatas?.first;
if (photoMetadata != null) {
  final response = await places.fetchPlacePhoto(photoMetadata);

  // Handle both platform responses
  final widget = response.when(
    image: (image) => image,                          // iOS: direct Image widget
    imageUrl: (url) => Image.network(url),            // Android/Web/Desktop: URL
  );
}
```

> **Common mistake:** If you only handle the `imageUrl` variant (e.g., using `CachedNetworkImage`), photos will fail on iOS. Always handle both cases.

## Web Usage

When using web support, enable the Maps JavaScript API in Google Cloud:

https://developers.google.com/maps/documentation/javascript/get-api-key

**Limitations:**
- Location restriction is not supported on web. See [Google issue tracker](https://issuetracker.google.com/issues/36219203).

## Why native SDKs?

Other plugins use HTTP web requests rather than the native SDK. Google allows you to restrict your API key to specific Android/iOS applications, but that only works with the native SDK. When using HTTP requests, your API key cannot be properly restricted.

This plugin uses native SDKs on mobile platforms for better security, and falls back to HTTP/REST on desktop platforms.

## Platform Field Availability

Not all `PlaceField` values are available on every platform. This is due to differences in the underlying SDKs (Android Places SDK, iOS Places SDK, Maps JavaScript API) — not limitations of this plugin.

Fields not listed below are supported on all platforms.

### Fields with limited support

| Field | Android | iOS | Web | Desktop |
|-------|:-------:|:---:|:---:|:-------:|
| `PrimaryType` | Yes | No | Yes | Yes |
| `PrimaryTypeDisplayName` | Yes | No | Yes | Yes |
| `ShortFormattedAddress` | Yes | No | No | Yes |
| `InternationalPhoneNumber` | Yes | Yes | Yes | Yes |
| `AdrFormatAddress` | Yes | No | Yes | Yes |
| `GoogleMapsUri` | Yes | No | Yes | Yes |
| `GoogleMapsLinks` | Yes | No | No | Yes |
| `TimeZone` | Yes | No | No | Yes |
| `CurrentSecondaryOpeningHours` | Yes | No | No | Yes |
| `PureServiceAreaBusiness` | Yes | No¹ | No | Yes |
| `ServesCocktails` | Yes | No | Yes | Yes |
| `ServesCoffee` | Yes | No | Yes | Yes |
| `ServesDessert` | Yes | No | Yes | Yes |
| `GoodForChildren` | Yes | No | Yes | Yes |
| `AllowsDogs` | Yes | No | Yes | Yes |
| `Restroom` | Yes | No | Yes | Yes |
| `GoodForGroups` | Yes | No | Yes | Yes |
| `GoodForWatchingSports` | Yes | No | Yes | Yes |
| `LiveMusic` | Yes | No | Yes | Yes |
| `OutdoorSeating` | Yes | No | Yes | Yes |
| `MenuForChildren` | Yes | No | Yes | Yes |
| `PaymentOptions` | Yes | No | No | Yes |
| `ParkingOptions` | Yes | No | No | Yes |
| `EvChargeOptions` | Yes | No | No | Yes |
| `FuelOptions` | Yes | No | No | Yes |
| `PriceRange` | Yes | No | No | Yes |
| `AccessibilityOptions` | Yes | Partial² | No | Yes |
| `GenerativeSummary` | Yes | No | No | Yes |
| `ReviewSummary` | Yes | No | No | Yes |
| `NeighborhoodSummary` | Yes | No | No | Yes |
| `EvChargeAmenitySummary` | Yes | No | No | Yes |
| `PostalAddress` | Yes | No | No | Yes |
| `SubDestinations` | Yes | No | No | Yes |
| `ContainingPlaces` | Yes | No | No | Yes |
| `AddressDescriptor` | Yes | No | No | Yes |
| `ConsumerAlerts` | Yes | No | No | Yes |

**Notes:**
1. iOS SDK exposes `pureServiceAreaBusiness` but it always returns `nil` in current versions.
2. iOS `AccessibilityOptions` only provides `wheelchairAccessibleEntrance`; the other three sub-fields (`wheelchairAccessibleParking`, `wheelchairAccessibleRestroom`, `wheelchairAccessibleSeating`) return `nil`.

**Desktop** = Linux, macOS, Windows (all use the REST API via `google_places_sdk_plus_http`).

## Package Structure

This is a federated plugin. The app-facing package (`google_places_sdk_plus`) depends on the following packages:

| Package | Description |
|---------|-------------|
| [`google_places_sdk_plus_platform_interface`](https://pub.dev/packages/google_places_sdk_plus_platform_interface) | Shared types, models, and platform interface |
| [`google_places_sdk_plus_android`](https://pub.dev/packages/google_places_sdk_plus_android) | Android implementation (Kotlin, native Places SDK) |
| [`google_places_sdk_plus_ios`](https://pub.dev/packages/google_places_sdk_plus_ios) | iOS implementation (Swift, native Places SDK) |
| [`google_places_sdk_plus_web`](https://pub.dev/packages/google_places_sdk_plus_web) | Web implementation (Maps JavaScript API) |
| [`google_places_sdk_plus_http`](https://pub.dev/packages/google_places_sdk_plus_http) | HTTP/REST implementation (used by desktop) |
| [`google_places_sdk_plus_linux`](https://pub.dev/packages/google_places_sdk_plus_linux) | Linux (delegates to HTTP) |
| [`google_places_sdk_plus_macos`](https://pub.dev/packages/google_places_sdk_plus_macos) | macOS (delegates to HTTP) |
| [`google_places_sdk_plus_windows`](https://pub.dev/packages/google_places_sdk_plus_windows) | Windows (delegates to HTTP) |

## Migrating from 0.x

See [MIGRATION.md](https://github.com/KamiloChinome/google_places_sdk_plus/blob/main/MIGRATION.md) for upgrade instructions. There are no breaking changes in 1.0.0.

## License

BSD-3-Clause. Original copyright (c) 2023 Matan Shukry. See [LICENSE](LICENSE) for details.
