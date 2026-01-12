import 'package:flutter/material.dart';
import 'data/db/app_database.dart';
import 'map_page.dart';
import 'constructions_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SigConstructionApp());
}

class SigConstructionApp extends StatelessWidget {
  const SigConstructionApp({super.key});

  // 🎨 Couleurs Bordeaux
  static const Color primary = Color(0xFF7A1E2D);
  static const Color secondary = Color(0xFFB23A48);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIG Construction',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: secondary,
        ),

        scaffoldBackgroundColor: const Color(0xFFF7F6F8),

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 6,
        ),

        // ✅ CORRECTION ICI (Material 3)
        cardTheme: CardThemeData(
          elevation: 6,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

////////////////////////////////////////////////////////////////
/// LOGIN PAGE
////////////////////////////////////////////////////////////////
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

    final ok = await _db.checkLogin(
      _userCtrl.text.trim(),
      _passCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else {
      setState(() => _error = "Identifiants invalides");
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.map, color: Colors.white, size: 42),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "SIG Construction",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Relevé & gestion cartographique",
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: "Utilisateur",
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
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text("Se connecter"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////
/// HOME SHELL (CARTE + LISTE)
////////////////////////////////////////////////////////////////
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? "Carte" : "Constructions"),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          MapPage(key: _mapKey, onTapFeature: (_) {}),
          ConstructionsListPage(onOpenInMap: _openInMap),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: "Carte",
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            label: "Liste",
          ),
        ],
      ),
    );
  }
}
