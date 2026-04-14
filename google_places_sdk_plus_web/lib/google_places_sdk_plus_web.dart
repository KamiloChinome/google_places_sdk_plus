@JS()
library places;

import 'dart:async';
import 'dart:developer';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:google_maps/google_maps.dart' as core;
import 'package:google_maps/google_maps_places.dart' as places;
import 'package:google_maps/google_maps_places.dart' hide PriceLevel;
import 'package:google_places_sdk_plus_platform_interface/google_places_sdk_plus_platform_interface.dart'
    as inter;
import 'package:google_places_sdk_plus_platform_interface/google_places_sdk_plus_platform_interface.dart';
import 'package:google_places_sdk_plus_web/extension.dart' as ext;
import 'package:web/web.dart' as html;

@JS('initMap')
external set _initMap(JSFunction f);

/// Web implementation plugin for flutter google places sdk
class FlutterGooglePlacesSdkWebPlugin extends FlutterGooglePlacesSdkPlatform {
  /// Register the plugin with the web implementation.
  /// Called by ?? when ??
  static void registerWith(Registrar registrar) {
    FlutterGooglePlacesSdkPlatform.instance = FlutterGooglePlacesSdkWebPlugin();
  }

  static const _scriptId = 'google_places_sdk_plus_web_script_id';

  Completer? _completer;

  bool _elementInjected = false;
  AutocompleteSessionToken? _lastSessionToken;

  // Language
  String? _language;

  // Cache for photos
  final _photosCache = <String, places.Photo>{};
  var _runningUid = 1;

  @override
  Future<void> deinitialize() async {
    // Nothing to do; there is no de-initialize for web
  }

  @override
  Future<void> initialize(String apiKey, {Locale? locale}) async {
    if (_elementInjected) {
      return;
    }

    final completer = Completer();
    _completer = completer;

    _initMap = _doInit.toJS;

    final html.Element? scriptExist = html.window.document.querySelector(
      '#$_scriptId',
    );
    if (scriptExist != null) {
      _doInit();
    } else {
      final body = html.window.document.querySelector('body')!;
      final src =
          'https://maps.googleapis.com/maps/api/js?key=$apiKey&loading=async&libraries=places&callback=initMap';
      if (locale?.languageCode != null) {
        _language = locale?.languageCode;
      }
      body.append(
        html.HTMLScriptElement()
          ..id = _scriptId
          ..src = src
          ..async = true
          ..type = 'application/javascript',
      );
    }

    return completer.future.then((_) {});
  }

  @override
  Future<void> updateSettings(String apiKey, {Locale? locale}) async {
    if (locale != null) {
      _language = locale.languageCode;
    }
  }

  void _doInit() {
    _elementInjected = true;
    _completer!.complete();
  }

  @override
  Future<bool?> isInitialized() async {
    return _completer?.isCompleted == true;
  }

  @override
  Future<FindAutocompletePredictionsResponse> findAutocompletePredictions(
    String query, {
    List<String>? countries,
    List<String> placeTypesFilter = const [],
    bool? newSessionToken,
    inter.LatLng? origin,
    inter.LatLngBounds? locationBias,
    inter.LatLngBounds? locationRestriction,
  }) async {
    if (locationRestriction != null) {
      // https://issuetracker.google.com/issues/36219203
      log(
        'locationRestriction is not supported: https://issuetracker.google.com/issues/36219203',
      );
    }

    // On Web, AutocompleteSessionToken must be explicitly created.
    // Create a new token if requested or if none exists.
    if (newSessionToken == true || _lastSessionToken == null) {
      _lastSessionToken = AutocompleteSessionToken();
    }

    final prom =
        AutocompleteSuggestion.fetchAutocompleteSuggestions(
              AutocompleteRequest()
                ..sessionToken = _lastSessionToken
                ..input = query
                ..origin = origin == null
                    ? null
                    : core.LatLng(origin.lat, origin.lng)
                ..includedPrimaryTypes = placeTypesFilter.isEmpty
                    ? null
                    : placeTypesFilter
                ..includedRegionCodes = countries
                ..locationBias = _boundsToWeb(locationBias)
                ..language = _language,
            )
            as JSPromise<JSObject>?;
    final result = await prom?.toDart;
    final response = result as ext.AutocompleteResponse?;
    final resp = response?.suggestions.toDart ?? [];

    final predictions = resp
        .map(_translatePrediction)
        .nonNulls
        .toList(growable: false);
    return FindAutocompletePredictionsResponse(predictions);
  }

