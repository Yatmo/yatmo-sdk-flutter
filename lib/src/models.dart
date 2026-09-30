import 'configuration.dart';

/// Simple latitude / longitude pair (distinct from maplibre_gl's LatLng so the models stay free of the map dependency).
class YatmoLatLng {
  const YatmoLatLng(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

// ---- /Points ----------------------------------------------------------------------------------

/// One point of interest as returned by GET /Points (compact keys on the wire).
class YatmoPoi {
  const YatmoPoi({
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.categoryId,
    required this.icon,
    required this.subIcon,
    required this.grouped,
    this.rpt,
    this.specificData,
    this.filterId,
  });

  factory YatmoPoi.fromJson(Map<String, dynamic> o) => YatmoPoi(
        name: (o['n'] ?? '') as String,
        type: (o['t'] ?? '') as String,
        latitude: (o['la'] as num).toDouble(),
        longitude: (o['ln'] as num).toDouble(),
        categoryId: (o['p'] ?? '').toString(),
        icon: (o['i'] ?? '').toString(),
        subIcon: (o['si'] ?? '').toString(),
        grouped: o['g'] == true,
        rpt: o['rpt']?.toString(),
        specificData: o['sd']?.toString(),
        filterId: o['fid']?.toString(),
      );

  final String name;

  /// Translated type, for example "Preschool" or "Bus stop (Dansaert)".
  final String type;
  final double latitude;
  final double longitude;

  /// Category id, the value to pass in `poiTypeIds`.
  final String categoryId;

  /// Icon ids, comma separated when several POIs share the same position.
  final String icon;

  /// Sub-icon ids (transit lines), comma separated, may be empty.
  final String subIcon;
  final bool grouped;
  final String? rpt;

  /// Specific data as a JSON string (transit lines, brand...), "{}" when empty.
  final String? specificData;
  final String? filterId;

  String get id => '$latitude,$longitude,$name';
  List<String> get iconIds => icon.split(',').where((s) => s.isNotEmpty).toList();
  List<String> get subIconIds => subIcon.split(',').where((s) => s.isNotEmpty).toList();
}

// ---- /Summary ---------------------------------------------------------------------------------

/// Travel information for one mode, as computed by the routing engine.
class YatmoTravelData {
  const YatmoTravelData({
    required this.hasTravelInformation,
    required this.travelModeCode,
    this.translatedTravelMode,
    this.distanceMeters,
    this.distanceLongLabel,
    this.distanceShortLabel,
    this.travelTimeSeconds,
    this.travelTimeLongLabel,
    this.travelTimeShortLabel,
    this.travelTimeExtraShortLabel,
  });

  factory YatmoTravelData.fromJson(Map<String, dynamic> o) => YatmoTravelData(
        hasTravelInformation: o['hti'] == true,
        travelModeCode: (o['tm'] as num?)?.toInt() ?? 0,
        translatedTravelMode: o['ttm'] as String?,
        distanceMeters: (o['ptdd'] as num?)?.toInt(),
        distanceLongLabel: o['ptdll'] as String?,
        distanceShortLabel: o['ptdsl'] as String?,
        travelTimeSeconds: (o['tt'] as num?)?.toInt(),
        travelTimeLongLabel: o['ttll'] as String?,
        travelTimeShortLabel: o['ttsl'] as String?,
        travelTimeExtraShortLabel: o['ttesl'] as String?,
      );

  final bool hasTravelInformation;

  /// 1 driving, 2 walking, 3 bicycling, 4 transit. See [travelMode].
  final int travelModeCode;
  final String? translatedTravelMode;
  final int? distanceMeters;
  final String? distanceLongLabel;
  final String? distanceShortLabel;
  final int? travelTimeSeconds;
  final String? travelTimeLongLabel;
  final String? travelTimeShortLabel;
  final String? travelTimeExtraShortLabel;

  TravelMode? get travelMode => TravelMode.fromSummaryCode(travelModeCode);
}

/// One place inside a Summary sub-category.
class YatmoSummaryPlace {
  const YatmoSummaryPlace({
    required this.categoryId,
    required this.icon,
    required this.subIcon,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.travelData,
    this.specificData,
  });

  factory YatmoSummaryPlace.fromJson(Map<String, dynamic> o) => YatmoSummaryPlace(
        categoryId: (o['id'] as num?)?.toInt() ?? 0,
        icon: (o['i'] as num?)?.toInt() ?? 0,
        subIcon: (o['si'] as num?)?.toInt() ?? 0,
        latitude: (o['la'] as num).toDouble(),
        longitude: (o['lo'] as num).toDouble(),
        name: (o['n'] ?? '') as String,
        specificData: o['sd']?.toString(),
        travelData: _list(o['td'], YatmoTravelData.fromJson),
      );

  final int categoryId;
  final int icon;
  final int subIcon;
  final double latitude;
  final double longitude;
  final String name;
  final String? specificData;
  final List<YatmoTravelData> travelData;

  YatmoTravelData? travel(TravelMode mode) {
    for (final t in travelData) {
      if (t.travelModeCode == mode.summaryCode) return t;
    }
    return null;
  }
}

class YatmoSummarySubCategory {
  const YatmoSummarySubCategory({required this.subType, required this.label, required this.places, this.singularLabel});

  factory YatmoSummarySubCategory.fromJson(Map<String, dynamic> o) => YatmoSummarySubCategory(
        subType: (o['st'] as num?)?.toInt() ?? 0,
        label: (o['l'] ?? '') as String,
        singularLabel: o['lb'] as String?,
        places: _list(o['d'], YatmoSummaryPlace.fromJson),
      );

  final int subType;
  final String label;
  final String? singularLabel;
  final List<YatmoSummaryPlace> places;
}

class YatmoSummaryCategory {
  const YatmoSummaryCategory({required this.categoryType, required this.label, required this.subCategories});

  factory YatmoSummaryCategory.fromJson(Map<String, dynamic> o) => YatmoSummaryCategory(
        categoryType: (o['ct'] as num?)?.toInt() ?? 0,
        label: (o['l'] ?? '') as String,
        subCategories: _list(o['sc'], YatmoSummarySubCategory.fromJson),
      );

  final int categoryType;
  final String label;
  final List<YatmoSummarySubCategory> subCategories;
}

class YatmoCloseCity {
  const YatmoCloseCity({required this.names, required this.travelData, this.center});

  factory YatmoCloseCity.fromJson(Map<String, dynamic> o) => YatmoCloseCity(
        names: _stringMap(o['n']),
        travelData: _list(o['td'], YatmoTravelData.fromJson),
        center: o['c'] is Map ? YatmoLatLng((o['c']['Latitude'] as num).toDouble(), (o['c']['Longitude'] as num).toDouble()) : null,
      );

  /// City name per language code (EN, FR, NL...).
  final Map<String, String> names;
  final List<YatmoTravelData> travelData;
  final YatmoLatLng? center;

  String? name(Language language) => names[language.name.toUpperCase()] ?? names['EN'] ?? (names.isEmpty ? null : names.values.first);
}

class YatmoPlaceInformation {
  const YatmoPlaceInformation({
    required this.isLocality,
    this.streetName,
    this.cityName,
    this.zipCode,
    this.localizedStreetNames,
    this.localizedCityNames,
  });

  factory YatmoPlaceInformation.fromJson(Map<String, dynamic> o) => YatmoPlaceInformation(
        streetName: o['StreetName'] as String?,
        isLocality: o['IsLocality'] == true,
        cityName: o['CityName'] as String?,
        zipCode: o['ZipCode'] as String?,
        localizedStreetNames: o['LocalizedStreetNames'] == null ? null : _stringMap(o['LocalizedStreetNames']),
        localizedCityNames: o['LocalizedCityNames'] == null ? null : _stringMap(o['LocalizedCityNames']),
      );

  final String? streetName;
  final bool isLocality;
  final String? cityName;
  final String? zipCode;
  final Map<String, String>? localizedStreetNames;
  final Map<String, String>? localizedCityNames;
}

/// GET /Summary: nearby places grouped by category, closest cities and reverse-geocoded place.
class YatmoSummary {
  const YatmoSummary({required this.categories, required this.closeCities, this.placeInformation});

  factory YatmoSummary.fromJson(Map<String, dynamic> o) => YatmoSummary(
        categories: _list(o['AvailableCategoriesAroundPosition'], YatmoSummaryCategory.fromJson),
        closeCities: _list(o['CloseCities'], YatmoCloseCity.fromJson),
        placeInformation: o['PlaceInformation'] is Map ? YatmoPlaceInformation.fromJson(Map<String, dynamic>.from(o['PlaceInformation'] as Map)) : null,
      );

  final List<YatmoSummaryCategory> categories;
  final List<YatmoCloseCity> closeCities;
  final YatmoPlaceInformation? placeInformation;
}

// ---- /Summary/text ----------------------------------------------------------------------------

class YatmoSummaryParagraph {
  const YatmoSummaryParagraph(this.sentences);
  final List<String> sentences;
  String get text => sentences.join(' ');
}

/// Generated neighbourhood paragraphs, resolved to the configured language by the client.
class YatmoSummaryText {
  const YatmoSummaryText(this.paragraphs);

  factory YatmoSummaryText.fromJson(Map<String, dynamic> o, Language language) {
    final code = language.name.toUpperCase();
    final paragraphs = _list(o['Paragraphs'], (p) {
      final sentences = <String>[];
      for (final s in (p['Sentences'] as List? ?? const [])) {
        if (s is! Map) continue;
        final text = s[code] ?? s['EN'] ?? (s.isEmpty ? null : s.values.first);
        if (text is String && text.isNotEmpty) sentences.add(text);
      }
      return YatmoSummaryParagraph(sentences);
    });
    return YatmoSummaryText(paragraphs);
  }

  final List<YatmoSummaryParagraph> paragraphs;
  String get text => paragraphs.map((p) => p.text).join('\n\n');
}

// ---- /Scores ----------------------------------------------------------------------------------

class YatmoScore {
  const YatmoScore({required this.key, required this.label, required this.value, required this.subTypes, this.iconId, this.categoryType});

  factory YatmoScore.fromJson(Map<String, dynamic> o) => YatmoScore(
        key: (o['k'] ?? '') as String,
        label: (o['l'] ?? '') as String,
        value: (o['v'] as num?)?.toDouble() ?? 0,
        iconId: (o['iconId'] as num?)?.toInt(),
        categoryType: (o['pt'] as num?)?.toInt(),
        subTypes: (o['st'] as List? ?? const []).map((e) => (e as num).toInt()).toList(),
      );

  /// Stable key: publicTransport, trains, motorways, nurseries, schools, supermarkets...
  final String key;
  final String label;

  /// 0 to 10.
  final double value;
  final int? iconId;
  final int? categoryType;
  final List<int> subTypes;
}

class YatmoScores {
  const YatmoScores({required this.scores, this.language});

  factory YatmoScores.fromJson(Map<String, dynamic> o) =>
      YatmoScores(scores: _list(o['scores'], YatmoScore.fromJson), language: o['language'] as String?);

  final List<YatmoScore> scores;
  final String? language;
}

// ---- /Enrichment ------------------------------------------------------------------------------

class YatmoTravelInfo {
  const YatmoTravelInfo({required this.distanceMeters, required this.durationSeconds, required this.durationMinutes});

  static YatmoTravelInfo? fromJson(dynamic o) => o is Map
      ? YatmoTravelInfo(
          distanceMeters: (o['distanceMeters'] as num?)?.toInt() ?? 0,
          durationSeconds: (o['durationSeconds'] as num?)?.toInt() ?? 0,
          durationMinutes: (o['durationMinutes'] as num?)?.toInt() ?? 0,
        )
      : null;

  final int distanceMeters;
  final int durationSeconds;
  final int durationMinutes;
}

class YatmoNearestPoi {
  const YatmoNearestPoi({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.straightLineDistanceMeters,
    this.walking,
    this.bicycling,
    this.driving,
    this.transit,
  });

  factory YatmoNearestPoi.fromJson(Map<String, dynamic> o) => YatmoNearestPoi(
        name: (o['name'] ?? '') as String,
        latitude: (o['latitude'] as num).toDouble(),
        longitude: (o['longitude'] as num).toDouble(),
        straightLineDistanceMeters: (o['straightLineDistanceMeters'] as num?)?.toInt() ?? 0,
        walking: YatmoTravelInfo.fromJson(o['walking']),
        bicycling: YatmoTravelInfo.fromJson(o['bicycling']),
        driving: YatmoTravelInfo.fromJson(o['driving']),
        transit: YatmoTravelInfo.fromJson(o['transit']),
      );

  final String name;
  final double latitude;
  final double longitude;
  final int straightLineDistanceMeters;
  final YatmoTravelInfo? walking;
  final YatmoTravelInfo? bicycling;
  final YatmoTravelInfo? driving;
  final YatmoTravelInfo? transit;
}

class YatmoEnrichedCategory {
  const YatmoEnrichedCategory({required this.id, required this.key, required this.group, required this.label, this.nearest});

  factory YatmoEnrichedCategory.fromJson(Map<String, dynamic> o) => YatmoEnrichedCategory(
        id: (o['id'] as num?)?.toInt() ?? 0,
        key: (o['key'] ?? '') as String,
        group: (o['group'] ?? '') as String,
        label: (o['label'] ?? '') as String,
        nearest: o['nearest'] is Map ? YatmoNearestPoi.fromJson(Map<String, dynamic>.from(o['nearest'] as Map)) : null,
      );

  final int id;
  final String key;
  final String group;
  final String label;
  final YatmoNearestPoi? nearest;
}

/// GET /Enrichment: the nearest place of each category with routed distances and times.
class YatmoEnrichment {
  const YatmoEnrichment({
    required this.latitude,
    required this.longitude,
    required this.country,
    required this.language,
    required this.searchRadiusMeters,
    required this.categories,
  });

  factory YatmoEnrichment.fromJson(Map<String, dynamic> o) => YatmoEnrichment(
        latitude: (o['latitude'] as num).toDouble(),
        longitude: (o['longitude'] as num).toDouble(),
        country: (o['country'] ?? '') as String,
        language: (o['language'] ?? '') as String,
        searchRadiusMeters: (o['searchRadiusMeters'] as num?)?.toInt() ?? 0,
        categories: _list(o['categories'], YatmoEnrichedCategory.fromJson),
      );

  final double latitude;
  final double longitude;
  final String country;
  final String language;
  final int searchRadiusMeters;
  final List<YatmoEnrichedCategory> categories;
}

// ---- /Isochrone/GetMultipleTimes --------------------------------------------------------------

/// One reachable area. [geometry] is the GeoJSON geometry (Polygon or MultiPolygon) as returned by the API.
class YatmoIsochrone {
  const YatmoIsochrone({required this.label, required this.geometry});
  final String label;
  final Map<String, dynamic> geometry;
}

// ---- /Geolocation/GetClose (Photon) -----------------------------------------------------------

class YatmoPlace {
  const YatmoPlace({
    required this.latitude,
    required this.longitude,
    this.name,
    this.street,
    this.houseNumber,
    this.postcode,
    this.city,
    this.country,
    this.countryCode,
    this.type,
  });

  static YatmoPlace? fromFeature(Map<String, dynamic> f) {
    final coordinates = (f['geometry'] as Map?)?['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final p = Map<String, dynamic>.from((f['properties'] as Map?) ?? const {});
    return YatmoPlace(
      name: p['name'] as String?,
      street: p['street'] as String?,
      houseNumber: p['housenumber']?.toString(),
      postcode: p['postcode']?.toString(),
      city: p['city'] as String?,
      country: p['country'] as String?,
      countryCode: p['countrycode'] as String?,
      type: p['type'] as String?,
      latitude: (coordinates[1] as num).toDouble(),
      longitude: (coordinates[0] as num).toDouble(),
    );
  }

  final String? name;
  final String? street;
  final String? houseNumber;
  final String? postcode;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? type;
  final double latitude;
  final double longitude;

  /// "Rue Neuve, 1000 Brussels" style single line.
  String get label {
    final cityLine = [postcode, city].whereType<String>().join(' ');
    return [name ?? street, cityLine].whereType<String>().where((s) => s.isNotEmpty).join(', ');
  }
}

// ---- /SimplifiedCategories --------------------------------------------------------------------

/// Category ids grouped by family (Education, Transports, Motorways, Shopping, Tourism...).
class YatmoCategoryGroup {
  const YatmoCategoryGroup({required this.name, required this.poiTypeIds});
  final String name;
  final List<int> poiTypeIds;
}

// ---- helpers ----------------------------------------------------------------------------------

List<T> _list<T>(dynamic array, T Function(Map<String, dynamic>) map) {
  if (array is! List) return const [];
  return array.whereType<Map>().map((e) => map(Map<String, dynamic>.from(e))).toList();
}

Map<String, String> _stringMap(dynamic o) {
  if (o is! Map) return const {};
  return o.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
}
