# google_places_sdk_plus

[![pub package](https://img.shields.io/pub/v/google_places_sdk_plus.svg)](https://pub.dev/packages/google_places_sdk_plus)
[![Tests](https://github.com/KamiloChinome/google_places_sdk_plus/actions/workflows/tests.yml/badge.svg)](https://github.com/KamiloChinome/google_places_sdk_plus/actions/workflows/tests.yml)

A Flutter plugin for the [Google Places API (New)](https://developers.google.com/maps/documentation/places/web-service/op-overview) using native SDKs on each platform.

Originally forked from [`flutter_google_places_sdk`](https://github.com/matanshukry/flutter_google_places_sdk). This package extends the original with full Places API (New) coverage, migrates away from deprecated endpoints, and is independently maintained.

## Features

- Full Places API (New) support (~45 Place fields, 30+ types)
- Autocomplete, Place Details, Place Photos
- Search by Text, Search Nearby
- Native SDK on Android and iOS, REST/HTTP on desktop, Maps JS API on web
- All platforms: Android, iOS, Web, Linux, macOS, Windows

## Platform Support

| Platform | Implementation | Notes |
|----------|---------------|-------|
| Android  | Native SDK    | Full API parity |
| iOS      | Native SDK    | `primaryType`, `primaryTypeDisplayName`, `shortFormattedAddress` not available in GMSPlace SDK 10.x |
| Web      | Maps JS API   | Full API parity |
| Linux    | REST/HTTP     | Requires API key with no platform restrictions |
| macOS    | REST/HTTP     | Requires API key with no platform restrictions |
| Windows  | REST/HTTP     | Requires API key with no platform restrictions |

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
```

## Repository Structure

| Package | Description |
|---------|-------------|
| [`google_places_sdk_plus`](google_places_sdk_plus/) | App-facing package |
| [`google_places_sdk_plus_platform_interface`](google_places_sdk_plus_platform_interface/) | Shared types, models, and platform interface |
| [`google_places_sdk_plus_android`](google_places_sdk_plus_android/) | Android implementation (Kotlin, native Places SDK) |
| [`google_places_sdk_plus_ios`](google_places_sdk_plus_ios/) | iOS implementation (Swift, native Places SDK) |
| [`google_places_sdk_plus_web`](google_places_sdk_plus_web/) | Web implementation (Maps JavaScript API) |
| [`google_places_sdk_plus_http`](google_places_sdk_plus_http/) | HTTP/REST implementation (used by desktop) |
| [`google_places_sdk_plus_linux`](google_places_sdk_plus_linux/) | Linux (delegates to HTTP) |
| [`google_places_sdk_plus_macos`](google_places_sdk_plus_macos/) | macOS (delegates to HTTP) |
| [`google_places_sdk_plus_windows`](google_places_sdk_plus_windows/) | Windows (delegates to HTTP) |

## Development

### Prerequisites

This project uses [FVM](https://fvm.app/) to pin the Flutter SDK version.

```bash
dart pub global activate fvm
fvm install
```

### Code Generation

After cloning, generate code before building:

```bash
cd google_places_sdk_plus_platform_interface
fvm dart run build_runner build --delete-conflicting-outputs

cd ../google_places_sdk_plus_http
fvm dart run build_runner build --delete-conflicting-outputs
```

### Running Tests

```bash
cd google_places_sdk_plus
fvm flutter test
```

### Running the Example App

```bash
cd google_places_sdk_plus/example
fvm flutter pub get
fvm flutter run
```

## Migrating from 0.x

See [MIGRATION.md](MIGRATION.md) for upgrade instructions. There are no breaking changes in 1.0.0.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `API key not valid` | Ensure Places API (New) is enabled in Google Cloud Console |
| `null` fields on iOS | Some fields (`primaryType`, `shortFormattedAddress`) are not available in GMSPlace SDK 10.x |
| Desktop `HTTP 403` | API key must not have platform restrictions (HTTP keys only) |
| `CLIENT_NOT_INITIALIZED` | Call `FlutterGooglePlacesSdk('YOUR_KEY')` before any API method |

## License

BSD-3-Clause. Original copyright (c) 2023 Matan Shukry. See [LICENSE](google_places_sdk_plus/LICENSE) for details.
