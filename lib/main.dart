import 'package:flutter/material.dart';
import 'data/db/app_database.dart';
import 'map_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SigConstructionApp());
}

class SigConstructionApp extends StatelessWidget {
  const SigConstructionApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3D5AFE);

    return MaterialApp(
      title: 'SIG Construction',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(centerTitle: true),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        cardTheme: CardThemeData(
          elevation: 10,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// -------------------- LOGIN --------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _db = AppDatabase.instance;

  final _userCtrl = TextEditingController(text: "admin");
  final _passCtrl = TextEditingController(text: "admin");

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ok = await _db.checkLogin(
        _userCtrl.text.trim(),
        _passCtrl.text.trim(),
      );

      if (!mounted) return;

      if (ok) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
      } else {
        setState(() => _error = "Identifiants invalides");
      }
    } catch (e) {
      setState(() => _error = "Erreur DB: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primaryContainer, cs.secondaryContainer],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.map_outlined,
                        size: 38,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "SIG Construction",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Relevé cartographique & consultation",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(
                        labelText: "Username",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: "Mot de passe",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Se connecter"),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Compte test : admin / admin",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------- HOME (Carte + Liste) --------------------
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final GlobalKey<MapPageState> _mapKey = GlobalKey<MapPageState>();

  void _openInMap(String id) {
    setState(() => _index = 0);
    _mapKey.currentState?.focusOn(id);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      MapPage(key: _mapKey, onTapFeature: (_) {}),
      ConstructionsListPage(onOpenInMap: _openInMap),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_index == 0 ? "Carte" : "Constructions")),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: "Carte"),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            label: "Liste",
          ),
        ],
      ),
    );
  }
}

// -------------------- LISTE + Recherche multicritères --------------------
class ConstructionsListPage extends StatefulWidget {
  const ConstructionsListPage({super.key, required this.onOpenInMap});
  final void Function(String id) onOpenInMap;

  @override
  State<ConstructionsListPage> createState() => _ConstructionsListPageState();
}

class _ConstructionsListPageState extends State<ConstructionsListPage> {
  final _db = AppDatabase.instance;

  String _qAdresse = "";
  String _qType = "Tous";

  @override
  void initState() {
    super.initState();
    _db.refreshTick.addListener(_onDbRefresh);
  }

  void _onDbRefresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _db.refreshTick.removeListener(_onDbRefresh);
    super.dispose();
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
                      onChanged: (v) => setState(() => _qAdresse = v.trim()),
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
                    onChanged: (v) => setState(() => _qType = v ?? "Tous"),
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
                if (snap.hasError)
                  return Center(child: Text("Erreur: ${snap.error}"));

                final rows = snap.data ?? [];
                if (rows.isEmpty)
                  return const Center(child: Text("Aucune construction"));

                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final id = (r['id'] ?? '').toString();
                    final adresse = (r['adresse'] ?? '').toString();
                    final type = (r['type_construction'] ?? '').toString();
                    final isCommercial = type == "commercial";

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            isCommercial
                                ? Icons.storefront
                                : Icons.home_work_outlined,
                          ),
                        ),
                        title: Text(
                          adresse.isEmpty ? "Construction $id" : adresse,
                        ),
                        subtitle: Text("ID: $id • Type: $type"),
                        onTap: () => widget.onOpenInMap(id),
                        onLongPress: () async {
                          await _openEditDialog(context, r);
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == "edit") await _openEditDialog(context, r);
                            if (v == "delete") {
                              final ok = await _confirmDelete(context, id);
                              if (ok == true) await _db.deleteConstruction(id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: "edit",
                              child: Text("Modifier"),
                            ),
                            PopupMenuItem(
                              value: "delete",
                              child: Text("Supprimer"),
                            ),
                          ],
                        ),
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

  Future<bool?> _confirmDelete(BuildContext context, String id) {
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

  Future<void> _openEditDialog(
    BuildContext context,
    Map<String, Object?> row,
  ) async {
    final id = (row['id'] ?? '').toString();
    final adresseCtrl = TextEditingController(
      text: (row['adresse'] ?? '').toString(),
    );
    final contactCtrl = TextEditingController(
      text: (row['contact'] ?? '').toString(),
    );
    String type = (row['type_construction'] ?? 'residentiel').toString();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
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
              Text(
                "Modifier $id",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    adresseCtrl.dispose();
    contactCtrl.dispose();
  }
}
