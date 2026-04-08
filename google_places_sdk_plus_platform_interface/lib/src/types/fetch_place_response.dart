import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_places_sdk_plus_platform_interface/src/types/place.dart';

part 'fetch_place_response.freezed.dart';

/// The response for a [FlutterGooglePlacesSdkPlatform.fetchPlace] request
@freezed
sealed class FetchPlaceResponse with _$FetchPlaceResponse {
  /// constructs a [FetchPlaceResponse] object.
  const factory FetchPlaceResponse(
    /// the Place returned by the response.
    Place? place,
  ) = _FetchPlaceResponse;
}