  inter.AutocompletePrediction? _translatePrediction(
    AutocompleteSuggestion? suggestion,
  ) {
    final prediction = suggestion?.placePrediction;
    if (prediction == null) {
      return null;
    }
    final mainText = prediction.mainText?.text ?? '';
    final secondaryText = prediction.secondaryText?.text ?? '';
    return inter.AutocompletePrediction(
      distanceMeters: prediction.distanceMeters?.toInt() ?? 0,
      placeId: prediction.placeId,
      primaryText: mainText,
      secondaryText: secondaryText,
      fullText: '$mainText, $secondaryText',
    );
  }

  @override
  Future<FetchPlaceResponse> fetchPlace(
    String placeId, {
    required List<PlaceField> fields,
    bool? newSessionToken,
    String? regionCode,
  }) async {
    final respPlace = await _getDetails(placeId, fields);
    // End the session after fetching a place (billing optimization).
    // The next autocomplete call will create a new session token.
    _lastSessionToken = null;
    return FetchPlaceResponse(respPlace);
  }

  String? _mapField(PlaceField field) {
    return switch (field) {
      PlaceField.AdrFormatAddress => 'adrFormatAddress',
      PlaceField.UtcOffset => 'utcOffsetMinutes',
      PlaceField.OpeningHours => 'regularOpeningHours',
      PlaceField.CurrentOpeningHours => 'regularOpeningHours',
      // SecondaryOpeningHours just don't exist on the javascript api;
      // we're falling back to the regularOpeningHours as best-case scenario
      PlaceField.SecondaryOpeningHours => 'regularOpeningHours',
      PlaceField.WebsiteUri => 'websiteURI',
      PlaceField.CurbsidePickup => 'hasCurbsidePickup',
      PlaceField.Delivery => 'hasDelivery',
      PlaceField.DineIn => 'hasDineIn',
      PlaceField.Reservable => 'isReservable',
      PlaceField.Takeout => 'hasTakeout',
      PlaceField.IconMaskUrl => 'svgIconMaskURI',
      PlaceField.GoogleMapsUri => 'googleMapsURI',
      PlaceField.GoodForChildren => 'isGoodForChildren',
      PlaceField.GoodForGroups => 'isGoodForGroups',
      PlaceField.GoodForWatchingSports => 'isGoodForWatchingSports',
      PlaceField.Restroom => 'hasRestroom',
      PlaceField.LiveMusic => 'hasLiveMusic',
      PlaceField.OutdoorSeating => 'hasOutdoorSeating',
      PlaceField.MenuForChildren => 'hasMenuForChildren',
      PlaceField.UserRatingCount => 'userRatingCount',
      // Fields not available on the JS Places API — return null to skip
      PlaceField.ShortFormattedAddress => null,
      PlaceField.TimeZone => null,
      PlaceField.CurrentSecondaryOpeningHours => null,
      PlaceField.SubDestinations => null,
      PlaceField.ContainingPlaces => null,
      PlaceField.AddressDescriptor => null,
      PlaceField.GenerativeSummary => null,
      PlaceField.ReviewSummary => null,
      PlaceField.NeighborhoodSummary => null,
      PlaceField.EvChargeAmenitySummary => null,
      PlaceField.ConsumerAlerts => null,
      PlaceField.PureServiceAreaBusiness => null,
      _ => _upperCamelCaseToLowerCamelCase(field.name),
    };
  }

  String _upperCamelCaseToLowerCamelCase(String name) {
    final first = name[0].toLowerCase();
    final rest = name.substring(1);
    return first + rest;
  }

