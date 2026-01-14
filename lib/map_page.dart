import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'construction_types.dart';
import 'data/db/app_database.dart';
import 'data/models/user.dart';

/// ✅ MapPage (Leaflet + WebView)
///
/// Fix principaux par rapport à v3:
/// - Donne une contrainte de taille claire au WebView (Positioned.fill + StackFit.expand)
///   pour éviter "RenderBox was not laid out" sur certains appareils.
/// - Dropdown agent (superviseur) avec largeur bornée + isExpanded.
/// - Le reste des fonctionnalités (détails, édition attributs, etc.) est identique.
///
/// ⚠️ Couleurs:
/// - Flutter envoie `feature.properties.type_color` (hex).
/// - map.html DOIT utiliser cette propriété dans sa fonction style.
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
  bool _detailsOpen = false;

  String? _selectedPolygonId;
  List<AppUser> _agents = [];
  int? _agentFilterId;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('MapChannel', onMessageReceived: _onMapMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _loaded = true);
            await _pushGeoJsonToMap();
          },
        ),
      )
      ..loadFlutterAsset('assets/map/map.html');

    // Refresh carte quand la DB change
    AppDatabase.instance.refreshTick.addListener(() async {
      if (_loaded) await _pushGeoJsonToMap();
    });

    if (widget.user.isSupervisor) {
      _loadAgents();
    }
  }

  Future<void> _loadAgents() async {
    final agents = await AppDatabase.instance.getAgents();
    if (!mounted) return;
    setState(() => _agents = agents);
  }

  // ================= MAP -> FLUTTER =================

  Future<void> _onMapMessage(JavaScriptMessage msg) async {
    try {
      final data = jsonDecode(msg.message);

      if (data['type'] == 'tap') {
        final id = data['id'].toString();
        if (!mounted) return;
        setState(() => _selectedPolygonId = id);
        widget.onTapFeature(id);
        await showDetails(id);
        return;
      }

      if (data['type'] == 'untap') {
        if (!mounted) return;
        setState(() => _selectedPolygonId = null);
        return;
      }

      if (data['type'] == 'created') {
        final feature = (data['feature'] as Map).cast<String, dynamic>();
        await _openCreateForm(feature);
        return;
      }

      if (data['type'] == 'edited') {
        final id = data['id'].toString();
        final feature = (data['feature'] as Map).cast<String, dynamic>();

        await AppDatabase.instance.updateGeometry(
          id: id,
          geojsonFeature: feature,
        );

        if (!mounted) return;
        setState(() => _selectedPolygonId = null);
        await _pushGeoJsonToMap();
        return;
      }
    } catch (e) {
      debugPrint('MapChannel error: $e');
    }
  }

  // ================= DATA -> MAP =================

  Future<void> _pushGeoJsonToMap() async {
    final rows = await AppDatabase.instance.getConstructionsForUser(
      widget.user,
      _agentFilterId,
    );

    final features = rows
        .map<Map<String, dynamic>?>((r) {
          final geo = (r['geometrie_geojson'] ?? '').toString();
          if (geo.isEmpty) return null;

          final f = jsonDecode(geo) as Map<String, dynamic>;
          f['properties'] ??= {};
          f['properties']['id'] = r['id'].toString();

          final typeCode = (r['type_construction'] ?? '').toString();
          f['properties']['type_construction'] = typeCode;
          f['properties']['type_color'] = ConstructionTypes.hexOf(typeCode);
          f['properties']['type_label'] = ConstructionTypes.labelOf(typeCode);

          f['properties']['adresse'] = (r['adresse'] ?? '').toString();
          f['properties']['contact'] = (r['contact'] ?? '').toString();
          f['properties']['created_by'] = (r['created_by'] ?? '').toString();
          return f;
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    final fc = {'type': 'FeatureCollection', 'features': features};
    await _controller.runJavaScript('setData(${jsonEncode(fc)});');
  }

  // ================= API (pour HomeShell) =================

  Future<void> focusOn(String id) async {
    if (!_loaded) return;
    await _controller.runJavaScript('focusOn(${jsonEncode(id)});');
    if (!mounted) return;
    setState(() => _selectedPolygonId = id);
  }

  Future<void> clearSelection() async {
    if (!_loaded) return;
    try {
      await _controller.runJavaScript('clearSelection();');
    } catch (_) {
      // ignore (si map.html n'a pas encore la fonction)
    }
    if (!mounted) return;
    setState(() => _selectedPolygonId = null);
  }

  // ================= DETAILS =================

  Future<void> showDetails(String id) async {
    if (!mounted) return;
    if (_detailsOpen) return;

    final row = await AppDatabase.instance.getConstructionById(id);
    if (!mounted) return;
    if (row == null) return;

    final adresse = (row['adresse'] ?? '').toString();
    final contact = (row['contact'] ?? '').toString();
    final typeCode = (row['type_construction'] ?? '').toString();
    final date = (row['date_releve'] ?? '').toString();
    final createdBy = row['created_by'];

    final typeDef = ConstructionTypes.byCode(typeCode);

    _detailsOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ElegantSheet(
        title: 'Détails construction',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('ID'),
              subtitle: Text(id),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Adresse'),
              subtitle: Text(adresse.isEmpty ? '-' : adresse),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Contact'),
              subtitle: Text(contact.isEmpty ? '-' : contact),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: typeDef.color,
                  shape: BoxShape.circle,
                ),
              ),
              title: const Text('Type de construction'),
              subtitle: Text(typeDef.label),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Date de relevé'),
              subtitle: Text(date.isEmpty ? '-' : date),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Créé par'),
              subtitle: Text(createdBy == null ? '-' : createdBy.toString()),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Fermer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await clearSelection();
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Désélectionner'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _openEditAttributes(id);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifier les attributs'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () async {
                final canDelete =
                    widget.user.isSupervisor ||
                    createdBy?.toString() == widget.user.id.toString();
                if (!canDelete) {
                  Navigator.pop(context);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Vous n'êtes pas autorisé à supprimer."),
                    ),
                  );
                  return;
                }
                final ok = await _confirmDelete(id);
                if (ok == true) {
                  Navigator.pop(context);
                  await _deletePolygon(id);
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
            ),
          ],
        ),
      ),
    ).whenComplete(() => _detailsOpen = false);
  }

  Future<void> _openEditAttributes(String id) async {
    final row = await AppDatabase.instance.getConstructionById(id);
    if (!mounted) return;
    if (row == null) return;

    final adresseCtrl = TextEditingController(
      text: (row['adresse'] ?? '').toString(),
    );
    final contactCtrl = TextEditingController(
      text: (row['contact'] ?? '').toString(),
    );
    String type = (row['type_construction'] ?? ConstructionTypes.defaultCode)
        .toString();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => _ElegantSheet(
          title: 'Modifier les attributs',
          child: Column(
            children: [
              TextField(
                controller: adresseCtrl,
                decoration: const InputDecoration(labelText: 'Adresse / Nom'),
              ),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Contact'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(
                  labelText: 'Type de construction',
                ),
                items: ConstructionTypes.all
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.code,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: t.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(t.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setModalState(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      await AppDatabase.instance.updateConstruction(
        id: id,
        adresse: adresseCtrl.text.trim(),
        contact: contactCtrl.text.trim(),
        typeConstruction: type,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attributs modifiés ✅')));
    }
  }

  // ================= RELEVÉ =================

  void _openReleveMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _ElegantSheet(
        title: 'Relevé – Actions',
        child: Column(
          children: _selectedPolygonId == null
              ? [
                  ListTile(
                    leading: const Icon(Icons.add_location_alt),
                    title: const Text('Dessiner une construction'),
                    onTap: () {
                      Navigator.pop(context);
                      _startDraw();
                    },
                  ),
                ]
              : [
                  _actionTile(
                    Icons.remove_circle_outline,
                    'Désélectionner',
                    clearSelection,
                  ),
                  _actionTile(
                    Icons.edit,
                    'Modifier la forme',
                    _enableGeometryEdit,
                  ),
                  _actionTile(
                    Icons.check_circle,
                    'Valider la modification',
                    _saveGeometryEdit,
                    color: Colors.green,
                  ),
                  _actionTile(Icons.delete, 'Supprimer', () async {
                    final ok = await _confirmDelete(_selectedPolygonId!);
                    if (ok == true) {
                      await _deletePolygon(_selectedPolygonId!);
                    }
                  }, color: Colors.red),
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
    await clearSelection();
    await _controller.runJavaScript('startDraw();');
  }

  Future<void> _enableGeometryEdit() async {
    if (_selectedPolygonId == null) return;
    await _controller.runJavaScript(
      'enableEdit(${jsonEncode(_selectedPolygonId)});',
    );
  }

  Future<void> _saveGeometryEdit() async {
    if (_selectedPolygonId == null) return;
    await _controller.runJavaScript(
      'saveEdit(${jsonEncode(_selectedPolygonId)});',
    );
  }

  Future<void> _deletePolygon(String id) async {
    await _controller.runJavaScript('deletePolygon(${jsonEncode(id)});');
    await AppDatabase.instance.deleteConstruction(id);
    if (!mounted) return;
    setState(() => _selectedPolygonId = null);
  }

  // ================= CREATE =================

  Future<void> _openCreateForm(Map<String, dynamic> feature) async {
    final adresseCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    String type = ConstructionTypes.defaultCode;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => _ElegantSheet(
          title: 'Nouvelle construction',
          child: Column(
            children: [
              TextField(
                controller: adresseCtrl,
                decoration: const InputDecoration(labelText: 'Adresse / Nom'),
              ),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Contact'),
              ),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(
                  labelText: 'Type de construction',
                ),
                items: ConstructionTypes.all
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.code,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: t.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(t.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setModalState(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enregistrer'),
              ),
            ],
          ),
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
        title: const Text('Supprimer ?'),
        content: Text('Confirmer la suppression de $id'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ✅ Important: taille explicite
        Positioned.fill(child: WebViewWidget(controller: _controller)),
        if (!_loaded) const Center(child: CircularProgressIndicator()),

        if (widget.user.isSupervisor)
          Positioned(
            top: 16,
            left: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: SizedBox(
                  width: 220,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: _agentFilterId,
                      hint: const Text('Filtrer par agent'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tous les agents'),
                        ),
                        ..._agents.map(
                          (agent) => DropdownMenuItem<int?>(
                            value: agent.id,
                            child: Text(
                              agent.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) async {
                        setState(() => _agentFilterId = value);
                        if (_loaded) await _pushGeoJsonToMap();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'releve',
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
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
