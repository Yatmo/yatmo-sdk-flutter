# yatmo_sdk

[![CI](https://github.com/yatmo/yatmo-sdk-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/yatmo/yatmo-sdk-flutter/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/yatmo_sdk.svg)](https://pub.dev/packages/yatmo_sdk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Neighbourhood intelligence for real-estate apps: the [Yatmo](https://yatmo.com) map with the points of interest, travel times and neighbourhood summaries your listing pages need, in Flutter. Built on [`maplibre_gl`](https://pub.dev/packages/maplibre_gl), no Google Maps key required.

<p align="center">
  <img src="https://raw.githubusercontent.com/yatmo/yatmo-sdk-flutter/main/doc/screenshot-ios.png" width="240" alt="Yatmo map in the listing screen of a demo iOS app">
  <img src="https://raw.githubusercontent.com/yatmo/yatmo-sdk-flutter/main/doc/screenshot-android.png" width="240" alt="Yatmo map in the listing screen of a demo Android app">
</p>

## Requirements

- Flutter 3.35+, `maplibre_gl` 0.27+ (its Android build needs a JDK 21)
- A Yatmo licence: the **frontend key** and your iOS bundle id / Android applicationId registered as [app ids](https://documentation.yatmo.com/mobile/app-ids)

## Installation

```yaml
dependencies:
  yatmo_sdk: ^1.0.0
  package_info_plus: ^8.0.0   # optional, to read the app id at runtime
```

## Quick start

```dart
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yatmo_sdk/yatmo_sdk.dart';

final info = await PackageInfo.fromPlatform();
final yatmo = YatmoClient(YatmoConfiguration(
  licenseKey: 'YOUR_FRONTEND_KEY',
  country: Country.be,
  language: Language.fr,
  appId: info.packageName, // bundle id on iOS, applicationId on Android
));

YatmoMapView(
  client: yatmo,
  property: const LatLng(50.8520525, 4.3442926),
  zoom: 15,
  isochrones: TravelMode.walking,       // 5 / 10 / 20 minute areas, camera fitted like the web plugin
  onPoiSelected: (poi) => debugPrint('${poi.name} (${poi.type})'),
);

final summary = await yatmo.summary(latitude: 50.8520525, longitude: 4.3442926);
final enrichment = await yatmo.enrichment(latitude: 50.8520525, longitude: 4.3442926);
```

The app id is sent with every request. Register it on your licence, otherwise the API answers 403.

## What is inside

| Type | Role |
|---|---|
| `YatmoClient`, `YatmoConfiguration` | Typed client on `package:http`: `summary`, `summaryText`, `scores`, `enrichment`, `points`, `isochrones`, `geocode`, `simplifiedCategories`, `pluginUrl` |
| `YatmoMapView` | `MapLibreMap` with a Yatmo style, property pin, POI symbols following the camera, isochrones, tap callback, raw controller through `onMapCreated` |

The package does not depend on `webview_flutter`: use `client.pluginUrl(...)` with the WebView of your choice to show the Yatmo iframe plugin.

Full guide: https://documentation.yatmo.com/mobile/flutter

## Example app

`example/` shows the map and exercises every client call:

```bash
cd example
flutter run --dart-define=YATMO_LICENSE_KEY=YOUR_FRONTEND_KEY
```

Emulator note: with the software renderer (`-gpu swiftshader_indirect`) the Android emulator draws no map labels or icons in `maplibre_gl`; use `-gpu host` or a real device.

## Licence

The SDK is released under the [MIT licence](LICENSE). Using the Yatmo API requires a licence key: https://yatmo.com
