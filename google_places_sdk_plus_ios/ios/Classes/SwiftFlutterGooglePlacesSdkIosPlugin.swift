import Flutter
import UIKit
import GooglePlaces

public class SwiftFlutterGooglePlacesSdkIosPlugin: NSObject, FlutterPlugin {
    static let CHANNEL_NAME = "plugins.msh.com/google_places_sdk_plus"
    let METHOD_INITIALIZE = "initialize"
    let METHOD_UPDATE_SETTINGS = "updateSettings"
    let METHOD_DEINITIALIZE = "deinitialize"
    let METHOD_IS_INITIALIZE = "isInitialized"
    let METHOD_FIND_AUTOCOMPLETE_PREDICTIONS = "findAutocompletePredictions"
    let METHOD_FETCH_PLACE = "fetchPlace"
    let METHOD_FETCH_PLACE_PHOTO = "fetchPlacePhoto"
    let METHOD_SEARCH_BY_TEXT = "searchByText"
    let METHOD_NEARBY_SEARCH = "searchNearby"
    
    private var placesClient: GMSPlacesClient!
    private var lastSessionToken: GMSAutocompleteSessionToken?
    
    private var photosCache: Dictionary<String, GMSPlacePhotoMetadata> = [:]
    
    private var initializedApiKey: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterGooglePlacesSdkIosPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case METHOD_INITIALIZE:
            let args = call.arguments as? Dictionary<String,Any>
            let apiKey = args?["apiKey"] as? String
            initialize(apiKey: apiKey)
            result(nil)
        case METHOD_UPDATE_SETTINGS:
            let args = call.arguments as? Dictionary<String,Any>
            let apiKey = args?["apiKey"] as? String
            updateSettings(apiKey: apiKey)
            result(nil)
        case METHOD_DEINITIALIZE:
            placesClient = nil
            initializedApiKey = nil
            photosCache.removeAll()
            result(nil)
        case METHOD_IS_INITIALIZE:
            result(placesClient != nil)
        case METHOD_FIND_AUTOCOMPLETE_PREDICTIONS:
            guard let args = call.arguments as? Dictionary<String,Any>,
                  let query = args["query"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments for findAutocompletePredictions", details: nil))
                return
            }
            let countries = args["countries"] as? [String]? ?? [String]()
            let placeTypeFilters = args["typesFilter"] as? [String]
            let origin = latLngFromMap(argument: args["origin"] as? Dictionary<String, Any?>)
            let newSessionToken = args["newSessionToken"] as? Bool
            let locationBias = rectangularBoundsFromMap(argument: args["locationBias"] as? Dictionary<String, Any?>)
            let locationRestriction = rectangularBoundsFromMap(argument: args["locationRestriction"] as? Dictionary<String, Any?>)
            let sessionToken = getSessionToken(force: newSessionToken == true)

            let filter = GMSAutocompleteFilter()
            filter.types = placeTypeFilters;
            filter.countries = countries
            filter.origin = origin
            filter.locationBias = locationBias
            filter.locationRestriction = locationRestriction

            let request = GMSAutocompleteRequest(query: query)
            request.filter = filter
            request.sessionToken = sessionToken

