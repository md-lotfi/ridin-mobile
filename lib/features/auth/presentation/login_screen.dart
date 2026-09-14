import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/ridin_logo.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'parent_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final login = _loginController.text.trim();
    final password = _passwordController.text.trim();

    if (login.isEmpty || password.isEmpty) return;

    context.read<AuthBloc>().add(LoginSubmitted(login: login, password: password));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            AppSnackBar.showError(context, state.error);
          }
        },
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Language Selector
                Align(
                  alignment: Alignment.topRight,
                  child: DropdownButton<Locale>(
                    value: context.locale,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: Locale('fr'), child: Text('Français 🇫🇷')),
                      DropdownMenuItem(value: Locale('en'), child: Text('English 🇬🇧')),
                      DropdownMenuItem(value: Locale('ar'), child: Text('العربية 🇩🇿')),
                    ],
                    onChanged: (newLocale) {
                      if (newLocale != null) {
                        context.setLocale(newLocale);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Official Ridin Brand Icon
                const Center(
                  child: RidinLogoIcon(size: 84),
                ),
                const SizedBox(height: 24),

                Text(
                  'app_name'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'login.subtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 36),

                // Input fields
                TextField(
                  controller: _loginController,
                  decoration: InputDecoration(
                    labelText: 'login.email_or_phone'.tr(),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'login.password'.tr(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;

                    return ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('login.submit'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Registration Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Nouveau sur Ridin ? ',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ParentRegisterScreen()),
                        );
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text(
                        'Créer un compte Parent',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
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
    );
  }
}
