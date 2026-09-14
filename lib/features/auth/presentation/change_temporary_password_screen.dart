import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../data/auth_repository.dart';

class ChangeTemporaryPasswordScreen extends StatefulWidget {
  const ChangeTemporaryPasswordScreen({super.key});

  @override
  State<ChangeTemporaryPasswordScreen> createState() => _ChangeTemporaryPasswordScreenState();
}

class _ChangeTemporaryPasswordScreenState extends State<ChangeTemporaryPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = context.read<AuthRepository>();
      final result = await authRepo.changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
        confirmPassword: _confirmPasswordController.text.trim(),
      );

      if (!mounted) return;

      final message = result['message'] as String? ?? 'Mot de passe mis à jour avec succès !';
      AppSnackBar.showSuccess(context, message);

      // Refresh authentication state so AppRootView transitions to DriverCockpitScreen
      context.read<AuthBloc>().add(AuthCheckRequested());
    } on ApiException catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Une erreur inattendue est survenue.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _logout() {
    context.read<AuthBloc>().add(LogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _logout,
            icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF94A3B8)),
            label: const Text(
              'Déconnexion',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Security Shield Header Badge
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 38,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Sécurisation de votre Compte',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Explanatory Notice
                    Container(
                      padding: const EdgeInsetsDirectional.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF334155),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFF59E0B),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Votre compte a été initialisé avec un mot de passe temporaire. Pour des raisons de sécurité, veuillez définir votre mot de passe personnel afin d\'activer l\'accès au cockpit.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade300,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Current Temporary Password Field
                    _buildLabel('Mot de passe temporaire actuel (Code PIN)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: _buildInputDecoration(
                        hintText: 'Code PIN reçu de l\'école',
                        prefixIcon: Icons.lock_clock_outlined,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir votre mot de passe ou PIN temporaire';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // New Password Field
                    _buildLabel('Nouveau mot de passe personnel'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: _buildInputDecoration(
                        hintText: '6 caractères minimum',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 6) {
                          return 'Le mot de passe doit comporter au moins 6 caractères';
                        }
                        if (value.trim() == _currentPasswordController.text.trim()) {
                          return 'Le nouveau mot de passe doit être différent du mot de passe temporaire';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Confirm New Password Field
                    _buildLabel('Confirmer le nouveau mot de passe'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: _buildInputDecoration(
                        hintText: 'Répétez le mot de passe',
                        prefixIcon: Icons.check_circle_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (value) {
                        if (value != _newPasswordController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF0F172A),
                          disabledBackgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF0F172A),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded, size: 20, color: Color(0xFF0F172A)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Déverrouiller le Cockpit',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFFCBD5E1),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
    );
  }
}
