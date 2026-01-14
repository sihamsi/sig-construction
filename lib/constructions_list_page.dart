import 'package:flutter/material.dart';

import 'construction_types.dart';
import 'data/db/app_database.dart';
import 'data/models/user.dart';

/// ✅ Liste des constructions (version stable layout)
///
/// Fix principaux par rapport à v3:
/// - Évite les erreurs "RenderBox was not laid out" liées à Flexible/Expanded
///   dans les items des Dropdown (overlay avec contraintes parfois non bornées).
/// - Recherche texte + filtre par type.
/// - Tap = aller à la carte.
/// - Long press = menu (Modifier attributs / Aller à la carte).
class ConstructionsListPage extends StatefulWidget {
  const ConstructionsListPage({
    super.key,
    required this.onOpenInMap,
    required this.user,
  });

  final void Function(String id) onOpenInMap;
  final AppUser user;

  @override
  State<ConstructionsListPage> createState() => _ConstructionsListPageState();
}

class _ConstructionsListPageState extends State<ConstructionsListPage> {
  final _db = AppDatabase.instance;

  String _q = ""; // recherche texte
  String _qType = "Tous";

  // (Optionnel) filtre agent pour superviseur
  int? _agentFilterId;
  List<AppUser> _agents = [];

  @override
  void initState() {
    super.initState();
    if (widget.user.isSupervisor) {
      _loadAgents();
    }
  }

  Future<void> _loadAgents() async {
    final agents = await _db.getAgents();
    if (!mounted) return;
    setState(() => _agents = agents);
  }

  // ------------------ EDIT ATTRIBUTES ------------------

  Future<void> _openEditAttributes(String id) async {
    final row = await _db.getConstructionById(id);
    if (!mounted) return;

    if (row == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Construction introuvable")));
      return;
    }

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
        builder: (context, setModalState) => _EditSheet(
          title: "Modifier attributs",
          child: Column(
            children: [
              TextField(
                controller: adresseCtrl,
                decoration: const InputDecoration(labelText: "Nom / Adresse"),
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
                items: ConstructionTypes.all
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.code,
                        child: _DropdownTypeItem(
                          label: t.label,
                          color: t.color,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setModalState(() => type = v ?? type),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                      label: const Text("Annuler"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.save),
                      label: const Text("Enregistrer"),
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
      await _db.updateConstruction(
        id: id,
        adresse: adresseCtrl.text.trim(),
        contact: contactCtrl.text.trim(),
        typeConstruction: type,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Modifié avec succès ✅")));
      setState(() {});
    }
  }

  void _showLongPressMenu(String id) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text("Modifier les attributs"),
              subtitle: const Text("Adresse / Contact / Type"),
              onTap: () async {
                Navigator.pop(context);
                await _openEditAttributes(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text("Aller à la carte"),
              onTap: () {
                Navigator.pop(context);
                widget.onOpenInMap(id);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Rechercher (nom/adresse/contact/id)...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _q.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _q = ""),
                            ),
                    ),
                    onChanged: (v) => setState(() => _q = v.trim()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _qType,
                          decoration: const InputDecoration(labelText: "Type"),
                          items: [
                            const DropdownMenuItem(
                              value: "Tous",
                              child: Text("Tous"),
                            ),
                            ...ConstructionTypes.all.map(
                              (t) => DropdownMenuItem(
                                value: t.code,
                                child: _DropdownTypeItem(
                                  label: t.label,
                                  color: t.color,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _qType = v ?? "Tous"),
                        ),
                      ),
                      if (widget.user.isSupervisor) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            value: _agentFilterId,
                            decoration: const InputDecoration(
                              labelText: "Agent",
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text("Tous"),
                              ),
                              ..._agents.map(
                                (a) => DropdownMenuItem<int?>(
                                  value: a.id,
                                  child: Text(a.fullName),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _agentFilterId = v),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _db.refreshTick,
              builder: (_, __, ___) {
                return FutureBuilder<List<Map<String, Object?>>>(
                  future: _db.searchConstructionsForUser(
                    user: widget.user,
                    adresseQuery: _q,
                    type: _qType == "Tous" ? null : _qType,
                    agentId: _agentFilterId,
                  ),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rows = snap.data ?? [];
                    if (rows.isEmpty) {
                      return const Center(child: Text("Aucune construction"));
                    }

                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final id = (r['id'] ?? '').toString();
                        final adresse = (r['adresse'] ?? '').toString();
                        final contact = (r['contact'] ?? '').toString();
                        final type = (r['type_construction'] ?? '').toString();
                        final createdBy = (r['created_by'] as int?) ?? 0;

                        final typeDef = ConstructionTypes.byCode(type);

                        final agentName = widget.user.isSupervisor
                            ? _agents
                                  .firstWhere(
                                    (a) => a.id == createdBy,
                                    orElse: () => AppUser(
                                      id: 0,
                                      username: createdBy.toString(),
                                      firstName: "",
                                      lastName: "",
                                      phone: "",
                                      email: "",
                                      role: "agent",
                                    ),
                                  )
                                  .fullName
                            : "";

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: typeDef.color,
                              foregroundColor: Colors.white,
                              child: Text(
                                typeDef.label.isNotEmpty
                                    ? typeDef.label[0]
                                    : "?",
                              ),
                            ),
                            title: Text(
                              adresse.isEmpty ? "Construction $id" : adresse,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Type : ${typeDef.label}"),
                                if (contact.isNotEmpty)
                                  Text("Contact : $contact"),
                                Text("ID : $id"),
                                if (widget.user.isSupervisor && createdBy != 0)
                                  Text("Agent : $agentName"),
                              ],
                            ),
                            trailing: const Icon(Icons.map_outlined),
                            onTap: () => widget.onOpenInMap(id),
                            onLongPress: () => _showLongPressMenu(id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Petit widget sécurisé pour les items de dropdown (évite Expanded/Flexible non bornés).
class _DropdownTypeItem extends StatelessWidget {
  const _DropdownTypeItem({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _EditSheet extends StatelessWidget {
  const _EditSheet({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
