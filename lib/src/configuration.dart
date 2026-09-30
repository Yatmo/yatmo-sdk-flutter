/// Version sent in the X-Yatmo-SDK header. Keep in sync with pubspec.yaml.
const String yatmoSdkVersion = '1.0.0';

/// Countries served by the Yatmo API. The API subdomain is the lower-case name: `https://be.yatmo.com/`.
enum Country { be, fr, nl, lu, ch, de, it, es, pt, ie, uk, at, ca, gr, ma, au, hr, mt, si, rs, cy, ba, me, bg, al }

/// Languages accepted by the `language` parameter of the API.
enum Language { en, fr, nl, de, it, es, pt, ca, zh, hi, ar, ru, ja, el, hr, mt, sl, sr, tr, bs, sq, bg, cnr }

/// The seven map styles of the web plugin. [id] is the style id used by the plugin.
enum YatmoMapStyle {
  liberty(1, 'osm_liberty'),
  basic(2, 'osm_basic'),
  bright(3, 'osm_bright'),
  threeD(4, 'osm_3d'),
  positron(5, 'osm_positron'),
  dark(6, 'osm_dark'),
  libertyStonehedge(7, 'osm_liberty_stonehedge');

  const YatmoMapStyle(this.id, this._fileName);

  final int id;
  final String _fileName;

  String get url => 'https://map.yatmo.com/$_fileName.json';
}

/// Travel modes of the routing endpoints. [apiName] is the API spelling, [summaryCode] the code inside Summary payloads.
enum TravelMode {
  driving('Driving', 1),
  walking('Walking', 2),
  bicycling('Bicycling', 3),
  transit('Transit', 4);

  const TravelMode(this.apiName, this.summaryCode);

  final String apiName;
  final int summaryCode;

  static TravelMode? fromSummaryCode(int code) {
    for (final mode in values) {
      if (mode.summaryCode == code) return mode;
    }
    return null;
  }
}

/// Everything the SDK needs to talk to the API. One instance per app.
class YatmoConfiguration {
  const YatmoConfiguration({
    required this.licenseKey,
    required this.country,
    required this.language,
    required this.appId,
    this.apiBaseUrl,
    this.timeout = const Duration(seconds: 15),
    this.platform = 'flutter',
  });

  /// Your frontend key (the one used by the web plugins). Never the backend key.
  final String licenseKey;
  final Country country;
  final Language language;

  /// The iOS bundle identifier or the Android application id of the running app, sent in X-Yatmo-App-Id.
  /// `package_info_plus` returns it as `packageName`.
  final String appId;

  /// Override the API host, for staging environments. Defaults to `https://{country}.yatmo.com/`.
  final String? apiBaseUrl;
  final Duration timeout;

  /// Sent in X-Yatmo-Platform, informative only.
  final String platform;

  String get resolvedBaseUrl => apiBaseUrl ?? 'https://${country.name}.yatmo.com/';
  String get countryCode => country.name.toUpperCase();
  String get languageCode => language.name.toUpperCase();
}

/// Thrown by [YatmoClient]. 401 = key missing or unknown, 403 = app id or country not allowed, 429 = quota, 0 = network.
class YatmoException implements Exception {
  YatmoException(this.statusCode, this.message, [this.cause]);

  final int statusCode;
  final String message;
  final Object? cause;

  @override
  String toString() => 'YatmoException($statusCode): $message';
}
