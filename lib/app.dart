import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import 'data/admin_repository.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_sign_in_screen.dart';
import 'supabase_config.dart';
import 'theme/admin_theme.dart';

class IEntierAdministrationApp extends StatelessWidget {
  final AdminRepository? repository;

  const IEntierAdministrationApp({super.key, this.repository});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'i-ENTIER Administration',
    debugShowCheckedModeBanner: false,
    theme: buildAdminTheme(),
    home: AdminAuthGate(repository: repository ?? SupabaseAdminRepository()),
  );
}

class AdminAuthGate extends StatelessWidget {
  final AdminRepository repository;

  const AdminAuthGate({super.key, required this.repository});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: SupabaseConfig.client.auth.onAuthStateChange.map(
      (state) => state.session?.user,
    ),
    initialData: SupabaseConfig.client.auth.currentUser,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const AdminLoadingScreen();
      }
      final user = snapshot.data;
      if (user == null) return const AdminSignInScreen();
      return AdminAccessGate(user: user, repository: repository);
    },
  );
}

class AdminAccessGate extends StatelessWidget {
  final User user;
  final AdminRepository repository;

  const AdminAccessGate({
    super.key,
    required this.user,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: repository.watchAccess(user.uid),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const AdminLoadingScreen();
      }
      if (snapshot.hasError) {
        return AdminAccessError(user: user);
      }
      if (snapshot.data != true) return AdminAccessDenied(user: user);
      return AdminDashboardScreen(user: user, repository: repository);
    },
  );
}

class AdminLoadingScreen extends StatelessWidget {
  const AdminLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: AdminColors.primary)),
  );
}

class AdminAccessDenied extends StatelessWidget {
  final User user;

  const AdminAccessDenied({super.key, required this.user});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: AdminPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0ED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AdminColors.danger,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Accès administrateur requis',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AdminColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${user.email ?? 'Ce compte'} est bien connecté, mais ne possède pas encore le rôle administrateur.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AdminColors.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Identifiant à autoriser dans administrators',
                        style: TextStyle(
                          color: AdminColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      SelectableText(
                        user.uid,
                        style: const TextStyle(
                          color: AdminColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: user.uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Identifiant copié.')),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('Copier l’identifiant'),
                    ),
                    TextButton.icon(
                      onPressed: () => SupabaseConfig.client.auth.signOut(),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Changer de compte'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminAccessError extends StatelessWidget {
  final User user;

  const AdminAccessError({super.key, required this.user});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AdminPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: AdminColors.primary,
                  size: 42,
                ),
                const SizedBox(height: 15),
                Text(
                  'Vérification de l’accès impossible',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vérifiez la connexion et les politiques de la table administrators.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => SupabaseConfig.client.auth.signOut(),
                  child: const Text('Changer de compte'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
