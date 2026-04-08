import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_plus/google_places_sdk_plus.dart';
import 'package:google_places_sdk_plus_platform_interface/method_channel_google_places_sdk_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    FlutterGooglePlacesSdkMethodChannel.channelName,
  );

  final List<MethodCall> log = <MethodCall>[];
  late FlutterGooglePlacesSdk flutterGooglePlacesSdk;

  const kPrediction1 = AutocompletePrediction(
    placeId: 'mwzmsk-iamsdcim',
    distanceMeters: 5123,
    primaryText: 'ptext3',
    secondaryText: 'stext5',
    fullText: 'ftext6',
  );
  const kPrediction2 = AutocompletePrediction(
    placeId: 'dcc',
    distanceMeters: 0,
    primaryText: 'ptext1',
    secondaryText: 'stext515',
    fullText: 'ftext6cad',
  );

  // Realistic coordinates (Tel Aviv)
  const kPlace = Place(
    id: 'ChIJ9UxXEYdLHRUR0jYgVTqNP4o',
    latLng: LatLng(lat: 32.0853, lng: 34.7818),
    address: '14 Rothschild Blvd, Tel Aviv, Israel',
    addressComponents: [],
    businessStatus: BusinessStatus.Operational,
    attributions: [],
    name: 'Test Place',
    openingHours: null,
    phoneNumber: '+972-3-123-4567',
    photoMetadatas: [],
    plusCode: null,
    priceLevel: null,
    rating: 4.5,
    types: [],
    userRatingsTotal: 120,
    utcOffsetMinutes: 120,
    viewport: null,
    websiteUri: null,
    nameLanguageCode: 'en',
    reviews: [],
  );

  final kDefaultResponses = <dynamic, dynamic>{
    'findAutocompletePredictions': <dynamic>[
      kPrediction1.toJson(),
      kPrediction2.toJson(),
    ],
    'fetchPlace': kPlace.toJson(),
  };

  const String kDefaultApiKey = 'test-api-key-23';
  const Locale kDefaultLocale = Locale('he');

  late Map<String, dynamic> responses;

  Matcher _getInitializeMatcher() {
    return isMethodCall(
      'initialize',
      arguments: {
        'apiKey': kDefaultApiKey,
        'locale': <String, dynamic>{
          'country': kDefaultLocale.countryCode,
          'language': kDefaultLocale.languageCode,
        },
      },
    );
  }

  group('FlutterGooglePlacesSdk', () {
    setUp(() {
      responses = Map<String, dynamic>.from(kDefaultResponses);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) {
            log.add(methodCall);
            final dynamic response = responses[methodCall.method];
            if (response != null && response is Exception) {
              return Future<dynamic>.error('$response');
            }
            return Future<dynamic>.value(response);
          });
      flutterGooglePlacesSdk = FlutterGooglePlacesSdk(
        kDefaultApiKey,
        locale: kDefaultLocale,
      );
      log.clear();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      log.clear();
    });

    group('isInitialized', () {
      test('returns true', () async {
        responses['isInitialized'] = true;
        final bool? result = await flutterGooglePlacesSdk.isInitialized();

        expect(log, <Matcher>[
          _getInitializeMatcher(),
          isMethodCall('isInitialized', arguments: null),
        ]);
        expect(result, isTrue);
      });

      test('returns false', () async {
        responses['isInitialized'] = false;
        final bool? result = await flutterGooglePlacesSdk.isInitialized();

        expect(log, <Matcher>[
          _getInitializeMatcher(),
          isMethodCall('isInitialized', arguments: null),
        ]);
        expect(result, isFalse);
      });
    });

    group('findAutocompletePredictions', () {
      test('default behavior', () async {
        const queryTest = 'my-query-text';
        const countriesTest = ['c5', 'c32'];
        const placeTypeFilterTest = ['establishment'];
        const origin = LatLng(lat: 32.51, lng: 95.31);
        final result = await flutterGooglePlacesSdk.findAutocompletePredictions(
          queryTest,
          countries: countriesTest,
          placeTypesFilter: placeTypeFilterTest,
          newSessionToken: false,
          origin: origin,
        );

        expect(log, <Matcher>[
          _getInitializeMatcher(),
          isMethodCall(
            'findAutocompletePredictions',
            arguments: <String, dynamic>{
              'query': queryTest,
              'countries': countriesTest,
              'typesFilter': ['establishment'],
              'newSessionToken': false,
              'origin': origin.toJson(),
              'locationBias': null,
              'locationRestriction': null,
            },
          ),
        ]);

        const expected = FindAutocompletePredictionsResponse([
          kPrediction1,
          kPrediction2,
        ]);
        expect(result, equals(expected));
      });

      test('with locationBias', () async {
        const locationBias = LatLngBounds(
          southwest: LatLng(lat: 32.0, lng: 34.0),
          northeast: LatLng(lat: 33.0, lng: 35.0),
        );
        await flutterGooglePlacesSdk.findAutocompletePredictions(
          'test',
          locationBias: locationBias,
        );

        expect(log, hasLength(2));
        final call = log[1];
        expect(call.method, 'findAutocompletePredictions');
        expect(call.arguments['locationBias'], locationBias.toJson());
      });
    });

    group('fetchPlace', () {
      test('default behavior', () async {
        const placeId = 'my-place-id';
        const fields = [PlaceField.Location, PlaceField.PriceLevel];
        final result = await flutterGooglePlacesSdk.fetchPlace(
          placeId,
          fields: fields,
        );

        expect(log, <Matcher>[
          _getInitializeMatcher(),
          isMethodCall(
            'fetchPlace',
            arguments: <String, dynamic>{
              'placeId': placeId,
              'fields': fields.map((e) => e.name).toList(growable: false),
              'newSessionToken': null,
              'regionCode': null,
            },
          ),
        ]);

        const expected = FetchPlaceResponse(kPlace);
        expect(result, equals(expected));
      });

      test('with regionCode', () async {
        const placeId = 'my-place-id';
        const fields = [PlaceField.Location];
        final result = await flutterGooglePlacesSdk.fetchPlace(
          placeId,
          fields: fields,
          regionCode: 'CO',
        );

        expect(log, hasLength(2));
        final call = log[1];
        expect(call.method, 'fetchPlace');
        expect(call.arguments['regionCode'], 'CO');

        const expected = FetchPlaceResponse(kPlace);
        expect(result, equals(expected));
      });
    });

    group('deinitialize', () {
      test('calls platform deinitialize', () async {
        responses['deinitialize'] = null;
        await flutterGooglePlacesSdk.deinitialize();

        expect(log, <Matcher>[
          _getInitializeMatcher(),
          isMethodCall('deinitialize', arguments: null),
        ]);
      });

      test('allows re-initialization after deinitialize', () async {
        responses['deinitialize'] = null;
        responses['isInitialized'] = true;

        await flutterGooglePlacesSdk.deinitialize();
        await flutterGooglePlacesSdk.isInitialized();

        final methodNames = log.map((c) => c.method).toList();
        expect(methodNames, [
          'initialize',
          'deinitialize',
          'initialize',
          'isInitialized',
        ]);
      });
    });

    group('fetchPlacePhoto', () {
      test('returns image from Uint8List response', () async {
        const photoMetadata = PhotoMetadata(
          photoReference: 'places/abc/photos/xyz',
          width: 1920,
          height: 1080,
          attributions: 'Test Author',
        );
        // Simulate a minimal valid PNG as Uint8List response
        responses['fetchPlacePhoto'] = Uint8List.fromList([
          137, 80, 78, 71, 13, 10, 26, 10, // PNG header
        ]);
        final result = await flutterGooglePlacesSdk.fetchPlacePhoto(
          photoMetadata,
          maxWidth: 800,
          maxHeight: 600,
        );

        expect(log, hasLength(2));
        final call = log[1];
        expect(call.method, 'fetchPlacePhoto');
        expect(call.arguments['photoReference'], 'places/abc/photos/xyz');
        expect(call.arguments['maxWidth'], 800);
        expect(call.arguments['maxHeight'], 600);

        // Response should be the image variant
        expect(result, isA<FetchPlacePhotoResponseImage>());
      });

      test('returns imageUrl from String response', () async {
        const photoMetadata = PhotoMetadata(
          photoReference: 'places/abc/photos/xyz',
          width: 1920,
          height: 1080,
          attributions: 'Test Author',
        );
        responses['fetchPlacePhoto'] = 'https://example.com/photo.jpg';
        final result = await flutterGooglePlacesSdk.fetchPlacePhoto(
          photoMetadata,
        );

        expect(result, isA<FetchPlacePhotoResponseImageUrl>());
      });
    });

    group('searchByText', () {
      test('sends correct request and parses response', () async {
        const textQuery = 'restaurants in Tel Aviv';
        const fields = [PlaceField.Id, PlaceField.DisplayName];
        responses['searchByText'] = <dynamic>[kPlace.toJson()];

        final result = await flutterGooglePlacesSdk.searchByText(
          textQuery,
          fields: fields,
        );

        expect(log, hasLength(2));
        final call = log[1];
        expect(call.method, 'searchByText');
        expect(call.arguments['textQuery'], textQuery);
        expect(call.arguments['fields'], fields.map((e) => e.name).toList());
        expect(call.arguments['includedType'], isNull);
        expect(call.arguments['maxResultCount'], isNull);

        expect(result.places, hasLength(1));
        expect(result.places[0].id, kPlace.id);
      });

      test('sends all optional parameters', () async {
        const textQuery = 'cafe';
        const fields = [PlaceField.Id];
        const locationBias = LatLngBounds(
          southwest: LatLng(lat: 32.0, lng: 34.0),
          northeast: LatLng(lat: 33.0, lng: 35.0),
        );
        responses['searchByText'] = <dynamic>[];

        await flutterGooglePlacesSdk.searchByText(
          textQuery,
          fields: fields,
          includedType: 'cafe',
          maxResultCount: 5,
          locationBias: locationBias,
          minRating: 4.0,
          openNow: true,
          priceLevels: [PriceLevel.priceLevelModerate],
          rankPreference: TextSearchRankPreference.Distance,
          regionCode: 'IL',
          strictTypeFiltering: true,
        );

        final call = log[1];
        expect(call.arguments['includedType'], 'cafe');
        expect(call.arguments['maxResultCount'], 5);
        expect(call.arguments['locationBias'], locationBias.toJson());
        expect(call.arguments['minRating'], 4.0);
        expect(call.arguments['openNow'], true);
        expect(call.arguments['priceLevels'], [
          PriceLevel.priceLevelModerate.name,
        ]);
        expect(call.arguments['rankPreference'], 'DISTANCE');
        expect(call.arguments['regionCode'], 'IL');
        expect(call.arguments['strictTypeFiltering'], true);
      });

      test('returns empty list when no results', () async {
        responses['searchByText'] = <dynamic>[];
        final result = await flutterGooglePlacesSdk.searchByText(
          'nonexistent place xyz',
          fields: [PlaceField.Id],
        );

        expect(result.places, isEmpty);
      });
    });

    group('searchNearby', () {
      test('sends correct request and parses response', () async {
        const fields = [PlaceField.Id, PlaceField.Location];
        const locationRestriction = CircularBounds(
          center: LatLng(lat: 32.0853, lng: 34.7818),
          radius: 1000.0,
        );
        responses['searchNearby'] = <dynamic>[kPlace.toJson()];

        final result = await flutterGooglePlacesSdk.searchNearby(
          fields: fields,
          locationRestriction: locationRestriction,
          includedTypes: ['restaurant'],
          maxResultCount: 10,
        );

        expect(log, hasLength(2));
        final call = log[1];
        expect(call.method, 'searchNearby');
        expect(call.arguments['fields'], fields.map((e) => e.name).toList());
        expect(
          call.arguments['locationRestriction'],
          locationRestriction.toJson(),
        );
        expect(call.arguments['includedTypes'], ['restaurant']);
        expect(call.arguments['maxResultCount'], 10);

        expect(result.places, hasLength(1));
        expect(result.places[0].id, kPlace.id);
      });

      test('sends all optional parameters', () async {
        const locationRestriction = CircularBounds(
          center: LatLng(lat: 32.0853, lng: 34.7818),
          radius: 500.0,
        );
        responses['searchNearby'] = <dynamic>[];

        await flutterGooglePlacesSdk.searchNearby(
          fields: [PlaceField.Id],
          locationRestriction: locationRestriction,
          includedTypes: ['restaurant'],
          includedPrimaryTypes: ['restaurant'],
          excludedTypes: ['bar'],
          excludedPrimaryTypes: ['bar'],
          rankPreference: NearbySearchRankPreference.Distance,
          regionCode: 'IL',
          maxResultCount: 5,
        );

        final call = log[1];
        expect(call.arguments['includedTypes'], ['restaurant']);
        expect(call.arguments['includedPrimaryTypes'], ['restaurant']);
        expect(call.arguments['excludedTypes'], ['bar']);
        expect(call.arguments['excludedPrimaryTypes'], ['bar']);
        expect(call.arguments['rankPreference'], 'DISTANCE');
        expect(call.arguments['regionCode'], 'IL');
        expect(call.arguments['maxResultCount'], 5);
      });
    });

    group('updateSettings', () {
      test('updates apiKey and locale', () async {
        const newApiKey = 'new-api-key';
        const newLocale = Locale('en', 'US');

        responses['updateSettings'] = null;
        await flutterGooglePlacesSdk.updateSettings(
          apiKey: newApiKey,
          locale: newLocale,
        );

        expect(log, hasLength(2));
        final call = log[1];
        expect(call.method, 'updateSettings');
        expect(call.arguments['apiKey'], newApiKey);
        expect(call.arguments['locale'], {
          'country': newLocale.countryCode,
          'language': newLocale.languageCode,
        });

        // Verify internal state was updated
        expect(flutterGooglePlacesSdk.apiKey, newApiKey);
        expect(flutterGooglePlacesSdk.locale, newLocale);
      });

      test('keeps current apiKey when null is passed', () async {
        responses['updateSettings'] = null;
        await flutterGooglePlacesSdk.updateSettings(locale: const Locale('fr'));

        final call = log[1];
        expect(call.arguments['apiKey'], kDefaultApiKey);
        expect(flutterGooglePlacesSdk.apiKey, kDefaultApiKey);
      });
    });

    group('error handling', () {
      test('method call error is catchable', () async {
        responses['isInitialized'] = Exception('test error');

        expect(
          () => flutterGooglePlacesSdk.isInitialized(),
          throwsA(isA<PlatformException>()),
        );
      });

      test('error in one call does not block subsequent calls', () async {
        responses['isInitialized'] = Exception('first call error');

        try {
          await flutterGooglePlacesSdk.isInitialized();
        } catch (_) {
          // Expected
        }

        // Second call should succeed
        responses['isInitialized'] = true;
        final result = await flutterGooglePlacesSdk.isInitialized();
        expect(result, isTrue);
      });

      test('error does not produce unhandled async exception', () async {
        // If the bug existed, an unhandled exception from _waitFor's throw
        // would cause this test to fail even though we caught the error.
        responses['isInitialized'] = Exception('should not be unhandled');

        try {
          await flutterGooglePlacesSdk.isInitialized();
        } catch (_) {
          // Expected - this is the single, proper propagation
        }

        // Give the event loop a chance to surface any unhandled errors
        await Future<void>.delayed(Duration.zero);
      });
    });

    group('sequential call ordering', () {
      test('multiple calls are executed in order', () async {
        responses['isInitialized'] = true;
        responses['fetchPlace'] = kPlace.toJson();

        final future1 = flutterGooglePlacesSdk.isInitialized();
        final future2 = flutterGooglePlacesSdk.fetchPlace(
          'place-id',
          fields: [PlaceField.Id],
        );

        await Future.wait([future1, future2]);

        // Both should have completed with initialize only called once
        // and methods in order
        final methodNames = log.map((c) => c.method).toList();
        expect(methodNames[0], 'initialize');
        expect(methodNames[1], 'isInitialized');
        expect(methodNames[2], 'fetchPlace');
      });
    });
  });
}
