import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_places_sdk_plus/google_places_sdk_plus.dart';
import 'package:google_places_sdk_plus_example/constants.dart';
import 'package:google_places_sdk_plus_example/google_places_img.dart'
    if (dart.library.html) 'package:google_places_sdk_plus_example/google_places_img_web.dart'
    as gpi;
import 'package:google_places_sdk_plus_example/settings_page.dart';

/// Title
const title = 'Flutter Google Places SDK Example';

void main() {
  runApp(MyApp());
}

/// Main app
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(primaryColor: Colors.blueAccent),
      home: const MyHomePage(),
    );
  }
}

/// Main home page
class MyHomePage extends StatefulWidget {
  /// Construct the HomePage
  const MyHomePage({super.key, this.initOnStart = true});

  /// When true, the relevant classes (e.g. [FlutterGooglePlacesSdk]) will be
  /// initialized as part of the lifecycle (e.g. initState).
  /// When false, user will need to click the "Init" button to initialize it.
  final bool initOnStart;

  @override
  State<StatefulWidget> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterGooglePlacesSdk? _placesVar;

  FlutterGooglePlacesSdk get _places => _placesVar!;

  //
  String? _predictLastText;

  List<String> _placeTypesFilter = ['establishment'];

  bool _locationBiasEnabled = true;
  LatLngBounds _locationBias = const LatLngBounds(
    southwest: LatLng(lat: 32.0810305, lng: 34.785707),
    northeast: LatLng(lat: 32.0935937, lng: 34.8013896),
  );

  bool _locationRestrictionEnabled = false;
  LatLngBounds _locationRestriction = const LatLngBounds(
    southwest: LatLng(lat: 32.0583974, lng: 34.7633473),
    northeast: LatLng(lat: 32.0876885, lng: 34.8040563),
  );

  List<String> _countries = ['il'];
  bool _countriesEnabled = true;

  bool _predicting = false;
  dynamic _predictErr;

  List<AutocompletePrediction>? _predictions;

  //
  final TextEditingController _fetchPlaceIdController = TextEditingController();
  final List<PlaceField> _placeFields = PlaceField.values;

  // List<PlaceField> _placeFields = [
  //   PlaceField.Address,
  //   PlaceField.AddressComponents,
  //   PlaceField.BusinessStatus,
  //   PlaceField.Id,
  //   PlaceField.Location,
  //   PlaceField.DisplayName,
  //   PlaceField.OpeningHours,
  //   PlaceField.NationalPhoneNumber,
  //   PlaceField.InternationalPhoneNumber,
  //   PlaceField.Photos,
  //   PlaceField.PlusCode,
  //   PlaceField.PriceLevel,
  //   PlaceField.Rating,
  //   PlaceField.Types,
  //   PlaceField.UserRatingCount,
  //   PlaceField.UtcOffset,
  //   PlaceField.Viewport,
  //   PlaceField.WebsiteUri,
  // ];

  bool _fetchingPlace = false;
  dynamic _fetchingPlaceErr;

  bool _fetchingPlacePhoto = false;
  dynamic _fetchingPlacePhotoErr;

  Place? _place;
  FetchPlacePhotoResponse? _placePhoto;
  PhotoMetadata? _placePhotoMetadata;

  // -- Search by Text
  String? _searchByTextLastQuery;
  bool _searchingByText = false;
  dynamic _searchByTextErr;
  List<Place>? _searchByTextResults;
  String? _searchByTextIncludedType;
  int? _searchByTextMaxResults;
  double? _searchByTextMinRating;
  bool _searchByTextOpenNow = false;
  bool _searchByTextStrictTypeFiltering = false;
  TextSearchRankPreference? _searchByTextRankPreference;

  bool _searchByTextLocationBiasEnabled = false;
  LatLngBounds _searchByTextLocationBias = const LatLngBounds(
    southwest: LatLng(lat: 32.0810305, lng: 34.785707),
    northeast: LatLng(lat: 32.0935937, lng: 34.8013896),
  );

  // -- Search Nearby
  bool _searchingNearby = false;
  dynamic _searchNearbyErr;
  List<Place>? _searchNearbyResults;
  String? _searchNearbyIncludedTypes;
  int? _searchNearbyMaxResults;
  NearbySearchRankPreference? _searchNearbyRankPreference;

