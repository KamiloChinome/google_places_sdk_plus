# Migration Guide: 0.x to 1.0.0

## Overview

Version 1.0.0 marks the first stable release of `google_places_sdk_plus`. All 9 packages are now version-aligned at 1.0.0. The public API is fully backward-compatible with 0.5.x.

## Updating your dependency

```yaml
# Before
dependencies:
  google_places_sdk_plus: ^0.5.0

# After
dependencies:
  google_places_sdk_plus: ^1.0.0
```

## What changed

### New: `regionCode` parameter on `fetchPlace()`

`fetchPlace()` now accepts an optional `regionCode` parameter, matching the Google Places API (New) specification. This was already available on `searchByText()` and `searchNearby()`. No action required -- your existing calls work unchanged.

```dart
// Before (still works)
final response = await places.fetchPlace('placeId', fields: [PlaceField.DisplayName]);

// Now you can also pass regionCode
final response = await places.fetchPlace(
  'placeId',
  fields: [PlaceField.DisplayName],
  regionCode: 'CO',
);
```

### New: `deinitialize()` method

You can now call `deinitialize()` to reset the Places client to its uninitialized state. This is useful for cleanup or when switching API keys at runtime.

```dart
await places.deinitialize();
```

## Breaking changes

**There are no breaking changes in 1.0.0.** All existing 0.5.x code will compile and run without modification.

## Platform packages

If you depend on any platform package directly (uncommon), update all to `^1.0.0`:

| Package | Old | New |
|---------|-----|-----|
| `google_places_sdk_plus_platform_interface` | `^0.5.0` | `^1.0.0` |
| `google_places_sdk_plus_android` | `^0.4.0` | `^1.0.0` |
| `google_places_sdk_plus_ios` | `^0.3.0` | `^1.0.0` |
| `google_places_sdk_plus_web` | `^0.4.0` | `^1.0.0` |
| `google_places_sdk_plus_http` | `^0.4.0` | `^1.0.0` |
| `google_places_sdk_plus_linux` | `^0.4.0` | `^1.0.0` |
| `google_places_sdk_plus_macos` | `^0.4.0` | `^1.0.0` |
| `google_places_sdk_plus_windows` | `^0.4.0` | `^1.0.0` |
