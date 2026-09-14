import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';
import '../../features/auth/bloc/auth_state.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Drawer();
        }

        final user = state.user;
        final role = (user['role'] as String?) ?? state.activeMode;

        final roleLabel = role == 'driver'
            ? 'roles.driver'.tr()
            : (role == 'business_admin' ? 'Administrateur' : 'roles.parent'.tr());

        final roleBadgeColor = role == 'driver'
            ? const Color(0xFFF59E0B) // Amber
            : const Color(0xFF38BDF8); // Sky blue

        return Drawer(
          child: Column(
            children: [
              // 1. Premium User Accounts Header
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: const Color(0xFF1E293B),
                  child: Text(
                    (user['name'] as String? ?? 'U').isNotEmpty
                        ? (user['name'] as String)[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                accountName: Text(
                  user['name'] as String? ?? 'Utilisateur',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                accountEmail: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user['phone'] as String? ?? user['email'] as String? ?? '',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleBadgeColor.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: roleBadgeColor.withAlpha(120), width: 1),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          color: roleBadgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Language Selector
              ListTile(
                leading: const Icon(Icons.language, color: Color(0xFF475569)),
                title: Text('common.language'.tr()),
                subtitle: Text(
                  context.locale.languageCode == 'ar'
                      ? 'العربية'
                      : (context.locale.languageCode == 'en' ? 'English' : 'Français'),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _showLanguageDialog(context),
              ),

              const Spacer(),
              const Divider(),

              // 4. Logout Action with Confirmation
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      'common.logout'.tr(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _showLogoutConfirmation(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('common.language'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Français'),
                trailing: context.locale.languageCode == 'fr'
                    ? const Icon(Icons.check, color: Color(0xFF0284C7))
                    : null,
                onTap: () {
                  context.setLocale(const Locale('fr'));
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('العربية'),
                trailing: context.locale.languageCode == 'ar'
                    ? const Icon(Icons.check, color: Color(0xFF0284C7))
                    : null,
                onTap: () {
                  context.setLocale(const Locale('ar'));
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('English'),
                trailing: context.locale.languageCode == 'en'
                    ? const Icon(Icons.check, color: Color(0xFF0284C7))
                    : null,
                onTap: () {
                  context.setLocale(const Locale('en'));
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('common.logout_confirm_title'.tr()),
          content: Text('common.logout_confirm_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext); // close dialog
                Navigator.pop(context); // close drawer
                context.read<AuthBloc>().add(LogoutRequested());
              },
              child: Text('common.logout'.tr()),
            ),
          ],
        );
      },
    );
  }
}
