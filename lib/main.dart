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

  // 🎨 Couleur principale (tu pourras la changer après)
  static const Color primary = Color(0xFFBBF0CE);

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
        ),

        scaffoldBackgroundColor: const Color(0xFFF7F8FA),

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 6,
        ),

        // ✅ CORRECTION ICI
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
                  const Icon(Icons.map, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    "SIG Construction",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: "Utilisateur",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Mot de passe",
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
/// HOME
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