  Future<inter.Place?> _getDetails(
    String placeId,
    List<inter.PlaceField> fields,
  ) async {
    final fieldsMapped = fields
        .map(_mapField)
        .nonNulls
        .toSet() // Distinct
        .map((str) => str.toJS)
        .toList(growable: false)
        .toJS;

    final place = places.Place(
      PlaceOptions(id: placeId, requestedLanguage: _language),
    );
    final task =
        place.fetchFields(FetchFieldsRequest(fields: fieldsMapped))
            as JSPromise<JSObject>?;
    // /*UNPARSED:Promise<{place:Place}>*/
    final result = await task?.toDart;
    final response = result as ext.FetchFieldsResponse?;
    final resultPlace = response?.place; // PlaceResult? Place?
    return _parsePlace(resultPlace);
  }

  inter.Place? _parsePlace(places.Place? place) {
    if (place == null) {
      return null;
    }

    return inter.Place(
      // ===== Existing (required) fields =====
      id: place.id,
      address: place.formattedAddress,
      addressComponents: place.addressComponents
          ?.map(_parseAddressComponent)
          .cast<inter.AddressComponent>()
          .toList(growable: false),
      businessStatus: _parseBusinessStatus(
        place.getProperty('business_status'.toJS) as String?,
      ),
      attributions: place.attributions?.cast<String>(),
      latLng: _parseLatLang(place.location),
      name: place.displayName,
      nameLanguageCode: place.displayNameLanguageCode,
      openingHours: _parseOpeningHours(place.openingHours),
      phoneNumber: place.nationalPhoneNumber,
      photoMetadatas: place.photos
          ?.map((photo) => _parsePhotoMetadata(photo))
          .cast<PhotoMetadata>()
          .toList(growable: false),
      plusCode: _parsePlusCode(place.plusCode),
      priceLevel: _webPriceLevelToInterPriceLevel(place.priceLevel),
      rating: place.rating?.toDouble(),
      types: place.types
          ?.map(_parsePlaceType)
          .where((item) => item != null)
          .cast<PlaceType>()
          .toList(growable: false),
      userRatingsTotal: place.userRatingCount?.toInt(),
      utcOffsetMinutes: place.utcOffsetMinutes?.toInt(),
      viewport: _parseLatLngBounds(place.viewport),
      websiteUri: place.websiteURI == null
          ? null
          : Uri.parse(place.websiteURI!),
      reviews: place.reviews?.map(_parseReview).toList(growable: false),
      // ===== New Places API fields =====
      primaryType: place.primaryType,
      primaryTypeDisplayName: place.primaryTypeDisplayName != null
          ? inter.LocalizedText(
              text: place.primaryTypeDisplayName!,
              languageCode: place.primaryTypeDisplayNameLanguageCode ?? '',
            )
          : null,
      // shortFormattedAddress is not available on the JS Places API
      internationalPhoneNumber: place.internationalPhoneNumber,
      nationalPhoneNumber: place.nationalPhoneNumber,
      adrFormatAddress: place.adrFormatAddress,
      editorialSummary: place.editorialSummary != null
          ? inter.LocalizedText(
              text: place.editorialSummary!,
              languageCode: place.editorialSummaryLanguageCode ?? '',
            )
          : null,
      iconBackgroundColor: place.iconBackgroundColor,
      iconMaskBaseUri: place.svgIconMaskURI,
      googleMapsUri: place.googleMapsURI,
      // Boolean service attributes
      curbsidePickup: place.hasCurbsidePickup,
      delivery: place.hasDelivery,
      dineIn: place.hasDineIn,
      reservable: place.isReservable,
      takeout: place.hasTakeout,
      servesBeer: place.servesBeer,
      servesBreakfast: place.servesBreakfast,
      servesBrunch: place.servesBrunch,
      servesDinner: place.servesDinner,
      servesLunch: place.servesLunch,
      servesVegetarianFood: place.servesVegetarianFood,
      servesWine: place.servesWine,
      servesCocktails: place.servesCocktails,
      servesCoffee: place.servesCoffee,
      servesDessert: place.servesDessert,
      goodForChildren: place.isGoodForChildren,
      allowsDogs: place.allowsDogs,
      restroom: place.hasRestroom,
      goodForGroups: place.isGoodForGroups,
      goodForWatchingSports: place.isGoodForWatchingSports,
      liveMusic: place.hasLiveMusic,
      outdoorSeating: place.hasOutdoorSeating,
      menuForChildren: place.hasMenuForChildren,
    );
  }