  LatLng _searchNearbyCenter = const LatLng(lat: 32.0853, lng: 34.7818);
  double _searchNearbyRadius = 500.0;

  @override
  void initState() {
    super.initState();

    if (widget.initOnStart) {
      _doInit();
    }
  }

  void _doInit() {
    if (_placesVar != null) {
      debugPrint('Warning: Places init called after already initialized!');
      return;
    }

    _placesVar = FlutterGooglePlacesSdk(
      INITIAL_API_KEY,
      locale: INITIAL_LOCALE,
    );
    _places.isInitialized().then((value) {
      debugPrint('Places Initialized: $value');

      // Update the state to reflect initialized state
      setState(() {});
    });
  }

  Future<void> _doDeinit() async {
    if (_placesVar == null) return;
    try {
      await _places.deinitialize();
      setState(() {
        _placesVar = null;
      });
      debugPrint('Places deinitialized');
    } catch (err) {
      debugPrint('Deinitialize error: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initWidgets = _buildInitWidgets();
    final predictionsWidgets = _buildPredictionWidgets();
    final fetchPlaceWidgets = _buildFetchPlaceWidgets();
    final fetchPlacePhotoWidgets = _buildFetchPlacePhotoWidgets();
    final searchByTextWidgets = _buildSearchByTextWidgets();
    final searchNearbyWidgets = _buildSearchNearbyWidgets();
    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        actions: [
          IconButton(
            onPressed: _openSettingsModal,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: ListView(
          children:
              initWidgets +
              [const SizedBox(height: 16)] +
              predictionsWidgets +
              [const SizedBox(height: 16)] +
              fetchPlaceWidgets +
              [const SizedBox(height: 16)] +
              fetchPlacePhotoWidgets +
              [const SizedBox(height: 16)] +
              searchByTextWidgets +
              [const SizedBox(height: 16)] +
              searchNearbyWidgets,
        ),
      ),
    );
  }

  void _onPlaceTypeFilterChanged(String? value) {
    if (value != null) {
      setState(() {
        _placeTypesFilter = [value];
      });
    }
  }

  String? _countriesValidator(String? input) {
    if (input == null || input.isEmpty) {
      return null; // valid
    }

    return input
        .split(',')
        .map((part) => part.trim())
        .map((part) {
          if (part.length != 2) {
            return "Country part '$part' must be 2 characters";
          }
          return null;
        })
        .where((item) => item != null)
        .firstOrNull;
  }

  void _onCountriesTextChanged(String countries) {
    _countries = (countries == '')
        ? []
        : countries
              .split(',')
              .map((item) => item.trim())
              .toList(growable: false);
  }

  void _onPredictTextChanged(String value) {
    _predictLastText = value;
  }

  Future<void> _fetchPlace() async {
    if (_fetchingPlace) {
      return;
    }

    final text = _fetchPlaceIdController.text;
    final hasContent = text.isNotEmpty;

    setState(() {
      _fetchingPlace = hasContent;
      _fetchingPlaceErr = null;
    });

    if (!hasContent) {
      return;
    }

    try {
      final result = await _places.fetchPlace(
        _fetchPlaceIdController.text,
        fields: _placeFields,
      );

      setState(() {
        _place = result.place;
        _fetchingPlace = false;
      });
    } catch (err) {
      setState(() {
        _fetchingPlaceErr = err;
        _fetchingPlace = false;
      });
    }
  }

  Future<void> _predict() async {
    if (_predicting) {
      return;
    }

    final hasContent = _predictLastText?.isNotEmpty ?? false;

    setState(() {
      _predicting = hasContent;
      _predictErr = null;
    });

    if (!hasContent) {
      return;
    }

    try {
      final result = await _places.findAutocompletePredictions(
        _predictLastText!,
        countries: _countriesEnabled ? _countries : null,
        placeTypesFilter: _placeTypesFilter,
        newSessionToken: false,
        origin: const LatLng(lat: 43.12, lng: 95.20),
        locationBias: _locationBiasEnabled ? _locationBias : null,
        locationRestriction: _locationRestrictionEnabled
            ? _locationRestriction
            : null,
      );

      setState(() {
        _predictions = result.predictions;
        _predicting = false;
      });
    } catch (err) {
      setState(() {
        _predictErr = err;
        _predicting = false;
      });
    }
  }

  void _onItemClicked(AutocompletePrediction item) {
    _fetchPlaceIdController.text = item.placeId ?? '';
  }

  Widget _buildPredictionItem(AutocompletePrediction item) {
    return InkWell(
      onTap: () => _onItemClicked(item),
      child: Column(
        children: [
          Text(item.fullText ?? ''),
          Text('${item.primaryText ?? ''} - ${item.secondaryText ?? ''}'),
          const Divider(thickness: 2),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(dynamic err) {
    final theme = Theme.of(context);
    final errorText = err == null ? '' : err.toString();
    return Text(
      errorText,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }

  List<Widget> _buildFetchPlacePhotoWidgets() {
    return [
      // --
      // TextFormField(controller: _fetchPlaceIdController),
      ElevatedButton(
        onPressed: (_fetchingPlacePhoto == true || _place == null)
            ? null
            : _fetchPlacePhoto,
        child: const Text('Fetch Place Photo'),
      ),

      // -- Error widget + Result
      _buildErrorWidget(_fetchingPlacePhotoErr),
      _buildPhotoWidget(_placePhoto),
    ];
  }

  Future<void> _fetchPlacePhoto() async {
    final place = _place;
    if (_fetchingPlacePhoto || place == null) {
      return;
    }

    if ((place.photoMetadatas?.length ?? 0) == 0) {
      setState(() {
        _fetchingPlacePhoto = false;
        _fetchingPlacePhotoErr = 'No photos for place';
      });
      return;
    }

    setState(() {
      _fetchingPlacePhoto = true;
      _fetchingPlacePhotoErr = null;
    });

    try {
      final metadata = place.photoMetadatas![0];

      final result = await _places.fetchPlacePhoto(metadata);

      setState(() {
        _placePhoto = result;
        _placePhotoMetadata = metadata;
        _fetchingPlacePhoto = false;
      });
    } catch (err) {
      setState(() {
        _fetchingPlacePhotoErr = err;
        _fetchingPlacePhoto = false;
      });
    }
  }

  List<Widget> _buildFetchPlaceWidgets() {
    return [
      // --
      TextFormField(controller: _fetchPlaceIdController),
      ElevatedButton(
        onPressed: _fetchingPlace == true ? null : _fetchPlace,
        child: const Text('Fetch Place'),
      ),

      // -- Error widget + Result
      _buildErrorWidget(_fetchingPlaceErr),
      WebSelectableText('Result: ' + (_place?.toString() ?? 'N/A')),
    ];
  }

  Widget _buildEnabledOption(
    bool value,
    void Function(bool) callback,
    Widget child,
  ) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: (value) {
            setState(() {
              callback(value ?? false);
            });
          },
        ),
        Flexible(child: child),
      ],
    );
  }

  List<Widget> _buildInitWidgets() {
    final isInit = _placesVar != null;
    return [
      Row(
        children: [
          if (isInit)
            const Icon(Icons.check, color: Colors.green)
          else
            const Icon(Icons.close, color: Colors.red),
          Text('Initialized: ' + (isInit ? 'true' : 'false')),
        ],
      ),
      Row(
        children: [
          ElevatedButton(
            onPressed: isInit ? null : _doInit,
            child: const Text('Initialize!'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isInit ? _doDeinit : null,
            child: const Text('Deinitialize'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildPredictionWidgets() {
    return [
      // --
      TextFormField(
        onChanged: _onPredictTextChanged,
        decoration: const InputDecoration(label: Text('Query')),
      ),
      // -- Countries
      _buildEnabledOption(
        _countriesEnabled,
        (value) => _countriesEnabled = value,
        TextFormField(
          enabled: _countriesEnabled,
          onChanged: _onCountriesTextChanged,
          decoration: const InputDecoration(label: Text('Countries')),
          validator: _countriesValidator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          initialValue: _countries.join(','),
        ),
      ),
      // -- Place Types
      DropdownButton<String>(
        items: const ['address', 'establishment', 'geocode']
            .map(
              (item) =>
                  DropdownMenuItem<String>(child: Text(item), value: item),
            )
            .toList(growable: false),
        value: _placeTypesFilter.isEmpty ? null : _placeTypesFilter[0],
        onChanged: _onPlaceTypeFilterChanged,
      ),
      // -- Location Bias
      _buildEnabledOption(
        _locationBiasEnabled,
        (value) => _locationBiasEnabled = value,
        LocationField(
          label: 'Location Bias',
          enabled: _locationBiasEnabled,
          value: _locationBias,
          onChanged: (bounds) {
            setState(() {
              _locationBias = bounds;
            });
          },
        ),
      ),
      // -- Location Restrictions
      _buildEnabledOption(
        _locationRestrictionEnabled,
        (value) => _locationRestrictionEnabled = value,
        LocationField(
          label: 'Location Restriction',
          enabled: _locationRestrictionEnabled,
          value: _locationRestriction,
          onChanged: (bounds) {
            setState(() {
              _locationRestriction = bounds;
            });
          },
        ),
      ),
      // -- Predict
      ElevatedButton(
        onPressed: _predicting == true ? null : _predict,
        child: const Text('Predict'),
      ),

      // -- Error widget + Result
      _buildErrorWidget(_predictErr),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: (_predictions ?? [])
            .map(_buildPredictionItem)
            .toList(growable: false),
      ),
      const Image(image: FlutterGooglePlacesSdk.assetPoweredByGoogleOnWhite),
    ];
  }

  // ===== Search by Text =====

  Future<void> _searchByText() async {
    if (_searchingByText) return;

    final hasContent = _searchByTextLastQuery?.isNotEmpty ?? false;
    setState(() {
      _searchingByText = hasContent;
      _searchByTextErr = null;
    });

    if (!hasContent) return;

    try {
      final result = await _places.searchByText(
        _searchByTextLastQuery!,
        fields: PlaceField.values,
        includedType: _searchByTextIncludedType,
        maxResultCount: _searchByTextMaxResults,
        minRating: _searchByTextMinRating,
        openNow: _searchByTextOpenNow ? true : null,
        strictTypeFiltering: _searchByTextStrictTypeFiltering ? true : null,
        rankPreference: _searchByTextRankPreference,
        locationBias: _searchByTextLocationBiasEnabled
            ? _searchByTextLocationBias
            : null,
      );

      setState(() {
        _searchByTextResults = result.places;
        _searchingByText = false;
      });
    } catch (err) {
      setState(() {
        _searchByTextErr = err;
        _searchingByText = false;
      });
    }
  }

  List<Widget> _buildSearchByTextWidgets() {
    return [
      Text('Search by Text', style: Theme.of(context).textTheme.titleMedium),
      // -- Text query
      TextFormField(
        onChanged: (value) => _searchByTextLastQuery = value,
        decoration: const InputDecoration(label: Text('Text Query')),
      ),
      // -- Included Type
      TextFormField(
        onChanged: (value) =>
            _searchByTextIncludedType = value.isEmpty ? null : value,
        decoration: const InputDecoration(
          label: Text('Included Type'),
          hintText: 'e.g. restaurant',
        ),
      ),
      // -- Max Result Count
      TextFormField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) => _searchByTextMaxResults = value.isEmpty
            ? null
            : int.tryParse(value),
        decoration: const InputDecoration(label: Text('Max Results')),
      ),
      // -- Min Rating
      TextFormField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        onChanged: (value) => _searchByTextMinRating = value.isEmpty
            ? null
            : double.tryParse(value),
        decoration: const InputDecoration(label: Text('Min Rating (0-5)')),
      ),
      // -- Open Now
      Row(
        children: [
          Checkbox(
            value: _searchByTextOpenNow,
            onChanged: (value) {
              setState(() => _searchByTextOpenNow = value ?? false);
            },
          ),
          const Text('Open Now'),
        ],
      ),
      // -- Strict Type Filtering
      Row(
        children: [
          Checkbox(
            value: _searchByTextStrictTypeFiltering,
            onChanged: (value) {
              setState(() => _searchByTextStrictTypeFiltering = value ?? false);
            },
          ),
          const Text('Strict Type Filtering'),
        ],
      ),
      // -- Rank Preference
      DropdownButton<TextSearchRankPreference?>(
        hint: const Text('Rank Preference'),
        items: [
          const DropdownMenuItem(value: null, child: Text('None')),
          ...TextSearchRankPreference.values.map(
            (item) => DropdownMenuItem(value: item, child: Text(item.name)),
          ),
        ],
        value: _searchByTextRankPreference,
        onChanged: (value) {
          setState(() => _searchByTextRankPreference = value);
        },
      ),
      // -- Location Bias
      _buildEnabledOption(
        _searchByTextLocationBiasEnabled,
        (value) => _searchByTextLocationBiasEnabled = value,
        LocationField(
          label: 'Location Bias',
          enabled: _searchByTextLocationBiasEnabled,
          value: _searchByTextLocationBias,
          onChanged: (bounds) {
            setState(() => _searchByTextLocationBias = bounds);
          },
        ),
      ),
      // -- Search button
      ElevatedButton(
        onPressed: _searchingByText ? null : _searchByText,
        child: const Text('Search by Text'),
      ),
      // -- Error + Results
      _buildErrorWidget(_searchByTextErr),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: (_searchByTextResults ?? [])
            .map(
              (place) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.displayName?.text ?? place.name ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(place.address ?? ''),
                    if (place.rating != null) Text('Rating: ${place.rating}'),
                    const Divider(thickness: 2),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    ];
  }

  // ===== Search Nearby =====

  Future<void> _searchNearby() async {
    if (_searchingNearby) return;

    setState(() {
      _searchingNearby = true;
      _searchNearbyErr = null;
    });

    try {
      final result = await _places.searchNearby(
        fields: PlaceField.values,
        locationRestriction: CircularBounds(
          center: _searchNearbyCenter,
          radius: _searchNearbyRadius,
        ),
        includedTypes: _searchNearbyIncludedTypes?.isNotEmpty == true
            ? _searchNearbyIncludedTypes!
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
            : null,
        maxResultCount: _searchNearbyMaxResults,
        rankPreference: _searchNearbyRankPreference,
      );

      setState(() {
        _searchNearbyResults = result.places;
        _searchingNearby = false;
      });
    } catch (err) {
      setState(() {
        _searchNearbyErr = err;
        _searchingNearby = false;
      });
    }
  }

  List<Widget> _buildSearchNearbyWidgets() {
    return [
      Text('Search Nearby', style: Theme.of(context).textTheme.titleMedium),
      // -- Center Lat
      Row(
        children: [
          Flexible(
            child: TextFormField(
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]')),
              ],
              initialValue: _searchNearbyCenter.lat.toString(),
              onChanged: (value) {
                final lat = double.tryParse(value);
                if (lat != null) {
                  _searchNearbyCenter = LatLng(
                    lat: lat,
                    lng: _searchNearbyCenter.lng,
                  );
                }
              },
              decoration: const InputDecoration(label: Text('Center Lat')),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: TextFormField(
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]')),
              ],
              initialValue: _searchNearbyCenter.lng.toString(),
              onChanged: (value) {
                final lng = double.tryParse(value);
                if (lng != null) {
                  _searchNearbyCenter = LatLng(
                    lat: _searchNearbyCenter.lat,
                    lng: lng,
                  );
                }
              },
              decoration: const InputDecoration(label: Text('Center Lng')),
            ),
          ),
        ],
      ),
      // -- Radius
      TextFormField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        initialValue: _searchNearbyRadius.toString(),
        onChanged: (value) {
          final radius = double.tryParse(value);
          if (radius != null) _searchNearbyRadius = radius;
        },
        decoration: const InputDecoration(label: Text('Radius (meters)')),
      ),
      // -- Included Types
      TextFormField(
        onChanged: (value) =>
            _searchNearbyIncludedTypes = value.isEmpty ? null : value,
        decoration: const InputDecoration(
          label: Text('Included Types'),
          hintText: 'e.g. restaurant,cafe',
        ),
      ),
      // -- Max Result Count
      TextFormField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) => _searchNearbyMaxResults = value.isEmpty
            ? null
            : int.tryParse(value),
        decoration: const InputDecoration(label: Text('Max Results')),
      ),
      // -- Rank Preference
      DropdownButton<NearbySearchRankPreference?>(
        hint: const Text('Rank Preference'),
        items: [
          const DropdownMenuItem(value: null, child: Text('None')),
          ...NearbySearchRankPreference.values.map(
            (item) => DropdownMenuItem(value: item, child: Text(item.name)),
          ),
        ],
        value: _searchNearbyRankPreference,
        onChanged: (value) {
          setState(() => _searchNearbyRankPreference = value);
        },
      ),
      // -- Search button
      ElevatedButton(
        onPressed: _searchingNearby ? null : _searchNearby,
        child: const Text('Search Nearby'),
      ),
      // -- Error + Results
      _buildErrorWidget(_searchNearbyErr),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: (_searchNearbyResults ?? [])
            .map(
              (place) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.displayName?.text ?? place.name ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(place.address ?? ''),
                    if (place.rating != null) Text('Rating: ${place.rating}'),
                    if (place.types != null)
                      Text(
                        'Types: ${place.types!.map((t) => t.name).join(", ")}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    const Divider(thickness: 2),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    ];
  }

  Widget _buildPhotoWidget(FetchPlacePhotoResponse? placePhoto) {
    if (placePhoto == null) {
      return Container();
    }

    return gpi.GooglePlacesImg(
      photoMetadata: _placePhotoMetadata!,
      placePhotoResponse: placePhoto,
    );
  }

  void _openSettingsModal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsPage(_places)),
    );
  }
}

/// Callback function with LatLngBounds
typedef ActionWithBounds = void Function(LatLngBounds);

/// Location widget used to display and edit a LatLngBounds type
class LocationField extends StatefulWidget {
  /// Create a LocationField
  const LocationField({
    Key? key,
    required this.label,
    required this.enabled,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  /// Label associated with this field
  final String label;

  /// If true the field is enabled. If false it is disabled and user can not interact with it
  /// Value is retained even when the field is disabled
  final bool enabled;

  /// The current value in the field
  final LatLngBounds value;

  /// Callback for when the value has changed by the user.
  final ActionWithBounds onChanged;

  @override
  State<StatefulWidget> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  late TextEditingController _ctrlNeLat;
  late TextEditingController _ctrlNeLng;
  late TextEditingController _ctrlSwLat;
  late TextEditingController _ctrlSwLng;

  @override
  void initState() {
    super.initState();

    _ctrlNeLat = TextEditingController.fromValue(
      TextEditingValue(text: widget.value.northeast.lat.toString()),
    );
    _ctrlNeLng = TextEditingController.fromValue(
      TextEditingValue(text: widget.value.northeast.lng.toString()),
    );
    _ctrlSwLat = TextEditingController.fromValue(
      TextEditingValue(text: widget.value.southwest.lat.toString()),
    );
    _ctrlSwLng = TextEditingController.fromValue(
      TextEditingValue(text: widget.value.southwest.lng.toString()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: InputDecorator(
        decoration: InputDecoration(
          enabled: widget.enabled,
          labelText: widget.label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
        child: Row(
          children: [
            _buildField('NE/Lat', _ctrlNeLat),
            _buildField('NE/Lng', _ctrlNeLng),
            _buildField('SW/Lat', _ctrlSwLat),
            _buildField('SW/Lng', _ctrlSwLng),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Flexible(
      child: TextFormField(
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        onChanged: (value) => _onValueChanged(controller, value),
        decoration: InputDecoration(label: Text(label)),
        // validator: _boundsValidator,
        // autovalidateMode: AutovalidateMode.onUserInteraction,
        controller: controller,
      ),
    );
  }

  void _onValueChanged(TextEditingController ctrlNELat, String value) {
    final neLat = double.parse(ctrlNELat.value.text);

    final LatLngBounds bounds = LatLngBounds(
      southwest: const LatLng(lat: 0.0, lng: 0.0),
      northeast: LatLng(lat: neLat, lng: 0.0),
    );

    widget.onChanged(bounds);
  }
}

/// Creates a web-selectable text widget.
///
/// If the platform is web, the widget created is [SelectableText].
/// Otherwise, it's a [Text].
class WebSelectableText extends StatelessWidget {
  /// Creates a web-selectable text widget.
  ///
  /// If the platform is web, the widget created is [SelectableText].
  /// Otherwise, it's a [Text].
  const WebSelectableText(this.data, {Key? key}) : super(key: key);

  /// The text to display.
  ///
  /// This will be null if a [textSpan] is provided instead.
  final String data;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SelectableText(data);
    }
    return Text(data);
  }
}
