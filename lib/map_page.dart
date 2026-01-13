import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'data/db/app_database.dart';
import 'data/models/user.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.onTapFeature, required this.user});
  final void Function(String id) onTapFeature;
  final AppUser user;

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  late final WebViewController _controller;
  bool _loaded = false;

  String? _selectedPolygonId;

  // ================= INIT =================

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'MapChannel',
        onMessageReceived: _onMapMessage,
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

  // ================= MAP → FLUTTER =================

  Future<void> _onMapMessage(JavaScriptMessage msg) async {
    try {
      final data = jsonDecode(msg.message);

      if (data['type'] == 'tap') {
        final id = data['id'].toString();
        setState(() => _selectedPolygonId = id);
        widget.onTapFeature(id);
      }

      if (data['type'] == 'created') {
        final feature = (data['feature'] as Map).cast<String, dynamic>();
        await _openCreateForm(feature);
      }

      if (data['type'] == 'edited') {
        final id = data['id'].toString();
        final feature = (data['feature'] as Map).cast<String, dynamic>();

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
  }

  // ================= DATA → MAP =================

  Future<void> _pushGeoJsonToMap() async {
    final rows =
        await AppDatabase.instance.getConstructionsForUser(widget.user);

    final features = rows
        .map<Map<String, dynamic>?>((r) {
          final geo = (r['geometrie_geojson'] ?? '').toString();
          if (geo.isEmpty) return null;

          final f = jsonDecode(geo) as Map<String, dynamic>;
          f['properties'] ??= {};
          f['properties']['id'] = r['id'].toString();
          f['properties']['type_construction'] =
              (r['type_construction'] ?? '').toString();
          f['properties']['adresse'] = (r['adresse'] ?? '').toString();
          f['properties']['contact'] = (r['contact'] ?? '').toString();
          f['properties']['created_by'] =
              (r['created_by'] ?? '').toString();

          return f;
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    final fc = {"type": "FeatureCollection", "features": features};
    await _controller.runJavaScript("setData(${jsonEncode(fc)});");
  }

  // ================= ✅ FOCUS (POUR main.dart) =================

  Future<void> focusOn(String id) async {
    if (!_loaded) return;
    await _controller.runJavaScript("focusOn(${jsonEncode(id)});");
    setState(() => _selectedPolygonId = id);
  }

  // ================= RELEVÉ =================

  void _openReleveMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _ElegantSheet(
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
                  _actionTile(
                    Icons.edit,
                    "Modifier la forme",
                    _enableGeometryEdit,
                  ),
                  _actionTile(
                    Icons.check_circle,
                    "Valider la modification",
                    _saveGeometryEdit,
                    color: Colors.green,
                  ),
                  _actionTile(
                    Icons.delete,
                    "Supprimer",
                    () async {
                      final ok =
                          await _confirmDelete(_selectedPolygonId!);
                      if (ok == true) {
                        await _deletePolygon(_selectedPolygonId!);
                      }
                    },
                    color: Colors.red,
                  ),
                ],
        ),
      ),
    );
  }

  ListTile _actionTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  // ================= ACTIONS =================

  Future<void> _startDraw() async {
    setState(() => _selectedPolygonId = null);
    await _controller.runJavaScript("startDraw();");
  }

  Future<void> _enableGeometryEdit() async {
    if (_selectedPolygonId == null) return;
    await _controller.runJavaScript(
      "enableEdit(${jsonEncode(_selectedPolygonId)});",
    );
  }

  Future<void> _saveGeometryEdit() async {
    if (_selectedPolygonId == null) return;
    await _controller.runJavaScript(
      "saveEdit(${jsonEncode(_selectedPolygonId)});",
    );
  }

  Future<void> _deletePolygon(String id) async {
    await _controller.runJavaScript(
      "deletePolygon(${jsonEncode(id)});",
    );
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
      builder: (_) => _ElegantSheet(
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
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Enregistrer"),
            ),
          ],
        ),
      ),
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
        createdBy: widget.user.id,
      );
    }
  }

  // ================= CONFIRM DELETE =================

  Future<bool?> _confirmDelete(String id) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer ?"),
        content: Text("Confirmer la suppression de $id"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer"),
          ),
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
          top: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: "releve",
            backgroundColor: const Color(0xFFBBF0CE),
            foregroundColor: Colors.black,
            onPressed: !_loaded ? null : _openReleveMenu,
            child: const Icon(Icons.edit_location_alt),
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