  inter.Review _parseReview(places.Review review) {
    return inter.Review(
      attribution: review.text ?? '',
      authorAttribution: inter.AuthorAttribution(
        name: review.authorAttribution?.displayName ?? '',
        photoUri: review.authorAttribution?.photoURI ?? '',
        uri: review.authorAttribution?.uri ?? '',
      ),
      rating: review.rating?.toDouble() ?? 0.0,
      publishTime: _parseDateToString(review.publishTime),
      relativePublishTimeDescription:
          review.relativePublishTimeDescription ?? '',
      originalText: review.originalText,
      originalTextLanguageCode: review.originalTextLanguageCode,
      text: review.text,
      textLanguageCode: review.textLanguageCode,
    );
  }

  /// Converts a JS [Date] to an ISO 8601 string, or returns an empty string.
  String _parseDateToString(JSObject? date) {
    if (date == null) {
      return '';
    }
    final result = date.callMethod<JSString>('toISOString'.toJS);
    return result.toDart;
  }

  PlaceType? _parsePlaceType(String? placeType) {
    if (placeType == null) {
      return null;
    }

    placeType = placeType.toUpperCase();
    return PlaceType.values.cast<PlaceType?>().firstWhere(
      (element) => element!.value == placeType,
      orElse: () => null,
    );
  }

  inter.AddressComponent _parseAddressComponent(
    places.AddressComponent addressComponent,
  ) {
    return inter.AddressComponent(
      name: addressComponent.longText ?? '',
      shortName: addressComponent.shortText ?? '',
      types: addressComponent.types
          .map((e) => e.toString())
          .cast<String>()
          .toList(growable: false),
    );
  }

  inter.LatLng? _parseLatLang(core.LatLng? location) {
    if (location == null) {
      return null;
    }

    return inter.LatLng(
      lat: location.lat.toDouble(),
      lng: location.lng.toDouble(),
    );
  }

  PhotoMetadata? _parsePhotoMetadata(places.Photo? photo) {
    if (photo == null) {
      return null;
    }

    final attrs = photo.authorAttributions
        .map((attr) => attr.uri)
        .nonNulls
        .toList(growable: false);
    final photoMetadata = PhotoMetadata(
      photoReference: _getPhotoMetadataReference(),
      width: photo.widthPx.toInt(),
      height: photo.heightPx.toInt(),
      attributions: attrs.length == 1 ? attrs[0] : '',
    );

    _photosCache[photoMetadata.photoReference ?? ''] = photo;

    return photoMetadata;
  }

  String _getPhotoMetadataReference() {
    final num = _runningUid++;
    return 'id_${num.toString()}';
  }

  inter.LatLngBounds? _parseLatLngBounds(core.LatLngBounds? viewport) {
    if (viewport == null) {
      return null;
    }

    return inter.LatLngBounds(
      southwest: _parseLatLang(viewport.southWest)!,
      northeast: _parseLatLang(viewport.northEast)!,
    );
  }

  inter.PlusCode? _parsePlusCode(places.PlusCode? plusCode) {
    if (plusCode == null) {
      return null;
    }

    return inter.PlusCode(
      compoundCode: plusCode.compoundCode ?? '',
      globalCode: plusCode.globalCode ?? '',
    );
  }

  inter.BusinessStatus? _parseBusinessStatus(String? businessStatus) {
    if (businessStatus == null) {
      return null;
    }

    businessStatus = businessStatus.toUpperCase();
    return inter.BusinessStatus.values.firstWhereOrNull(
      (element) => element.name.toUpperCase() == businessStatus,
    );
  }

  inter.OpeningHours? _parseOpeningHours(places.OpeningHours? openingHours) {
    if (openingHours == null) {
      return null;
    }

    return inter.OpeningHours(
      periods: openingHours.periods
          .map(_parsePeriod)
          .cast<Period>()
          .toList(growable: false),
      weekdayText: openingHours.weekdayDescriptions.cast<String>().toList(
        growable: false,
      ),
    );
  }

