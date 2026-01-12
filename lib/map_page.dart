import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'data/db/app_database.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.onTapFeature});
  final void Function(String id) onTapFeature;

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  late final WebViewController _controller;
  bool _loaded = false;

  /// ID du polygone sélectionné
  String? _selectedPolygonId;

  // ================= INIT =================

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'MapChannel',
        onMessageReceived: (msg) async {
          try {
            final data = jsonDecode(msg.message);

            if (data['type'] == 'tap') {
              final id = data['id'].toString();
              setState(() => _selectedPolygonId = id);
              widget.onTapFeature(id);
              return;
            }

            if (data['type'] == 'created') {
              final feature =
                  (data['feature'] as Map).cast<String, dynamic>();
              await _openCreateForm(feature);
              return;
            }

            if (data['type'] == 'edited') {
              final id = data['id'].toString();
              final feature =
                  (data['feature'] as Map).cast<String, dynamic>();

              await AppDatabase.instance.updateGeometry(
                id: id,
                geojsonFeature: feature,
              );

              setState(() => _selectedPolygonId = null);
              await _pushGeoJsonToMap();
            }
          } catch (e) {
            debugPrint("MapChannel error: $e");
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            setState(() => _loaded = true);
            await _pushGeoJsonToMap();
          },
        ),
      )
      ..loadFlutterAsset('assets/map/map.html');

    AppDatabase.instance.refreshTick.addListener(() async {
      if (_loaded) await _pushGeoJsonToMap();
    });
  }

  // ================= DATA → MAP =================

  Future<void> _pushGeoJsonToMap() async {
    final rows = await AppDatabase.instance.getConstructions();

    final features = rows
        .map<Map<String, dynamic>?>((r) {
          final geojsonStr = (r['geometrie_geojson'] ?? '').toString();
          if (geojsonStr.isEmpty) return null;

          final decoded = jsonDecode(geojsonStr) as Map<String, dynamic>;
          decoded['properties'] ??= {};

          decoded['properties']['id'] = r['id'].toString();
          decoded['properties']['type_construction'] =
              (r['type_construction'] ?? '').toString();
          decoded['properties']['adresse'] =
              (r['adresse'] ?? '').toString();
          decoded['properties']['contact'] =
              (r['contact'] ?? '').toString();

          return decoded;
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    final fc = {
      "type": "FeatureCollection",
      "features": features,
    };

    await _controller.runJavaScript("setData(${jsonEncode(fc)});");
  }

  // ================= LISTE → MAP =================

  Future<void> focusOn(String id) async {
    if (!_loaded) return;
    await _controller.runJavaScript("focusOn(${jsonEncode(id)});");
  }

  // ================= RELEVÉ MENU =================

  void _openReleveMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return _ElegantSheet(
          title: "Relevé – Actions",
          child: Column(
            children: _selectedPolygonId == null
                ? [
                    ListTile(
                      leading: const Icon(Icons.add_location_alt),
                      title: const Text("Dessiner une construction"),
                      onTap: () {
                        Navigator.pop(context);
                        _startDraw();
                      },
                    ),
                  ]
                : [
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text("Modifier la forme"),
                      onTap: () {
                        Navigator.pop(context);
                        _enableGeometryEdit();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.check_circle,
                          color: Colors.green),
                      title: const Text("Valider la modification"),
                      onTap: () {
                        Navigator.pop(context);
                        _saveGeometryEdit();
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.delete, color: Colors.red),
                      title: const Text("Supprimer"),
                      onTap: () async {
                        Navigator.pop(context);
                        final ok =
                            await _confirmDelete(_selectedPolygonId!);
                        if (ok == true) {
                          await _deletePolygon(_selectedPolygonId!);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text("Informations"),
                      onTap: () {
                        Navigator.pop(context);
                        _openDetailsById(_selectedPolygonId!);
                      },
                    ),
                  ],
          ),
        );
      },
    );
  }

  // ================= ACTIONS =================

  Future<void> _startDraw() async {
    setState(() => _selectedPolygonId = null);
    await _controller.runJavaScript("startDraw();");
  }

  Future<void> _enableGeometryEdit() async {
    await _controller.runJavaScript(
      "enableEdit(${jsonEncode(_selectedPolygonId)});",
    );
  }

  Future<void> _saveGeometryEdit() async {
    await _controller.runJavaScript(
      "saveEdit(${jsonEncode(_selectedPolygonId)});",
    );
  }

  Future<void> _deletePolygon(String id) async {
    await _controller.runJavaScript("deletePolygon(${jsonEncode(id)});");
    await AppDatabase.instance.deleteConstruction(id);
    setState(() => _selectedPolygonId = null);
  }

  // ================= CREATE =================

  Future<void> _openCreateForm(Map<String, dynamic> feature) async {
    final adresseCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    String type = "residentiel";

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return _ElegantSheet(
          title: "Nouvelle construction",
          child: Column(
            children: [
              TextField(
                controller: adresseCtrl,
                decoration: const InputDecoration(labelText: "Adresse"),
              ),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: "Contact"),
              ),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(
                      value: "residentiel", child: Text("Résidentiel")),
                  DropdownMenuItem(
                      value: "commercial", child: Text("Commercial")),
                ],
                onChanged: (v) => type = v ?? type,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Enregistrer"),
              ),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      feature['properties'] ??= {};
      feature['properties']['id'] = id;

      await AppDatabase.instance.insertConstruction(
        id: id,
        adresse: adresseCtrl.text.trim(),
        contact: contactCtrl.text.trim(),
        typeConstruction: type,
        geojsonFeature: feature,
      );
    }
  }

  // ================= DETAILS =================

  Future<void> _openDetailsById(String id) async {
    final row = await AppDatabase.instance.getConstructionById(id);
    if (row == null) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return _ElegantSheet(
          title: "Construction $id",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Adresse : ${row['adresse'] ?? '-'}"),
              Text("Contact : ${row['contact'] ?? '-'}"),
              Text("Type : ${row['type_construction'] ?? '-'}"),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDelete(String id) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: Text("Confirmer la suppression de $id"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler")),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Supprimer")),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_loaded) const Center(child: CircularProgressIndicator()),
        Positioned(
          right: 14,
          bottom: 14,
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.edit_location_alt),
            label: const Text("Relevé"),
            onPressed: !_loaded ? null : _openReleveMenu,
          ),
        ),
      ],
    );
  }
}

// ================= UI HELPER =================

class _ElegantSheet extends StatelessWidget {
  const _ElegantSheet({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
