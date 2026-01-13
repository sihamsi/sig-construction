import 'package:flutter/material.dart';
import 'data/db/app_database.dart';
import 'data/models/user.dart';

class ConstructionsListPage extends StatefulWidget {
  const ConstructionsListPage({
    super.key,
    required this.onOpenInMap,
    required this.user,
  });
  final void Function(String id) onOpenInMap;
  final AppUser user;

  @override
  State<ConstructionsListPage> createState() =>
      _ConstructionsListPageState();
}

class _ConstructionsListPageState extends State<ConstructionsListPage> {
  final _db = AppDatabase.instance;

  String _qAdresse = "";
  String _qType = "Tous";
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
                  if (widget.user.isSupervisor) ...[
                    const SizedBox(width: 10),
                    DropdownButton<int?>(
                      value: _agentFilterId,
                      underline: const SizedBox(),
                      hint: const Text("Agent"),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text("Tous"),
                        ),
                        ..._agents.map(
                          (agent) => DropdownMenuItem<int?>(
                            value: agent.id,
                            child: Text(agent.fullName),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _agentFilterId = value),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(
                widget.user.isSupervisor
                    ? Icons.verified_outlined
                    : Icons.person_outline,
              ),
              label: Text(
                widget.user.isSupervisor
                    ? "Vue superviseur : toutes les constructions"
                    : "Vue agent : vos constructions uniquement",
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _db.searchConstructionsForUser(
                user: widget.user,
                adresseQuery: _qAdresse,
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
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final id = (r['id'] ?? '').toString();
                    final adresse = (r['adresse'] ?? '').toString();
                    final type =
                        (r['type_construction'] ?? '').toString();
                    final createdBy =
                        (r['created_by'] as int?) ?? 0;
                    final agentName = widget.user.isSupervisor
                        ? _agents
                            .firstWhere(
                              (agent) => agent.id == createdBy,
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
                        subtitle: Text(
                          widget.user.isSupervisor && createdBy != 0
                              ? "ID: $id • Type: $type • Agent: $agentName"
                              : "ID: $id • Type: $type",
                        ),
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