  Period _parsePeriod(places.OpeningHoursPeriod period) {
    return Period(
      open: _parseTimeOfWeek(period.open)!,
      close: _parseTimeOfWeek(period.close),
    );
  }

  TimeOfWeek? _parseTimeOfWeek(places.OpeningHoursPoint? timeOfWeek) {
    if (timeOfWeek == null) {
      return null;
    }

    final day = timeOfWeek.day.toInt();

    return TimeOfWeek(
      day: _parseDayOfWeek(day),
      time: PlaceLocalTime(
        hours: timeOfWeek.hour.toInt(),
        minutes: timeOfWeek.minute.toInt(),
      ),
    );
  }

  DayOfWeek _parseDayOfWeek(int day) {
    return DayOfWeek.values[day];
  }

  core.LatLngBounds? _boundsToWeb(inter.LatLngBounds? bounds) {
    if (bounds == null) {
      return null;
    }
    return core.LatLngBounds(
      _latLngToWeb(bounds.southwest),
      _latLngToWeb(bounds.northeast),
    );
  }

  core.LatLng _latLngToWeb(inter.LatLng latLng) {
    return core.LatLng(latLng.lat, latLng.lng);
  }

  @override
  Future<FetchPlacePhotoResponse> fetchPlacePhoto(
    PhotoMetadata photoMetadata, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    final places.Photo? value = _photosCache[photoMetadata.photoReference];
    if (value == null) {
      throw PlatformException(
        code: 'API_ERROR_PHOTO',
        message: 'PhotoMetadata must be initially fetched with fetchPlace',
        details: '',
      );
    }

    final url = value.uRI;

    return FetchPlacePhotoResponse.imageUrl(url);
  }

  /// Maps a list of [PlaceField]s to a [JSArray] of JS field-name strings.
  JSArray<JSString> _mapFields(List<inter.PlaceField> fields) {
    return fields
        .map(_mapField)
        .nonNulls
        .toSet() // Distinct
        .map((str) => str.toJS)
        .toList(growable: false)
        .toJS;
  }

  @override
  Future<inter.SearchByTextResponse> searchByText(
    String textQuery, {
    required List<inter.PlaceField> fields,
    String? includedType,
    int? maxResultCount,
    inter.LatLngBounds? locationBias,
    inter.LatLngBounds? locationRestriction,
    double? minRating,
    bool? openNow,
    List<inter.PriceLevel>? priceLevels,
    inter.TextSearchRankPreference? rankPreference,
    String? regionCode,
    bool? strictTypeFiltering,
  }) async {
    final request = SearchByTextRequest(
      textQuery: textQuery,
      fields: _mapFields(fields),
      includedType: includedType,
      maxResultCount: maxResultCount,
      locationBias: locationBias != null
          ? _boundsToWeb(locationBias) as JSAny
          : null,
      locationRestriction: locationRestriction != null
          ? _boundsToWebLiteral(locationRestriction)
          : null,
      minRating: minRating,
      isOpenNow: openNow,
      priceLevels: priceLevels
          ?.map(_interPriceLevelToWebPriceLevel)
          .nonNulls
          .toList(growable: false)
          .toJS,
      rankPreference: _mapTextRankPreference(rankPreference),
      region: regionCode,
      language: _language,
      useStrictTypeFiltering: strictTypeFiltering,
    );

    final prom = places.Place.searchByText(request) as JSPromise<JSObject>?;
    final result = await prom?.toDart;
    final response = result as ext.SearchPlacesResponse?;
    final resultPlaces =
        response?.places.map(_parsePlace).nonNulls.toList(growable: false) ??
        [];
    return inter.SearchByTextResponse(resultPlaces);
  }

