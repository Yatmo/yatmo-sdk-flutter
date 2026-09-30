import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show MapLibreMap, CameraPosition;
import 'package:yatmo_sdk/yatmo_sdk.dart';

// Functional test of the Yatmo Flutter SDK: a map on a Brussels listing plus every client call,
// each result printed (tag YatmoTest) and shown on screen.
const licenseKey = String.fromEnvironment('YATMO_LICENSE_KEY');
const lat = 50.8520525;
const lng = 4.3442926;

const plain = bool.fromEnvironment('PLAIN');

void main() {
  MapLibreMap.useHybridComposition = const bool.fromEnvironment('HYBRID', defaultValue: false);
  runApp(MaterialApp(home: plain ? const PlainPage() : const TestPage()));
}

/// Diagnostic: a bare MapLibreMap on the Yatmo style, no Yatmo layer at all.
class PlainPage extends StatelessWidget {
  const PlainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: const String.fromEnvironment('STYLE', defaultValue: 'https://map.yatmo.com/osm_liberty.json'),
        initialCameraPosition: const CameraPosition(target: LatLng(lat, lng), zoom: 15),
        onStyleLoadedCallback: () => debugPrint('YatmoTest: plain style loaded'),
      ),
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late final YatmoClient client;
  final lines = <String>[];

  @override
  void initState() {
    super.initState();
    client = YatmoClient(const YatmoConfiguration(
      licenseKey: licenseKey,
      country: Country.be,
      language: Language.fr,
      appId: 'com.yatmo.test.android',
    ));
    log('appId=com.yatmo.test.android key=${licenseKey.substring(0, 6)}...');
    runCalls();
  }

  Future<void> runCalls() async {
    await step('summary', () async {
      final s = await client.summary(latitude: lat, longitude: lng);
      final first = s.categories.first;
      final place = first.subCategories.first.places.first;
      return '${s.categories.length} categories, ${s.closeCities.length} cities, street=${s.placeInformation?.streetName}, first=${first.label}/${place.name} walk=${place.travel(TravelMode.walking)?.travelTimeShortLabel}';
    });
    await step('summaryText', () async {
      final t = await client.summaryText(latitude: lat, longitude: lng);
      return '${t.paragraphs.length} paragraphs, ${t.text.length} chars: ${t.text.substring(0, 80)}';
    });
    await step('scores', () async => (await client.scores(latitude: lat, longitude: lng)).scores.map((s) => '${s.key}=${s.value}').join(', '));
    await step('enrichment', () async {
      final e = await client.enrichment(latitude: lat, longitude: lng);
      return '${e.categories.length} categories, ${e.categories.first.key} -> ${e.categories.first.nearest?.name} ${e.categories.first.nearest?.walking?.durationMinutes} min';
    });
    await step('geocode', () async {
      final p = await client.geocode(query: 'Rue Neuve', latitude: lat, longitude: lng);
      return '${p.length} places, first=${p.first.label}';
    });
    await step('simplifiedCategories', () async => (await client.simplifiedCategories()).map((g) => '${g.name}:${g.poiTypeIds.length}').join(', '));
    await step('points', () async {
      final p = await client.points(southWest: const YatmoLatLng(50.848, 4.338), northEast: const YatmoLatLng(50.856, 4.350));
      return '${p.length} pois, first=${p.first.name} icon=${p.first.iconIds}';
    });
    await step('isochrones', () async => (await client.isochrones(mode: TravelMode.walking, latitude: lat, longitude: lng)).map((i) => '${i.label}:${i.geometry['type']}').join(', '));
    await step('pluginUrl', () async => client.pluginUrl(latitude: lat, longitude: lng));
    log('ALL CLIENT CALLS DONE');
  }

  Future<void> step(String name, Future<String> Function() block) async {
    try {
      log('OK $name: ${await block()}');
    } catch (e) {
      log('FAIL $name: $e');
    }
  }

  void log(String line) {
    debugPrint('YatmoTest: $line');
    if (mounted) setState(() => lines.add(line));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 520,
              child: YatmoMapView(
                client: client,
                property: const LatLng(lat, lng),
                zoom: 15,
                isochrones: TravelMode.walking,
                onError: (e) => log('MAP ERROR: $e'),
                onPoiSelected: (poi) => log('POI TAP: ${poi.name} (${poi.type})'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [for (final l in lines) Text(l, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
