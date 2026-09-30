import 'dart:convert';

import 'package:http/http.dart' as http;

import 'configuration.dart';
import 'models.dart';

/// Typed client for the Yatmo REST API. Every call sends the licence and the mobile headers
/// (LicenseKey, X-Yatmo-App-Id, X-Yatmo-Platform, X-Yatmo-SDK) and throws a [YatmoException] on failure.
class YatmoClient {
  YatmoClient(this.configuration, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final YatmoConfiguration configuration;
  final http.Client _http;

  /// GET /Summary: nearby places by category with travel times, closest cities, reverse-geocoded place.
  Future<YatmoSummary> summary({required double latitude, required double longitude}) async =>
      YatmoSummary.fromJson(await _getObject('Summary', _position(latitude, longitude)));

  /// GET /Summary/text: generated paragraphs, resolved to the configured language.
  Future<YatmoSummaryText> summaryText({required double latitude, required double longitude}) async =>
      YatmoSummaryText.fromJson(await _getObject('Summary/text', _position(latitude, longitude)), configuration.language);

  /// GET /Scores: one 0 to 10 score per category.
  Future<YatmoScores> scores({required double latitude, required double longitude}) async =>
      YatmoScores.fromJson(await _getObject('Scores', _position(latitude, longitude)));

  /// GET /Enrichment: nearest place of each category with distances and times for four travel modes.
  Future<YatmoEnrichment> enrichment({required double latitude, required double longitude}) async =>
      YatmoEnrichment.fromJson(await _getObject('Enrichment', _position(latitude, longitude)));

  /// GET /Points inside a bounding box. Only ask from zoom 13 upwards and debounce camera events.
  Future<List<YatmoPoi>> points({required YatmoLatLng southWest, required YatmoLatLng northEast, List<int>? poiTypeIds}) async {
    final query = <String, String>{
      'bound1': '${_fmt(southWest.latitude)},${_fmt(southWest.longitude)}',
      'bound2': '${_fmt(northEast.latitude)},${_fmt(northEast.longitude)}',
      'groupSamePositions': 'true',
      'caringForBigResponse': 'true',
    };
    if (poiTypeIds != null && poiTypeIds.isNotEmpty) query['poiTypesIds'] = poiTypeIds.join(',');
    final array = await _getArray('Points', query);
    return array.whereType<Map>().map((e) => YatmoPoi.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// GET /Isochrone/GetMultipleTimes: the 5, 10 and 20 minute areas, smallest first.
  Future<List<YatmoIsochrone>> isochrones({required TravelMode mode, required double latitude, required double longitude}) async {
    final array = await _getArray('Isochrone/GetMultipleTimes', {..._position(latitude, longitude), 'travelMode': mode.apiName});
    return array
        .whereType<Map>()
        .map((e) => YatmoIsochrone(label: (e['label'] ?? '').toString(), geometry: Map<String, dynamic>.from(e['iso'] as Map)))
        .toList();
  }

  /// GET /Geolocation/GetClose: address autocomplete near a position, inside the configured country.
  Future<List<YatmoPlace>> geocode({required String query, required double latitude, required double longitude}) async {
    final root = await _getObject('Geolocation/GetClose', {..._position(latitude, longitude), 'address': query});
    final features = root['features'];
    if (features is! List) return const [];
    return features.whereType<Map>().map((f) => YatmoPlace.fromFeature(Map<String, dynamic>.from(f))).whereType<YatmoPlace>().toList();
  }

  /// GET /SimplifiedCategories: category ids grouped by family, the values accepted by `poiTypeIds`.
  Future<List<YatmoCategoryGroup>> simplifiedCategories() async {
    final root = await _getObject('SimplifiedCategories', const {});
    final groups = root.entries
        .map((e) => YatmoCategoryGroup(name: e.key, poiTypeIds: (e.value as List? ?? const []).map((v) => (v as num).toInt()).toList()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return groups;
  }

  /// URL of the iframe plugin, for a WebView (webview_flutter or any other).
  String pluginUrl({
    required double latitude,
    required double longitude,
    String mode = 'overlay',
    int zoom = 15,
    String? accentColor,
    String? marker,
    YatmoMapStyle? mapStyle,
    Map<String, String> extraParameters = const {},
  }) {
    final params = <String, String>{
      'licenseKey': configuration.licenseKey,
      'country': configuration.countryCode,
      'language': configuration.languageCode,
      'latitude': _fmt(latitude),
      'longitude': _fmt(longitude),
      'mode': mode,
      'zoom': zoom.toString(),
      if (accentColor != null) 'accentColor': accentColor,
      if (marker != null) 'marker': marker,
      if (mapStyle != null) 'mapStyle': mapStyle.id.toString(),
      ...extraParameters,
    };
    return Uri.https('map.yatmo.com', '/plugin.html', params).toString();
  }

  /// Headers sent with every request, for callers that need an endpoint not wrapped above.
  Map<String, String> headers() => {
        'LicenseKey': configuration.licenseKey,
        'X-Yatmo-App-Id': configuration.appId,
        'X-Yatmo-Platform': configuration.platform,
        'X-Yatmo-SDK': 'yatmo-flutter/$yatmoSdkVersion',
        'Accept': 'application/json',
      };

  /// Full URL of an endpoint with the language appended.
  Uri url(String path, Map<String, String> query) =>
      Uri.parse(configuration.resolvedBaseUrl + path).replace(queryParameters: {...query, 'language': configuration.languageCode});

  Future<Map<String, dynamic>> _getObject(String path, Map<String, String> query) async {
    final decoded = jsonDecode(await _getText(path, query));
    if (decoded is! Map) throw YatmoException(200, 'Yatmo API: unreadable response');
    return Map<String, dynamic>.from(decoded);
  }

  Future<List<dynamic>> _getArray(String path, Map<String, String> query) async {
    final decoded = jsonDecode(await _getText(path, query));
    if (decoded is! List) throw YatmoException(200, 'Yatmo API: unreadable response');
    return decoded;
  }

  Future<String> _getText(String path, Map<String, String> query) async {
    http.Response response;
    try {
      response = await _http.get(url(path, query), headers: headers()).timeout(configuration.timeout);
    } catch (e) {
      throw YatmoException(0, e.toString(), e);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['Error'] is String) message = decoded['Error'] as String;
      } catch (_) {}
      throw YatmoException(response.statusCode, 'Yatmo API ${response.statusCode}: $message');
    }
    return response.body;
  }

  Map<String, String> _position(double latitude, double longitude) => {'latitude': _fmt(latitude), 'longitude': _fmt(longitude)};

  static String _fmt(double value) => value.toStringAsFixed(7);
}
