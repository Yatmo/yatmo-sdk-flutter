import 'dart:async';
import 'dart:convert';
import 'dart:math' show Point;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import 'cdn.dart';
import 'client.dart';
import 'configuration.dart';
import 'models.dart';

/// A MapLibre map with the Yatmo style, the property pin, POI symbols that follow the camera (debounced,
/// from [minZoomForPois]) and optional isochrones. The widget draws no popup: handle [onPoiSelected] with your own UI.
class YatmoMapView extends StatefulWidget {
  const YatmoMapView({
    super.key,
    required this.client,
    required this.property,
    this.zoom = 15,
    this.mapStyle = YatmoMapStyle.liberty,
    this.poiTypeIds,
    this.poiIconSize = 24,
    this.isochrones,
    this.minZoomForPois = 13,
    this.isochroneColors = const ['#70ADF0', '#F5A623', '#EF427F'],
    this.isochroneOpacities = const [0.5, 0.4, 0.3],
    this.onPoiSelected,
    this.onError,
    this.onMapCreated,
    this.fitIsochrones = true,
    this.isochronePadding = 40,
  });

  final YatmoClient client;

  /// Pin position and initial centre.
  final LatLng property;
  final double zoom;
  final YatmoMapStyle mapStyle;

  /// Category ids from `client.simplifiedCategories()`. Null = all.
  final List<int>? poiTypeIds;

  /// 24 or 32.
  final int poiIconSize;

  /// Draws the 5 / 10 / 20 minute areas when set.
  final TravelMode? isochrones;

  /// No POI request below this zoom.
  final double minZoomForPois;

  /// Fill colours (hex) and opacities from the smallest area to the largest (default = the web plugin palette:
  /// 5 min blue, 10 min orange, 20 min pink). The outline takes the fill colour, opaque.
  final List<String> isochroneColors;
  final List<double> isochroneOpacities;
  final void Function(YatmoPoi poi)? onPoiSelected;
  final void Function(Object error)? onError;

  /// Access to the raw controller, to add your own sources and layers once the style is loaded.
  final void Function(MapLibreMapController controller)? onMapCreated;

  /// Like the web plugin: once drawn, the camera fits the largest area; setting [isochrones] back to null restores
  /// the previous camera.
  final bool fitIsochrones;

  /// Padding around the isochrones when the camera fits them, in logical pixels.
  final double isochronePadding;

  @override
  State<YatmoMapView> createState() => _YatmoMapViewState();
}

class _YatmoMapViewState extends State<YatmoMapView> {
  static const _sourceIsochrones = 'yatmo-isochrones';
  static const _sourcePois = 'yatmo-pois';
  static const _sourceProperty = 'yatmo-property';
  static const _layerPois = 'yatmo-pois';

  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  Timer? _debounce;
  int _requestId = 0;
  final Map<String, YatmoPoi> _pois = {};
  final Set<String> _loadedIcons = {};
  CameraPosition? _cameraBeforeIsochrones;

