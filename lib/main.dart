import 'package:flutter/material.dart';
import 'data/db/app_database.dart';
import 'data/models/user.dart';
import 'map_page.dart';
import 'constructions_list_page.dart';
import 'dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SigConstructionApp());
}

class SigConstructionApp extends StatelessWidget {
  const SigConstructionApp({super.key});

  // 🎨 Couleur principale
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

        // ✅ OBLIGATOIRE avec Material 3
        cardTheme: const CardThemeData(
          elevation: 6,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),

        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
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

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String _role = "agent";

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      setState(() {
        _error = "Veuillez remplir tous les champs";
        _loading = false;
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _error = "Les mots de passe ne correspondent pas";
        _loading = false;
      });
      return;
    }

    AppUser? user = await _db.getUserByEmail(email);
    if (user == null) {
      user = await _db.createUser(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        password: password,
        role: _role,
      );
    } else {
      user = await _db.loginUser(email, password);
    }

    if (!mounted) return;

    if (user == null) {
      setState(() {
        _error = "Identifiants invalides";
        _loading = false;
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeShell(user: user)),
    );

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F7FA), Color(0xFFE3F2FD)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFBBF0CE),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        size: 34,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "SIG Construction",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Authentification sécurisée avec rôles",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _firstNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "Nom",
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lastNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "Prénom",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "Téléphone",
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "Mot de passe",
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Confirmation du mot de passe",
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(
                        labelText: "Rôle",
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "agent",
                          child: Text("Agent"),
                        ),
                        DropdownMenuItem(
                          value: "supervisor",
                          child: Text("Superviseur"),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _role = value ?? _role),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _authenticate,
                        icon: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          _loading ? "Connexion..." : "Se connecter",
                        ),
                      ),
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

////////////////////////////////////////////////////////////////
/// HOME (CARTE + LISTE + DASHBOARD)
////////////////////////////////////////////////////////////////
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});
  final AppUser user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// 🔑 clé vers MapPageState
  final GlobalKey<MapPageState> _mapKey = GlobalKey<MapPageState>();

  void _openInMap(String id) {
    setState(() => _index = 0);
    _mapKey.currentState?.focusOn(id);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _index == 0
                  ? "Carte"
                  : _index == 1
                      ? "Constructions"
                      : "Dashboard",
            ),
            Text(
              "${user.fullName} • ${user.isSupervisor ? "Superviseur" : "Agent"}",
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          MapPage(
            key: _mapKey,
            user: user,
            onTapFeature: (_) {},
          ),
          ConstructionsListPage(
            user: user,
            onOpenInMap: _openInMap,
          ),
          DashboardPage(user: user),
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
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: "Dashboard",
          ),
        ],
      ),
    );
  }
}