            placesClient.fetchAutocompleteSuggestions(from: request, callback: { (suggestions, error) in
                    if let error = error {
                        result(FlutterError(
                            code: "API_ERROR_AUTOCOMPLETE",
                            message: error.localizedDescription,
                            details: nil
                        ))
                    } else {
                        self.lastSessionToken = sessionToken
                        let mappedResult = self.suggestionsToList(suggestions: suggestions)
                        result(mappedResult)
                    }
                })
        case METHOD_FETCH_PLACE:
            guard let args = call.arguments as? Dictionary<String,Any>,
                  let placeId = args["placeId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments for fetchPlace", details: nil))
                return
            }
            let fields = ((args["fields"] as? [String])?.map {
                (item) in return placeFieldFromStr(it: item)
            })?.reduce(GMSPlaceField(), { partialResult, field in
                return GMSPlaceField(rawValue: partialResult.rawValue | field.rawValue)
            }) ?? GMSPlaceField.all
            let newSessionToken = args["newSessionToken"] as? Bool ?? false
            let sessionToken = getSessionToken(force: newSessionToken == true)

            let properties = placeFieldToProperties(fields: fields)
            let request = GMSFetchPlaceRequest(placeID: placeId, placeProperties: properties, sessionToken: sessionToken)

            placesClient.fetchPlace(with: request) { (place, error) in
                // End session after fetchPlace (billing optimization).
                // The next autocomplete call will create a new session token.
                self.lastSessionToken = nil

                if let error = error {
                    result(FlutterError(
                        code: "API_ERROR_PLACE",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    let mappedPlace = self.placeToMap(place: place)
                    result(mappedPlace)
                }
            }
        case METHOD_FETCH_PLACE_PHOTO:
            guard let args = call.arguments as? Dictionary<String,Any>,
                  let photoRef = args["photoReference"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments for fetchPlacePhoto", details: nil))
                return
            }
            let maxWidth = args["maxWidth"] as? Int
            let maxHeight = args["maxHeight"] as? Int
            if let maxWidth = maxWidth, maxWidth <= 0 {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "maxWidth must be positive, got \(maxWidth)", details: nil))
                return
            }
            if let maxHeight = maxHeight, maxHeight <= 0 {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "maxHeight must be positive, got \(maxHeight)", details: nil))
                return
            }
            let maxSize = CGSize(
                width: maxWidth ?? 4800,
                height: maxHeight ?? 4800
            )

            if let photoMetadata = photosCache[photoRef] {
                let request = GMSFetchPhotoRequest(photoMetadata: photoMetadata, maxSize: maxSize)
                placesClient.fetchPhoto(with: request, callback: { (photo, error) -> Void in
                    if let error = error {
                        result(FlutterError(
                            code: "API_ERROR_PHOTO",
                            message: error.localizedDescription,
                            details: nil
                        ))
                    } else {
                        let data = photo?.pngData()
                        result(data)
                    }
                })
            } else {
                result(FlutterError(
                    code: "API_ERROR_PHOTO",
                    message: "PhotoMetadata must be initially fetched with fetchPlace",
                    details: ""
                ))
            }
        case METHOD_SEARCH_BY_TEXT:
            guard let args = call.arguments as? Dictionary<String,Any>,
                  let textQuery = args["textQuery"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments for searchByText", details: nil))
                return
            }
            let includedType = args["includedType"] as? String
            let maxResultCount = args["maxResultCount"] as? Int
            let minRating = args["minRating"] as? Double
            let openNow = args["openNow"] as? Bool ?? false
            let priceLevels = args["priceLevels"] as? [Int] ?? []
            let regionCode = args["regionCode"] as? String
            let rankPreferenceStr = args["rankPreference"] as? String
            let strictTypeFiltering = args["strictTypeFiltering"] as? Bool ?? false
            let locationBias = rectangularBoundsFromMap(argument: args["locationBias"] as? Dictionary<String, Any?>)
            let locationRestriction = rectangularBoundsFromMap(argument: args["locationRestriction"] as? Dictionary<String, Any?>)
            let fields = ((args["fields"] as? [String])?.map {
                (item) in return placeFieldFromStr(it: item)
            })?.reduce(GMSPlaceField(), { partialResult, field in
                return GMSPlaceField(rawValue: partialResult.rawValue | field.rawValue)
            }) ?? GMSPlaceField.all

            let properties = placeFieldToProperties(fields: fields)
            let request = GMSPlaceSearchByTextRequest(textQuery: textQuery, placeProperties: properties)
            request.includedType = includedType
            if let maxResultCount = maxResultCount {
                request.maxResultCount = Int32(maxResultCount)
            }
            request.isOpenNow = openNow
            request.isStrictTypeFiltering = strictTypeFiltering
            if let minRating = minRating {
                request.minRating = Float(minRating)
            }
            if let regionCode = regionCode {
                request.regionCode = regionCode
            }
            if let locationBias = locationBias {
                request.locationBias = locationBias
            }
            if let locationRestriction = locationRestriction {
                request.locationRestriction = locationRestriction
            }
            if !priceLevels.isEmpty {
                request.priceLevels = priceLevels.map { NSNumber(value: $0) }
            }
            if let rankPreferenceStr = rankPreferenceStr {
                switch rankPreferenceStr {
                case "DISTANCE":
                    request.rankPreference = GMSPlaceSearchByTextRankPreference.distance
                default:
                    request.rankPreference = GMSPlaceSearchByTextRankPreference.relevance
                }
            }

            placesClient.searchByText(with: request) { (places, error) in
                if let error = error {
                    result(FlutterError(
                        code: "API_ERROR_SEARCH_BY_TEXT",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    let mappedPlaces = places?.map { self.placeToMap(place: $0) }
                    result(mappedPlaces)
                }
            }
        case METHOD_NEARBY_SEARCH:
            guard let args = call.arguments as? Dictionary<String,Any> else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments for searchNearby", details: nil))
                return
            }
            let fields = ((args["fields"] as? [String])?.map {
                (item) in return placeFieldFromStr(it: item)
            })?.reduce(GMSPlaceField(), { partialResult, field in
                return GMSPlaceField(rawValue: partialResult.rawValue | field.rawValue)
            }) ?? GMSPlaceField.all
            let locationRestrictionMap = args["locationRestriction"] as? Dictionary<String, Any?>
            if let centerMap = locationRestrictionMap?["center"] as? Dictionary<String, Any?> {
                if let lat = centerMap["lat"] as? Double, lat < -90.0 || lat > 90.0 {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "center latitude must be between -90 and 90, got \(lat)", details: nil))
                    return
                }
                if let lng = centerMap["lng"] as? Double, lng < -180.0 || lng > 180.0 {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "center longitude must be between -180 and 180, got \(lng)", details: nil))
                    return
                }
            }
            if let radiusVal = locationRestrictionMap?["radius"] as? Double, radiusVal <= 0.0 {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "radius must be positive, got \(radiusVal)", details: nil))
                return
            }
            let excludedPrimaryTypes = args["excludedPrimaryTypes"] as? [String] ?? []
            let excludedTypes = args["excludedTypes"] as? [String] ?? []
            let includedPrimaryTypes = args["includedPrimaryTypes"] as? [String] ?? []
            let includedTypes = args["includedTypes"] as? [String] ?? []
            let rankPreferenceStr = args["rankPreference"] as? String
            let regionCode = args["regionCode"] as? String
            let maxResultCount = args["maxResultCount"] as? Int
            
            guard let locationRestrictionMap = locationRestrictionMap,
                  let circularBounds = circularBoundsFromMap(argument: locationRestrictionMap) else {
                result(FlutterError(
                    code: "API_ERROR_NEARBY_SEARCH",
                    message: "locationRestriction is required for searchNearby",
                    details: nil
                ))
                return
            }
            
            let properties = placeFieldToProperties(fields: fields)
            let request = GMSPlaceSearchNearbyRequest(locationRestriction: circularBounds, placeProperties: properties)
            request.includedTypes = includedTypes
            request.excludedTypes = excludedTypes
            request.includedPrimaryTypes = includedPrimaryTypes
            request.excludedPrimaryTypes = excludedPrimaryTypes
            if let maxResultCount = maxResultCount {
                request.maxResultCount = maxResultCount
            }
            if let regionCode = regionCode {
                request.regionCode = regionCode
            }
            if let rankPreferenceStr = rankPreferenceStr {
                switch rankPreferenceStr {
                case "DISTANCE":
                    request.rankPreference = GMSPlaceSearchNearbyRankPreference.distance
                default:
                    request.rankPreference = GMSPlaceSearchNearbyRankPreference.popularity
                }
            }
            
            placesClient.searchNearby(with: request) { (places, error) in
                if let error = error {
                    result(FlutterError(
                        code: "API_ERROR_NEARBY_SEARCH",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    let mappedPlaces = places?.map { self.placeToMap(place: $0) }
                    result(mappedPlaces)
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Place serialization
    
    private func placeToMap(place: GMSPlace?) -> Dictionary<String, Any?> {
        guard let place = place else {
            return Dictionary<String, Any?>()
        }
        return [
            // ===== Legacy fields =====
            "id": place.placeID,
            "address": place.formattedAddress,
            "addressComponents": place.addressComponents?.map { addressComponentToMap(addressComponent: $0) },
            "businessStatus": businessStatusToStr(it: place.businessStatus),
            "attributions": place.attributions?.string,
            "latLng": latLngToMap(coordinate: place.coordinate),
            "name": place.name,
            "nameLanguageCode": nil as String?,
            "openingHours": openingHoursToMap(openingHours: place.openingHours),
            "phoneNumber": place.phoneNumber,
            "photoMetadatas": place.photos?.map { photoMetadataToMap(photoMetadata: $0) },
            "plusCode": plusCodeToMap(plusCode: place.plusCode),
            "priceLevel": priceLevelToString(priceLevel: place.priceLevel),
            "rating": place.rating > 0 ? place.rating : nil,
            "types": place.types?.map { $0.uppercased() },
            "userRatingsTotal": place.userRatingsTotal > 0 ? place.userRatingsTotal : nil,
            "utcOffsetMinutes": place.utcOffsetMinutes,
            "viewport": latLngBoundsToMap(viewport: place.viewportInfo),
            "websiteUri": place.website?.absoluteString,
            "reviews": place.reviews?.map { reviewToMap(review: $0) },
            
            // ===== New Places API (New) fields =====
            // Text / LocalizedText fields
            "displayName": localizedTextToMap(text: place.name, languageCode: nil),
            // primaryType, primaryTypeDisplayName, shortFormattedAddress
            // are not available in iOS SDK 10.x — serialize as nil
            "primaryType": nil as String?,
            "primaryTypeDisplayName": nil as Dictionary<String, Any?>?,
            "shortFormattedAddress": nil as String?,
            // GMSPlace.phoneNumber returns international format (with "+" country code)
            "internationalPhoneNumber": place.phoneNumber,
            "nationalPhoneNumber": place.phoneNumber,
            "adrFormatAddress": nil as String?,
            "editorialSummary": localizedTextToMap(text: place.editorialSummary, languageCode: nil),
            "iconBackgroundColor": place.iconBackgroundColor?.toHexString(),
            "iconMaskBaseUri": place.iconImageURL?.absoluteString,
            "googleMapsUri": nil as String?,
            "googleMapsLinks": nil as Dictionary<String, Any?>?,
            
            // Temporal fields
            "timeZone": nil as Dictionary<String, Any?>?,
            "currentOpeningHours": openingHoursToMap(openingHours: place.currentOpeningHours),
            "secondaryOpeningHours": place.secondaryOpeningHours?.map { openingHoursToMap(openingHours: $0) },
            // currentSecondaryOpeningHours not available in iOS SDK 10.x
            "currentSecondaryOpeningHours": nil as [Dictionary<String, Any?>]?,
            
            // Boolean service attributes (available in iOS SDK 10.x)
            "curbsidePickup": place.curbsidePickup.toBoolOrNil(),
            "delivery": place.delivery.toBoolOrNil(),
            "dineIn": place.dineIn.toBoolOrNil(),
            "reservable": place.reservable.toBoolOrNil(),
            "servesBeer": place.servesBeer.toBoolOrNil(),
            "servesBreakfast": place.servesBreakfast.toBoolOrNil(),
            "servesBrunch": place.servesBrunch.toBoolOrNil(),
            "servesDinner": place.servesDinner.toBoolOrNil(),
            "servesLunch": place.servesLunch.toBoolOrNil(),
            "servesVegetarianFood": place.servesVegetarianFood.toBoolOrNil(),
            "servesWine": place.servesWine.toBoolOrNil(),
            "takeout": place.takeout.toBoolOrNil(),
            "pureServiceAreaBusiness": place.pureServiceAreaBusiness.toBoolOrNil(),
            // Boolean attributes not available in iOS SDK 10.x
            "servesCocktails": nil as Bool?,
            "servesCoffee": nil as Bool?,
            "servesDessert": nil as Bool?,
            "goodForChildren": nil as Bool?,
            "allowsDogs": nil as Bool?,
            "restroom": nil as Bool?,
            "goodForGroups": nil as Bool?,
            "goodForWatchingSports": nil as Bool?,
            "liveMusic": nil as Bool?,
            "outdoorSeating": nil as Bool?,
            "menuForChildren": nil as Bool?,
            
            // Complex option types
            "accessibilityOptions": accessibilityOptionsToMap(place: place),
            "paymentOptions": nil as Dictionary<String, Any?>?,
            "parkingOptions": nil as Dictionary<String, Any?>?,
            "evChargeOptions": nil as Dictionary<String, Any?>?,
            "fuelOptions": nil as Dictionary<String, Any?>?,
            "priceRange": nil as Dictionary<String, Any?>?,
            "priceLevelNew": nil as String?,
            
            // Summaries & AI content
            "generativeSummary": nil as Dictionary<String, Any?>?,
            "reviewSummary": nil as Dictionary<String, Any?>?,
            "neighborhoodSummary": nil as Dictionary<String, Any?>?,
            "evChargeAmenitySummary": nil as Dictionary<String, Any?>?,
            
            // Relational data
            "postalAddress": nil as Dictionary<String, Any?>?,
            "subDestinations": nil as [Dictionary<String, Any?>]?,
            "containingPlaces": nil as [Dictionary<String, Any?>]?,
            "addressDescriptor": nil as Dictionary<String, Any?>?,
            "consumerAlerts": nil as [Dictionary<String, Any?>]?
        ]
    }
    
    // MARK: - Review serialization
    
    private func reviewToMap(review: GMSPlaceReview) -> Dictionary<String, Any?> {
        return [
            "attribution": review.authorAttribution?.name,
            "authorAttribution": authorAttributionToMap(author: review.authorAttribution),
            "originalText": localizedTextToMap(text: review.originalText, languageCode: review.originalTextLanguageCode),
            "rating": review.rating,
            "publishTime": nil as String?,
            "relativePublishTimeDescription": review.relativePublishDateDescription,
            "text": localizedTextToMap(text: review.text, languageCode: review.textLanguageCode),
        ]
    }
    
    private func authorAttributionToMap(author: GMSPlaceAuthorAttribution?) -> Dictionary<String, String?>? {
        guard let author = author else { return nil }
        return [
            "name": author.name,
            "photoUri": author.photoURI?.absoluteString,
            "uri": author.uri?.absoluteString
        ]
    }
    
    // MARK: - Accessibility options
    
    private func accessibilityOptionsToMap(place: GMSPlace) -> Dictionary<String, Any?>? {
        // iOS SDK 10.x only exposes wheelchairAccessibleEntrance as a GMSBooleanPlaceAttribute
        // on GMSPlace directly. Other accessibility fields are not available.
        let entrance = place.wheelchairAccessibleEntrance.toBoolOrNil()
        
        if entrance == nil {
            return nil
        }
        
        return [
            "wheelchairAccessibleEntrance": entrance,
            "wheelchairAccessibleParking": nil as Bool?,
            "wheelchairAccessibleRestroom": nil as Bool?,
            "wheelchairAccessibleSeating": nil as Bool?
        ]
    }
    
    // MARK: - Helper: LocalizedText
    
    func localizedTextToMap(text: String?, languageCode: String?) -> Dictionary<String, Any?>? {
        guard let text = text else { return nil }
        return [
            "text": text,
            "languageCode": languageCode
        ]
    }
    
    // MARK: - PriceLevel

    func priceLevelToString(priceLevel: GMSPlacesPriceLevel) -> String? {
        switch priceLevel {
        case .free:
            return "PRICE_LEVEL_FREE"
        case .cheap:
            return "PRICE_LEVEL_INEXPENSIVE"
        case .medium:
            return "PRICE_LEVEL_MODERATE"
        case .high:
            return "PRICE_LEVEL_EXPENSIVE"
        case .expensive:
            return "PRICE_LEVEL_VERY_EXPENSIVE"
        default:
            return nil
        }
    }

    // MARK: - Business status

    func businessStatusToStr(it: GMSPlacesBusinessStatus) -> String? {
        switch (it) {
        case GMSPlacesBusinessStatus.operational:
            return "OPERATIONAL";
        case GMSPlacesBusinessStatus.closedTemporarily:
            return "CLOSED_TEMPORARILY";
        case GMSPlacesBusinessStatus.closedPermanently:
            return "CLOSED_PERMANENTLY";
        default:
            return nil;
        }
    }
    
    // MARK: - PlusCode
    
    private func plusCodeToMap(plusCode: GMSPlusCode?) -> Dictionary<String, Any?>? {
        guard let plusCode = plusCode else {
            return nil
        }
        
        return [
            "compoundCode": plusCode.compoundCode,
            "globalCode": plusCode.globalCode
        ]
    }
    
    // MARK: - Photo metadata
    
    private func photoMetadataToMap(photoMetadata: GMSPlacePhotoMetadata) -> Dictionary<String, Any?> {
        let photoRef = _getPhotoReference()
        
        photosCache[photoRef] = photoMetadata
        
        return [
            "photoReference": photoRef,
            "width": Int(photoMetadata.maxSize.width),
            "height": Int(photoMetadata.maxSize.height),
            "attributions": photoMetadata.attributions?.string ?? "",
            "authorAttributions": photoMetadata.authorAttributions?.map { authorAttr -> Dictionary<String, String?> in
                return [
                    "name": authorAttr.name,
                    "photoUri": authorAttr.photoURI?.absoluteString,
                    "uri": authorAttr.uri?.absoluteString
                ]
            },
            "flagContentUri": nil as String?,
            "googleMapsUri": nil as String?
        ]
    }
    
    private func _getPhotoReference() -> String {
        return UUID().uuidString
    }
    
    // MARK: - Opening hours
    
    private func openingHoursToMap(openingHours: GMSOpeningHours?) -> Dictionary<String, Any?>? {
        guard let openingHours = openingHours else {
            return nil
        }
        return [
            "periods": openingHours.periods?.map { periodToMap(period: $0) },
            "weekdayText": openingHours.weekdayText
        ]
    }
    
    private func periodToMap(period: GMSPeriod) -> Dictionary<String, Any?> {
        return [
            "open": timeOfWeekToMap(event: period.openEvent),
            "close": timeOfWeekToMap(event: period.closeEvent)
        ]
    }
    
    private func timeOfWeekToMap(event: GMSEvent?) -> Dictionary<String, Any?>? {
        guard let event = event else {
            return nil
        }
        return [
            "day": dayOfWeekToStr(it: event.day),
            "time": placeLocalTimeToMap(time: event.time)
        ]
    }
    
    func dayOfWeekToStr(it: GMSDayOfWeek) -> String {
        switch (it) {
        case GMSDayOfWeek.sunday: return "SUNDAY";
        case GMSDayOfWeek.monday: return "MONDAY";
        case GMSDayOfWeek.tuesday: return "TUESDAY";
        case GMSDayOfWeek.wednesday: return "WEDNESDAY";
        case GMSDayOfWeek.thursday: return "THURSDAY";
        case GMSDayOfWeek.friday: return "FRIDAY";
        case GMSDayOfWeek.saturday: return "SATURDAY";
        default: return "NULL";
        }
    }

    private func placeLocalTimeToMap(time: GMSTime) -> Dictionary<String, Any?> {
      return [
        "hours": time.hour,
        "minutes": time.minute
      ]
    }
    
    // MARK: - Geometry helpers
    
    func latLngToMap(coordinate: CLLocationCoordinate2D?) -> Any? {
        guard let coordinate = coordinate else {
            return nil
        }
        return [
            "lat": coordinate.latitude,
            "lng": coordinate.longitude
        ]
    }

    private func latLngBoundsToMap(viewport: GMSPlaceViewportInfo?) -> Dictionary<String, Any?>? {
        guard let viewport = viewport else {
            return nil
        }
        return [
            "southwest": latLngToMap(coordinate: viewport.southWest),
            "northeast": latLngToMap(coordinate: viewport.northEast)
        ]
    }

    private func addressComponentToMap(addressComponent: GMSAddressComponent) -> Dictionary<String, Any?> {
      return [
        "name": addressComponent.name,
        "shortName": addressComponent.shortName,
        "types": addressComponent.types
      ]
    }
    
    // MARK: - PlaceField mapping
    
    func placeFieldFromStr(it: String) -> GMSPlaceField {
        switch (it) {
        // Core / legacy fields
        case "FormattedAddress", "ADDRESS", "FORMATTED_ADDRESS": return GMSPlaceField.formattedAddress
        case "AddressComponents", "ADDRESS_COMPONENTS": return GMSPlaceField.addressComponents
        case "BusinessStatus", "BUSINESS_STATUS": return GMSPlaceField.businessStatus
        case "Id", "ID": return GMSPlaceField.placeID
        case "Location", "LAT_LNG": return GMSPlaceField.coordinate
        case "DisplayName", "NAME": return GMSPlaceField.name
        case "OpeningHours", "OPENING_HOURS": return GMSPlaceField.openingHours
        case "NationalPhoneNumber", "InternationalPhoneNumber", "PHONE_NUMBER": return GMSPlaceField.phoneNumber
        case "Photos", "PHOTO_METADATAS": return GMSPlaceField.photos
        case "PlusCode", "PLUS_CODE": return GMSPlaceField.plusCode
        case "PriceLevel", "PRICE_LEVEL": return GMSPlaceField.priceLevel
        case "Rating", "RATING": return GMSPlaceField.rating
        case "Types", "TYPES": return GMSPlaceField.types
        case "UserRatingCount", "USER_RATINGS_TOTAL", "USER_RATING_COUNT": return GMSPlaceField.userRatingsTotal
        case "UtcOffset", "UTC_OFFSET": return GMSPlaceField.utcOffsetMinutes
        case "Viewport", "VIEWPORT": return GMSPlaceField.viewport
        case "WebsiteUri", "WEBSITE_URI": return GMSPlaceField.website
        
        // New Places API fields supported by iOS SDK 10.x as GMSPlaceField bitmask
        case "CurbsidePickup", "CURBSIDE_PICKUP": return GMSPlaceField.curbsidePickup
        case "CurrentOpeningHours", "CURRENT_OPENING_HOURS": return GMSPlaceField.currentOpeningHours
        case "Delivery", "DELIVERY": return GMSPlaceField.delivery
        case "DineIn", "DINE_IN": return GMSPlaceField.dineIn
        case "EditorialSummary", "EDITORIAL_SUMMARY": return GMSPlaceField.editorialSummary
        case "IconBackgroundColor", "ICON_BACKGROUND_COLOR": return GMSPlaceField.iconBackgroundColor
        case "IconMaskUrl", "ICON_MASK_URL": return GMSPlaceField.iconImageURL
        case "Reservable", "RESERVABLE": return GMSPlaceField.reservable
        case "SecondaryOpeningHours", "SECONDARY_OPENING_HOURS": return GMSPlaceField.secondaryOpeningHours
        case "ServesBeer", "SERVES_BEER": return GMSPlaceField.servesBeer
        case "ServesBreakfast", "SERVES_BREAKFAST": return GMSPlaceField.servesBreakfast
        case "ServesBrunch", "SERVES_BRUNCH": return GMSPlaceField.servesBrunch
        case "ServesDinner", "SERVES_DINNER": return GMSPlaceField.servesDinner
        case "ServesLunch", "SERVES_LUNCH": return GMSPlaceField.servesLunch
        case "ServesVegetarianFood", "SERVES_VEGETARIAN_FOOD": return GMSPlaceField.servesVegetarianFood
        case "ServesWine", "SERVES_WINE": return GMSPlaceField.servesWine
        case "Takeout", "TAKEOUT": return GMSPlaceField.takeout
        case "WheelchairAccessibleEntrance", "WHEELCHAIR_ACCESSIBLE_ENTRANCE": return GMSPlaceField.wheelchairAccessibleEntrance
            
        // Fields not in GMSPlaceField bitmask but available via GMSPlaceProperty
        // (used by search requests — for fetchPlace bitmask, they are silently ignored)
        case "Reviews", "REVIEWS",
             "AccessibilityOptions", "ACCESSIBILITY_OPTIONS",
             "PrimaryType", "PRIMARY_TYPE",
             "PrimaryTypeDisplayName", "PRIMARY_TYPE_DISPLAY_NAME",
             "ShortFormattedAddress", "SHORT_FORMATTED_ADDRESS",
             "PureServiceAreaBusiness", "PURE_SERVICE_AREA_BUSINESS":
            return GMSPlaceField()
            
        // Fields not supported by iOS SDK at all — return empty field (silently ignored)
        case "FormattedAddressAdr", "FORMATTED_ADDRESS_ADR",
             "AdrFormatAddress", "ADR_FORMAT_ADDRESS",
             "GoogleMapsUri", "GOOGLE_MAPS_URI",
             "GoogleMapsLinks", "GOOGLE_MAPS_LINKS",
             "TimeZone", "TIME_ZONE",
             "PostalAddress", "POSTAL_ADDRESS",
             "CurrentSecondaryOpeningHours", "CURRENT_SECONDARY_OPENING_HOURS",
             "PaymentOptions", "PAYMENT_OPTIONS",
             "ParkingOptions", "PARKING_OPTIONS",
             "EvChargeOptions", "EV_CHARGE_OPTIONS",
             "FuelOptions", "FUEL_OPTIONS",
             "PriceRange", "PRICE_RANGE",
             "SubDestinations", "SUB_DESTINATIONS",
             "ContainingPlaces", "CONTAINING_PLACES",
             "AddressDescriptor", "ADDRESS_DESCRIPTOR",
             "GenerativeSummary", "GENERATIVE_SUMMARY",
             "ReviewSummary", "REVIEW_SUMMARY",
             "NeighborhoodSummary", "NEIGHBORHOOD_SUMMARY",
             "EvChargeAmenitySummary", "EV_CHARGE_AMENITY_SUMMARY",
             "ConsumerAlerts", "CONSUMER_ALERTS",
             "ServesCocktails", "SERVES_COCKTAILS",
             "ServesCoffee", "SERVES_COFFEE",
             "ServesDessert", "SERVES_DESSERT",
             "GoodForChildren", "GOOD_FOR_CHILDREN",
             "AllowsDogs", "ALLOWS_DOGS",
             "Restroom", "RESTROOM",
             "GoodForGroups", "GOOD_FOR_GROUPS",
             "GoodForWatchingSports", "GOOD_FOR_WATCHING_SPORTS",
             "LiveMusic", "LIVE_MUSIC",
             "OutdoorSeating", "OUTDOOR_SEATING",
             "MenuForChildren", "MENU_FOR_CHILDREN":
            return GMSPlaceField()
            
        default:
            return GMSPlaceField()
        }
    }
    
    // MARK: - PlaceField to properties (for search requests)
    
    private func placeFieldToProperties(fields: GMSPlaceField) -> [String] {
        var properties: [String] = []
        
        let fieldMappings: [(GMSPlaceField, String)] = [
            (.name, GMSPlaceProperty.name.rawValue),
            (.placeID, GMSPlaceProperty.placeID.rawValue),
            (.coordinate, GMSPlaceProperty.coordinate.rawValue),
            (.formattedAddress, GMSPlaceProperty.formattedAddress.rawValue),
            (.businessStatus, GMSPlaceProperty.businessStatus.rawValue),
            (.openingHours, GMSPlaceProperty.openingHours.rawValue),
            (.phoneNumber, GMSPlaceProperty.phoneNumber.rawValue),
            (.photos, GMSPlaceProperty.photos.rawValue),
            (.plusCode, GMSPlaceProperty.plusCode.rawValue),
            (.priceLevel, GMSPlaceProperty.priceLevel.rawValue),
            (.rating, GMSPlaceProperty.rating.rawValue),
            (.types, GMSPlaceProperty.types.rawValue),
            (.userRatingsTotal, GMSPlaceProperty.userRatingsTotal.rawValue),
            (.utcOffsetMinutes, GMSPlaceProperty.utcOffsetMinutes.rawValue),
            (.viewport, GMSPlaceProperty.viewport.rawValue),
            (.website, GMSPlaceProperty.website.rawValue),
            (.addressComponents, GMSPlaceProperty.addressComponents.rawValue),
            (.iconBackgroundColor, GMSPlaceProperty.iconBackgroundColor.rawValue),
            (.iconImageURL, GMSPlaceProperty.iconImageURL.rawValue),
            (.curbsidePickup, GMSPlaceProperty.curbsidePickup.rawValue),
            (.currentOpeningHours, GMSPlaceProperty.currentOpeningHours.rawValue),
            (.delivery, GMSPlaceProperty.delivery.rawValue),
            (.dineIn, GMSPlaceProperty.dineIn.rawValue),
            (.editorialSummary, GMSPlaceProperty.editorialSummary.rawValue),
            (.reservable, GMSPlaceProperty.reservable.rawValue),
            (.secondaryOpeningHours, GMSPlaceProperty.secondaryOpeningHours.rawValue),
            (.servesBeer, GMSPlaceProperty.servesBeer.rawValue),
            (.servesBreakfast, GMSPlaceProperty.servesBreakfast.rawValue),
            (.servesBrunch, GMSPlaceProperty.servesBrunch.rawValue),
            (.servesDinner, GMSPlaceProperty.servesDinner.rawValue),
            (.servesLunch, GMSPlaceProperty.servesLunch.rawValue),
            (.servesVegetarianFood, GMSPlaceProperty.servesVegetarianFood.rawValue),
            (.servesWine, GMSPlaceProperty.servesWine.rawValue),
            (.takeout, GMSPlaceProperty.takeout.rawValue),
            (.wheelchairAccessibleEntrance, GMSPlaceProperty.wheelchairAccessibleEntrance.rawValue),
        ]
        
        for (field, property) in fieldMappings {
            if fields.contains(field) {
                properties.append(property)
            }
        }
        
        // Always include reviews and pureServiceAreaBusiness if requesting all fields
        if fields == GMSPlaceField.all {
            properties.append(GMSPlaceProperty.reviews.rawValue)
            properties.append(GMSPlaceProperty.pureServiceAreaBusiness.rawValue)
        }
        
        // If no specific fields, return all
        if properties.isEmpty {
            return GMSPlacePropertyArray() as [String]
        }
        
        return properties
    }
    
    // MARK: - Autocomplete
    
    private func suggestionsToList(suggestions: [GMSAutocompleteSuggestion]?) -> [Dictionary<String, Any?>]? {
        guard let suggestions = suggestions else {
            return nil
        }
        
        return suggestions.compactMap { (suggestion: GMSAutocompleteSuggestion) -> Dictionary<String, Any?>? in
            guard let placeSuggestion = suggestion.placeSuggestion else {
                return nil
            }
            return suggestionToMap(suggestion: placeSuggestion)
        }
    }
    
    private func suggestionToMap(suggestion: GMSAutocompletePlaceSuggestion) -> Dictionary<String, Any?> {
        return [
            "placeId": suggestion.placeID,
            "distanceMeters": suggestion.distanceMeters,
            "primaryText": suggestion.attributedPrimaryText.string,
            "secondaryText": suggestion.attributedSecondaryText?.string ?? "",
            "fullText": suggestion.attributedFullText.string,
            "placeTypes": suggestion.types.map { $0.uppercased() }
        ]
    }

    // MARK: - Session tokens
    
    private func getSessionToken(force: Bool) -> GMSAutocompleteSessionToken? {
        let localToken = lastSessionToken
        if (force || localToken == nil) {
            return GMSAutocompleteSessionToken.init()
        }
        return localToken
    }
    
    // MARK: - Bounds helpers
    
    private func rectangularBoundsFromMap(argument: Dictionary<String, Any?>?) -> (GMSPlaceLocationBias & GMSPlaceLocationRestriction)? {
        guard let argument = argument,
              let southWest = latLngFromMap(argument: argument["southwest"] as? Dictionary<String, Any?>)?.coordinate as? CLLocationCoordinate2D,
              let northEast = latLngFromMap(argument: argument["northeast"] as? Dictionary<String, Any?>)?.coordinate as? CLLocationCoordinate2D
               else {
            return nil
        }
        
        return GMSPlaceRectangularLocationOption(northEast, southWest);
    }
    
    private func circularBoundsFromMap(argument: Dictionary<String, Any?>) -> (GMSPlaceLocationBias & GMSPlaceLocationRestriction)? {
        guard let centerMap = argument["center"] as? Dictionary<String, Any?>,
              let center = latLngFromMap(argument: centerMap),
              let radius = argument["radius"] as? Double else {
            return nil
        }
        
        return GMSPlaceCircularLocationOption(center.coordinate, radius)
    }
    
    func latLngFromMap(argument: Dictionary<String, Any?>?) -> CLLocation? {
        guard let argument = argument,
              let lat = argument["lat"] as? Double,
              let lng = argument["lng"] as? Double else {
            return nil
        }
        
        return CLLocation(latitude: lat, longitude: lng)
    }
    
    // MARK: - Initialization
    
    private func initialize(apiKey: String?) {
        GMSPlacesClient.provideAPIKey(apiKey ?? "")
        placesClient = GMSPlacesClient.shared()
        initializedApiKey = apiKey
    }
    
    private func updateSettings(apiKey: String?) {
        if initializedApiKey != apiKey {
            GMSPlacesClient.provideAPIKey(apiKey ?? "")
            placesClient = GMSPlacesClient.shared()
            initializedApiKey = apiKey
        }
    }
}

// MARK: - Extensions

extension GMSBooleanPlaceAttribute {
    func toBoolOrNil() -> Bool? {
        switch self {
        case .true:
            return true
        case .false:
            return false
        default:
            return nil
        }
    }
}

extension UIColor {
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