  @override
  void didUpdateWidget(covariant YatmoMapView old) {
    super.didUpdateWidget(old);
    if (old.property != widget.property) {
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(widget.property, widget.zoom));
      _renderProperty();
      _cameraBeforeIsochrones = null; // the camera to restore is the one centred on the new property
      _loadIsochrones();
    } else if (old.isochrones != widget.isochrones) {
      _loadIsochrones();
    }
    if (old.poiTypeIds != widget.poiTypeIds) _scheduleLoadPois(Duration.zero);
    if (old.mapStyle != widget.mapStyle) {
      _styleLoaded = false;
      _loadedIcons.clear();
      _pois.clear();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      key: ValueKey(widget.mapStyle),
      styleString: widget.mapStyle.url,
      initialCameraPosition: CameraPosition(target: widget.property, zoom: widget.zoom),
      attributionButtonPosition: AttributionButtonPosition.bottomRight,
      myLocationEnabled: false,
      onMapCreated: (controller) {
        _controller = controller;
        controller.onFeatureTapped.add(_onFeatureTapped);
        widget.onMapCreated?.call(controller);
      },
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraIdle: () => _scheduleLoadPois(const Duration(milliseconds: 300)),
    );
  }

  Future<void> _onStyleLoaded() async {
    final c = _controller;
    if (c == null) return;
    _styleLoaded = true;
    final empty = {'type': 'FeatureCollection', 'features': <dynamic>[]};
    await c.addSource(_sourceIsochrones, GeojsonSourceProperties(data: empty));
    await c.addSource(_sourcePois, GeojsonSourceProperties(data: empty));
    await c.addSource(_sourceProperty, GeojsonSourceProperties(data: empty));
    final colors = widget.isochroneColors;
    final opacities = widget.isochroneOpacities;
    await c.addLayer(
      _sourceIsochrones,
      'yatmo-isochrones-fill',
      FillLayerProperties(
        fillColor: ['step', ['get', 'rank'], colors[0], 1, colors.length > 1 ? colors[1] : colors[0], 2, colors.length > 2 ? colors[2] : colors[0]],
        fillOpacity: ['step', ['get', 'rank'], opacities[0], 1, opacities.length > 1 ? opacities[1] : opacities[0], 2, opacities.length > 2 ? opacities[2] : opacities[0]],
      ),
    );
    await c.addLayer(
      _sourceIsochrones,
      'yatmo-isochrones-line',
      LineLayerProperties(
        lineColor: ['step', ['get', 'rank'], colors[0], 1, colors.length > 1 ? colors[1] : colors[0], 2, colors.length > 2 ? colors[2] : colors[0]],
        lineWidth: 3,
      ),
    );
    await c.addLayer(
      _sourcePois,
      _layerPois,
      const SymbolLayerProperties(iconImage: ['get', 'icon'], iconSize: 0.5, iconAllowOverlap: true, iconIgnorePlacement: true),
    );
    await c.addLayer(
      _sourceProperty,
      'yatmo-property',
      const CircleLayerProperties(circleRadius: 9, circleColor: '#428BFF', circleStrokeColor: '#FFFFFF', circleStrokeWidth: 3),
    );
    await _renderProperty();
    _scheduleLoadPois(Duration.zero);
    _loadIsochrones();
  }

  Future<void> _renderProperty() async {
    final c = _controller;
    if (c == null || !_styleLoaded) return;
    await c.setGeoJsonSource(_sourceProperty, {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {'type': 'Point', 'coordinates': [widget.property.longitude, widget.property.latitude]},
        }
      ],
    });
  }

  void _scheduleLoadPois(Duration delay) {
    _debounce?.cancel();
    _debounce = Timer(delay, _loadPois);
  }

  Future<void> _loadPois() async {
    final c = _controller;
    if (c == null || !_styleLoaded || !mounted) return;
    final zoom = c.cameraPosition?.zoom ?? widget.zoom;
    if (zoom < widget.minZoomForPois) {
      _pois.clear();
      await c.setGeoJsonSource(_sourcePois, {'type': 'FeatureCollection', 'features': <dynamic>[]});
      return;
    }
    final id = ++_requestId;
    try {
      final region = await c.getVisibleRegion();
      final pois = await widget.client.points(
        southWest: YatmoLatLng(region.southwest.latitude, region.southwest.longitude),
        northEast: YatmoLatLng(region.northeast.latitude, region.northeast.longitude),
        poiTypeIds: widget.poiTypeIds,
      );
      if (id != _requestId || !mounted) return;
      await _ensureIcons(c, pois);
      if (id != _requestId || !mounted) return;
      _pois
        ..clear()
        ..addEntries(pois.map((p) => MapEntry(p.id, p)));
      await c.setGeoJsonSource(_sourcePois, {
        'type': 'FeatureCollection',
        'features': [
          for (final p in pois)
            if (p.iconIds.isNotEmpty)
              {
                'type': 'Feature',
                'id': p.id,
                'properties': {'id': p.id, 'icon': 'yatmo-icon-${p.iconIds.first}'},
                'geometry': {'type': 'Point', 'coordinates': [p.longitude, p.latitude]},
              }
        ],
      });
    } catch (e) {
      widget.onError?.call(e);
    }
  }

  /// Downloads the CDN icons not yet registered on the style.
  Future<void> _ensureIcons(MapLibreMapController c, List<YatmoPoi> pois) async {
    final country = widget.client.configuration.country;
    final size = widget.poiIconSize >= 32 ? 32 : 24;
    final missing = pois.map((p) => p.iconIds.isEmpty ? null : p.iconIds.first).whereType<String>().toSet().where(_loadedIcons.add);
    for (final iconId in missing) {
      try {
        final response = await http.get(Uri.parse(YatmoCdn.iconUrl(country, iconId, size: size)));
        if (response.statusCode == 200) {
          await c.addImage('yatmo-icon-$iconId', Uint8List.fromList(response.bodyBytes));
        }
      } catch (_) {
        _loadedIcons.remove(iconId); // retry on the next load
      }
    }
  }

  Future<void> _loadIsochrones() async {
    final c = _controller;
    final mode = widget.isochrones;
    if (c == null || !_styleLoaded) return;
    if (mode == null) {
      await c.setGeoJsonSource(_sourceIsochrones, {'type': 'FeatureCollection', 'features': <dynamic>[]});
      final before = _cameraBeforeIsochrones;
      if (before != null) {
        _cameraBeforeIsochrones = null;
        await c.animateCamera(CameraUpdate.newCameraPosition(before));
      }
      return;
    }
    try {
      final areas = await widget.client.isochrones(mode: mode, latitude: widget.property.latitude, longitude: widget.property.longitude);
      if (!mounted || widget.isochrones != mode) return;
      final reversed = areas.reversed.toList();
      await c.setGeoJsonSource(_sourceIsochrones, {
        'type': 'FeatureCollection',
        'features': [
          for (var i = 0; i < reversed.length; i++)
            {
              'type': 'Feature',
              'properties': {'rank': reversed.length - 1 - i, 'label': reversed[i].label},
              'geometry': reversed[i].geometry,
            }
        ],
      });
      final bounds = areas.isEmpty ? null : _boundsOf(areas.last.geometry);
      if (widget.fitIsochrones && bounds != null) {
        _cameraBeforeIsochrones ??= c.cameraPosition;
        final p = widget.isochronePadding;
        await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, left: p, top: p, right: p, bottom: p));
      }
    } catch (e) {
      widget.onError?.call(e);
    }
  }

  /// Bounding box of a GeoJSON Polygon or MultiPolygon, whatever its nesting depth.
  static LatLngBounds? _boundsOf(Map<String, dynamic> geometry) {
    var west = 180.0, south = 90.0, east = -180.0, north = -90.0, count = 0;
    void walk(dynamic node) {
      if (node is! List) return;
      if (node.length >= 2 && node[0] is num && node[1] is num) {
        final lng = (node[0] as num).toDouble(), lat = (node[1] as num).toDouble();
        if (lng < west) west = lng;
        if (lng > east) east = lng;
        if (lat < south) south = lat;
        if (lat > north) north = lat;
        count++;
      } else {
        node.forEach(walk);
      }
    }
    walk(geometry['coordinates']);
    return count >= 2 ? LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)) : null;
  }

  // maplibre_gl 0.27 signature. Only POI features carry an id (isochrones and the property circle have none).
  void _onFeatureTapped(Point<double> point, LatLng coordinates, String featureId, String layerId, Annotation? annotation) {
    if (layerId != _layerPois) return;
    final poi = _pois[featureId];
    if (poi != null) widget.onPoiSelected?.call(poi);
  }
}

/// Debug helper: the GeoJSON currently rendered for the isochrones, as text.
String encodeGeoJson(Map<String, dynamic> geoJson) => jsonEncode(geoJson);