  @override
  Future<inter.SearchNearbyResponse> searchNearby({
    required List<inter.PlaceField> fields,
    required inter.CircularBounds locationRestriction,
    List<String>? includedTypes,
    List<String>? includedPrimaryTypes,
    List<String>? excludedTypes,
    List<String>? excludedPrimaryTypes,
    inter.NearbySearchRankPreference? rankPreference,
    String? regionCode,
    int? maxResultCount,
  }) async {
    final restriction =
        core.CircleLiteral(
              center: core.LatLngLiteral(
                lat: locationRestriction.center.lat,
                lng: locationRestriction.center.lng,
              ),
              radius: locationRestriction.radius,
            )
            as JSAny;

    final request = SearchNearbyRequest(
      locationRestriction: restriction,
      fields: _mapFields(fields),
      includedTypes: includedTypes?.map((s) => s.toJS).toList().toJS,
      includedPrimaryTypes: includedPrimaryTypes
          ?.map((s) => s.toJS)
          .toList()
          .toJS,
      excludedTypes: excludedTypes?.map((s) => s.toJS).toList().toJS,
      excludedPrimaryTypes: excludedPrimaryTypes
          ?.map((s) => s.toJS)
          .toList()
          .toJS,
      rankPreference: _mapNearbyRankPreference(rankPreference),
      region: regionCode,
      language: _language,
      maxResultCount: maxResultCount,
    );

    final prom = places.Place.searchNearby(request) as JSPromise<JSObject>?;
    final result = await prom?.toDart;
    final response = result as ext.SearchPlacesResponse?;
    final resultPlaces =
        response?.places.map(_parsePlace).nonNulls.toList(growable: false) ??
        [];
    return inter.SearchNearbyResponse(resultPlaces);
  }

  core.LatLngBoundsLiteral _boundsToWebLiteral(inter.LatLngBounds bounds) {
    return core.LatLngBoundsLiteral(
      south: bounds.southwest.lat,
      west: bounds.southwest.lng,
      north: bounds.northeast.lat,
      east: bounds.northeast.lng,
    );
  }

  /// Converts a JS Places API [places.PriceLevel] to our platform interface
  /// [inter.PriceLevel].
  ///
  /// Uses if-else chains because JS interop values are not Dart constants
  /// and cannot be used in switch pattern matching.
  inter.PriceLevel? _webPriceLevelToInterPriceLevel(places.PriceLevel? level) {
    if (level == null) return null;
    if (places.PriceLevel.FREE == level) {
      return inter.PriceLevel.priceLevelFree;
    }
    if (places.PriceLevel.INEXPENSIVE == level) {
      return inter.PriceLevel.priceLevelInexpensive;
    }
    if (places.PriceLevel.MODERATE == level) {
      return inter.PriceLevel.priceLevelModerate;
    }
    if (places.PriceLevel.EXPENSIVE == level) {
      return inter.PriceLevel.priceLevelExpensive;
    }
    if (places.PriceLevel.VERY_EXPENSIVE == level) {
      return inter.PriceLevel.priceLevelVeryExpensive;
    }
    return null;
  }

  /// Converts our platform interface [inter.PriceLevel] to a JS Places API
  /// [places.PriceLevel].
  places.PriceLevel? _interPriceLevelToWebPriceLevel(inter.PriceLevel level) {
    return switch (level) {
      inter.PriceLevel.priceLevelFree => places.PriceLevel.FREE,
      inter.PriceLevel.priceLevelInexpensive => places.PriceLevel.INEXPENSIVE,
      inter.PriceLevel.priceLevelModerate => places.PriceLevel.MODERATE,
      inter.PriceLevel.priceLevelExpensive => places.PriceLevel.EXPENSIVE,
      inter.PriceLevel.priceLevelVeryExpensive =>
        places.PriceLevel.VERY_EXPENSIVE,
      inter.PriceLevel.priceLevelUnspecified => null,
    };
  }

  SearchByTextRankPreference? _mapTextRankPreference(
    inter.TextSearchRankPreference? pref,
  ) {
    if (pref == null) return null;
    return switch (pref) {
      inter.TextSearchRankPreference.Distance =>
        SearchByTextRankPreference.DISTANCE,
      inter.TextSearchRankPreference.Relevance =>
        SearchByTextRankPreference.RELEVANCE,
    };
  }

  SearchNearbyRankPreference? _mapNearbyRankPreference(
    inter.NearbySearchRankPreference? pref,
  ) {
    if (pref == null) return null;
    return switch (pref) {
      inter.NearbySearchRankPreference.Distance =>
        SearchNearbyRankPreference.DISTANCE,
      inter.NearbySearchRankPreference.Popularity =>
        SearchNearbyRankPreference.POPULARITY,
    };
  }
}
