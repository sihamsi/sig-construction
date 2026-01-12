import 'package:flutter/material.dart';
import 'data/db/app_database.dart';

class ConstructionsListPage extends StatefulWidget {
  const ConstructionsListPage({super.key, required this.onOpenInMap});
  final void Function(String id) onOpenInMap;

  @override
  State<ConstructionsListPage> createState() =>
      _ConstructionsListPageState();
}

class _ConstructionsListPageState extends State<ConstructionsListPage> {
  final _db = AppDatabase.instance;

  String _qAdresse = "";
  String _qType = "Tous";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: "Recherche adresse...",
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) =>
                          setState(() => _qAdresse = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _qType,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: "Tous", child: Text("Tous")),
                      DropdownMenuItem(
                        value: "residentiel",
                        child: Text("Résidentiel"),
                      ),
                      DropdownMenuItem(
                        value: "commercial",
                        child: Text("Commercial"),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _qType = v ?? "Tous"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _db.searchConstructions(
                adresseQuery: _qAdresse,
                type: _qType == "Tous" ? null : _qType,
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
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final id = (r['id'] ?? '').toString();
                    final adresse = (r['adresse'] ?? '').toString();
                    final type =
                        (r['type_construction'] ?? '').toString();

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            type == "commercial"
                                ? Icons.storefront
                                : Icons.home_work_outlined,
                          ),
                        ),
                        title: Text(
                          adresse.isEmpty
                              ? "Construction $id"
                              : adresse,
                        ),
                        subtitle: Text("ID: $id • Type: $type"),
                        onTap: () => widget.onOpenInMap(id),
                      ),
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
