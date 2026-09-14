import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/ridin_logo.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class ParentRegisterScreen extends StatefulWidget {
  const ParentRegisterScreen({super.key});

  @override
  State<ParentRegisterScreen> createState() => _ParentRegisterScreenState();
}

class _ParentRegisterScreenState extends State<ParentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    context.read<AuthBloc>().add(
          ParentRegisterSubmitted(
            name: name,
            phone: phone,
            password: password,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          AppSnackBar.showError(context, state.error);
        } else if (state is Authenticated) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
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
          ],
        ),
        body: SafeArea(
          bottom: true,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: RidinLogoIcon(size: 72),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Créer un Compte Parent',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Suivez le bus scolaire de vos enfants en toute sérénité',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 28),

                    // Nom complet
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nom & Prénom',
                        hintText: 'ex: Fatima Zohra Benali',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez renseigner votre nom complet';
                        }
                        if (value.trim().length < 3) {
                          return 'Le nom doit contenir au moins 3 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Téléphone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Numéro de Téléphone (+213)',
                        hintText: '0550 12 34 56',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez renseigner votre numéro de mobile';
                        }
                        final clean = value.replaceAll(' ', '');
                        final regExp = RegExp(r'^(0|\+213)[567][0-9]{8}$');
                        if (!regExp.hasMatch(clean)) {
                          return 'Numéro algérien invalide (ex: 0550123456 ou 06/07)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Mot de passe
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir un mot de passe';
                        }
                        if (value.length < 6) {
                          return 'Au moins 6 caractères requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Confirmation Mot de passe
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Bouton de soumission
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
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'S\'inscrire comme Parent',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        );
                      },
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
