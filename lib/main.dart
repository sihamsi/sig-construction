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
        colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
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
/// LOGIN / SIGNUP PAGE
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

  // ✅ true = écran connexion (email + mot de passe)
  // ✅ false = écran inscription (tous les champs)
  bool _isLogin =
      true; // ⇦ Mets à false si tu veux afficher "Inscription" par défaut.

  bool _loading = false;
  String? _error;
  String? _success;
  String _role = 'agent';

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

  void _switchMode(bool toLogin) {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLogin = toLogin;
      _error = null;
      _success = null;
    });

    // Optionnel: quand on passe en connexion, on vide la confirmation.
    if (toLogin) {
      _confirmCtrl.clear();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
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
        _error = "Veuillez remplir tous les champs pour l'inscription";
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

    try {
      final existing = await _db.getUserByEmail(email);
      if (!mounted) return;

      if (existing != null) {
        setState(() {
          _error = "Ce compte existe déjà. Cliquez sur 'Se connecter'.";
          _loading = false;
        });
        return;
      }

      // ✅ Crée le compte, MAIS NE CONNECTE PAS AUTOMATIQUEMENT.
      await _db.createUser(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        password: password,
        role: _role,
      );

      if (!mounted) return;

      final msg =
          "Inscription réussie ✅. Vous pouvez maintenant vous connecter.";

      setState(() {
        _success = msg;
        _isLogin = true; // ⇦ bascule automatiquement vers l'écran connexion

        // On garde l'email (pratique), mais on vide le reste
        _passCtrl.clear();
        _confirmCtrl.clear();
        _firstNameCtrl.clear();
        _lastNameCtrl.clear();
        _phoneCtrl.clear();
        _role = 'agent';
      });

      _showSnack(msg);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Erreur lors de l'inscription: $e";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = "Veuillez saisir l'email et le mot de passe";
        _loading = false;
      });
      return;
    }

    try {
      final AppUser? user = await _db.loginUser(email, password);
      if (!mounted) return;

      if (user == null) {
        final existing = await _db.getUserByEmail(email);
        if (!mounted) return;

        setState(() {
          _error = existing == null
              ? "Compte introuvable. Cliquez sur 'S'inscrire'."
              : "Mot de passe incorrect";
        });
        return;
      }

      // ✅ Connexion OK → entrer dans l'application
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeShell(user: user)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Erreur lors de la connexion: $e";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5F7FA), Color(0xFFE3F2FD)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
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
                            _isLogin
                                ? "Connectez-vous à votre compte"
                                : "Créez un compte (inscription)",
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                          const SizedBox(height: 20),

                          // ================== CHAMPS INSCRIPTION ==================
                          if (!_isLogin) ...[
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
                          ],

                          // ================== CHAMPS COMMUNS ==================
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
                            textInputAction: _isLogin
                                ? TextInputAction.done
                                : TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: "Mot de passe",
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            onSubmitted: (_) {
                              if (_isLogin && !_loading) {
                                _signIn();
                              }
                            },
                          ),

                          // ================== CONFIRM + ROLE (INSCRIPTION) ==================
                          if (!_isLogin) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmCtrl,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
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
                          ],

                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          if (_success != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _success!,
                              style: const TextStyle(color: Colors.green),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _loading
                                  ? null
                                  : (_isLogin ? _signIn : _signUp),
                              icon: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _isLogin ? Icons.login : Icons.person_add,
                                    ),
                              label: Text(
                                _loading
                                    ? (_isLogin
                                          ? "Connexion..."
                                          : "Inscription...")
                                    : (_isLogin
                                          ? "Se connecter"
                                          : "S'inscrire"),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ✅ Link comme sur ton screenshot
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLogin
                                    ? "Pas de compte ?"
                                    : "Déjà un compte ?",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.black54),
                              ),
                              const SizedBox(width: 6),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => _switchMode(!_isLogin),
                                child: Text(
                                  _isLogin ? "S'inscrire" : "Se connecter",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
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
    final map = _mapKey.currentState;
    map?.focusOn(id);
    map?.showDetails(id);
  }

  void _logout() {
    // Ici, pas de session à "vider" (SQLite).
    // On revient juste à la page de connexion en supprimant l'historique.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
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
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Déconnexion'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          MapPage(key: _mapKey, user: user, onTapFeature: (_) {}),
          ConstructionsListPage(user: user, onOpenInMap: _openInMap),
          DashboardPage(user: user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: "Carte"),
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
