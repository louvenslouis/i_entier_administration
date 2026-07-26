import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';
import '../theme/admin_theme.dart';

class AdminSignInScreen extends StatefulWidget {
  const AdminSignInScreen({super.key});

  @override
  State<AdminSignInScreen> createState() => _AdminSignInScreenState();
}

class _AdminSignInScreenState extends State<AdminSignInScreen> {
  bool _signingIn = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      await SupabaseConfig.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConfig.authRedirectUrl,
        queryParams: const {'prompt': 'select_account'},
      );
    } on AuthException catch (error) {
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      setState(() => _error = 'La connexion Google n’a pas abouti.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AdminColors.navy,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const _AdminBackdrop(),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 820;
                    final card = _AdminSignInCard(
                      signingIn: _signingIn,
                      error: _error,
                      onSignIn: _signIn,
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          const AdminBrand(light: true),
                          const SizedBox(height: 30),
                          card,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        const Expanded(flex: 11, child: _AdminStory()),
                        const SizedBox(width: 70),
                        Expanded(flex: 9, child: card),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AdminBackdrop extends StatelessWidget {
  const _AdminBackdrop();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF101D33), Color(0xFF183B70)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -110,
          top: -150,
          child: Container(
            width: 390,
            height: 390,
            decoration: const BoxDecoration(
              color: Color(0x182F6DFF),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          left: -100,
          bottom: -180,
          child: Container(
            width: 430,
            height: 430,
            decoration: const BoxDecoration(
              color: Color(0x0FFFF0C0),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AdminStory extends StatelessWidget {
  const _AdminStory();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AdminBrand(light: true),
      SizedBox(height: 46),
      Text(
        'La confiance commence\npar une bonne vérification.',
        style: TextStyle(
          color: Colors.white,
          fontSize: 42,
          height: 1.1,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.3,
        ),
      ),
      SizedBox(height: 18),
      Text(
        'Examinez les demandes des personnels et institutions avant leur apparition dans l’annuaire i-ENTIER.',
        style: TextStyle(color: Color(0xFFD5DFF3), fontSize: 17, height: 1.55),
      ),
    ],
  );
}

class _AdminSignInCard extends StatelessWidget {
  final bool signingIn;
  final String? error;
  final VoidCallback onSignIn;

  const _AdminSignInCard({
    required this.signingIn,
    required this.error,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: Color(0x45061120),
          blurRadius: 44,
          offset: Offset(0, 20),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AdminColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: AdminColors.primary,
            size: 27,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Accès à l’administration',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AdminColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Seuls les comptes explicitement autorisés peuvent consulter et traiter les demandes.',
          style: TextStyle(color: AdminColors.muted, height: 1.5),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEFEC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: AdminColors.danger),
            ),
          ),
        ],
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('admin-google-sign-in'),
            onPressed: signingIn ? null : onSignIn,
            icon: signingIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login_rounded),
            label: Text(signingIn ? 'Connexion…' : 'Continuer avec Google'),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: AdminColors.muted,
              size: 16,
            ),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Accès contrôlé par les politiques Supabase.',
                style: TextStyle(color: AdminColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
