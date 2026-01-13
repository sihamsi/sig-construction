import 'package:flutter/material.dart';
import 'data/db/app_database.dart';
import 'data/models/user.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.user});
  final AppUser user;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _db = AppDatabase.instance;

  late Future<int> _totalFuture;
  late Future<Map<String, int>> _byTypeFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();

    // 🔄 rafraîchir automatiquement si DB change
    _db.refreshTick.addListener(_loadStats);
  }

  void _loadStats() {
    _totalFuture = _db.countConstructionsForUser(widget.user);
    _byTypeFuture = _db.countByTypeForUser(widget.user);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _db.refreshTick.removeListener(_loadStats);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ PAS DE SCAFFOLD ICI
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= TOTAL =================
            FutureBuilder<int>(
              future: _totalFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const _StatCard.loading();
                }

                return _StatCard(
                  title: widget.user.isSupervisor
                      ? "Nombre total de constructions"
                      : "Vos constructions",
                  value: snap.data.toString(),
                  icon: Icons.apartment,
                  color: Colors.teal,
                );
              },
            ),

            const SizedBox(height: 24),

            // ================= PAR TYPE =================
            Text(
              "Répartition par type",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            FutureBuilder<Map<String, int>>(
              future: _byTypeFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const _StatCard.loading();
                }

                final data = snap.data!;
                if (data.isEmpty) {
                  return const Text("Aucune donnée disponible");
                }

                return Column(
                  children: data.entries.map((e) {
                    final isResidential =
                        e.key.toLowerCase().contains("resident");

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StatCard(
                        title: e.key,
                        value: e.value.toString(),
                        icon: isResidential
                            ? Icons.home_work_outlined
                            : Icons.storefront_outlined,
                        color: isResidential
                            ? Colors.blueGrey
                            : Colors.orange,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// UI CARD
// =============================================================

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  const _StatCard.loading()
      : title = "Chargement...",
        value = "--",
        icon = Icons.hourglass_empty,
        color = Colors.grey;

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
