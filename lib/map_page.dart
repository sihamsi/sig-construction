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
              widget.onTapFeature(id);
              await _openDetailsById(id);
              return;
            }

            if (data['type'] == 'created') {
              final feature = (data['feature'] as Map).cast<String, dynamic>();
              await _openCreateForm(feature);
              return;
            }
          } catch (_) {}
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

  String _newId() {
    // notion simple (cours) : id basé sur timestamp
    final ms = DateTime.now().millisecondsSinceEpoch;
    return "c${ms.toString().substring(ms.toString().length - 7)}";
  }

  Future<void> _pushGeoJsonToMap() async {
    final rows = await AppDatabase.instance.getConstructions();

    final features = rows.map((r) {
      final geo = (r['geometrie_geojson'] ?? '').toString();
      final decoded = (jsonDecode(geo) as Map)
          .cast<String, dynamic>(); // Feature
      decoded['properties'] ??= <String, dynamic>{};

      decoded['properties']['id'] = (r['id'] ?? '').toString();
      decoded['properties']['type_construction'] =
          (r['type_construction'] ?? '').toString();
      decoded['properties']['adresse'] = (r['adresse'] ?? '').toString();
      decoded['properties']['contact'] = (r['contact'] ?? '').toString();

      return decoded;
    }).toList();

    final fc = {"type": "FeatureCollection", "features": features};
    await _controller.runJavaScript("setData(${jsonEncode(fc)});");
  }

  Future<void> focusOn(String id) async {
    if (!_loaded) return;
    await _controller.runJavaScript("focusOn(${jsonEncode(id)});");
  }

  Future<void> _startDraw() async {
    if (!_loaded) return;
    await _controller.runJavaScript("startDraw();");
  }

  // ----------- CREATE (Form après relevé) -----------
  Future<void> _openCreateForm(Map<String, dynamic> geojsonFeature) async {
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
                decoration: const InputDecoration(
                  labelText: "Adresse",
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Contact",
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(
                  labelText: "Type de construction",
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "residentiel",
                    child: Text("Résidentiel"),
                  ),
                  DropdownMenuItem(
                    value: "commercial",
                    child: Text("Commercial"),
                  ),
                ],
                onChanged: (v) => type = v ?? type,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Annuler"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (adresseCtrl.text.trim().isEmpty) return;
                        Navigator.pop(context, true);
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text("Enregistrer"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      final id = _newId();

      geojsonFeature['properties'] ??= <String, dynamic>{};
      geojsonFeature['properties']['id'] = id;

      await AppDatabase.instance.insertConstruction(
        id: id,
        adresse: adresseCtrl.text.trim(),
        contact: contactCtrl.text.trim(),
        typeConstruction: type,
        geojsonFeature: geojsonFeature,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Construction $id enregistrée")));
      }
    }

    adresseCtrl.dispose();
    contactCtrl.dispose();
  }

  // ----------- DETAILS + EDIT + DELETE (tap polygon) -----------
  Future<void> _openDetailsById(String id) async {
    final row = await AppDatabase.instance.getConstructionById(id);
    if (!mounted || row == null) return;

    final adresse = (row['adresse'] ?? '').toString();
    final contact = (row['contact'] ?? '').toString();
    final type = (row['type_construction'] ?? '').toString();

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return _ElegantSheet(
          title: "Construction $id",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoLine(
                icon: Icons.place_outlined,
                label: "Adresse",
                value: adresse,
              ),
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.phone_outlined,
                label: "Contact",
                value: contact,
              ),
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.category_outlined,
                label: "Type",
                value: type,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _openEditDialog(id, adresse, contact, type);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text("Modifier"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final ok = await _confirmDelete(id);
                        if (ok == true) {
                          await AppDatabase.instance.deleteConstruction(id);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Supprimer"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditDialog(
    String id,
    String adresse0,
    String contact0,
    String type0,
  ) async {
    final adresseCtrl = TextEditingController(text: adresse0);
    final contactCtrl = TextEditingController(text: contact0);
    String type = type0.isEmpty ? "residentiel" : type0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return _ElegantSheet(
          title: "Modifier $id",
          child: Column(
            children: [
              TextField(
                controller: adresseCtrl,
                decoration: const InputDecoration(labelText: "Adresse"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: "Contact"),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(
                  labelText: "Type de construction",
                ),
                items: const [
                  DropdownMenuItem(
                    value: "residentiel",
                    child: Text("Résidentiel"),
                  ),
                  DropdownMenuItem(
                    value: "commercial",
                    child: Text("Commercial"),
                  ),
                ],
                onChanged: (v) => type = v ?? type,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () async {
                    await AppDatabase.instance.updateConstruction(
                      id: id,
                      adresse: adresseCtrl.text.trim(),
                      contact: contactCtrl.text.trim(),
                      typeConstruction: type,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Enregistrer"),
                ),
              ),
            ],
          ),
        );
      },
    );

    adresseCtrl.dispose();
    contactCtrl.dispose();
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
            onPressed: _loaded ? _startDraw : null,
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: const Text("Relevé"),
          ),
        ),
      ],
    );
  }
}

// -------- UI helpers (style plus sophistiqué sans packages externes) --------

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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = value.isEmpty ? "-" : value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: "$label : ",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
