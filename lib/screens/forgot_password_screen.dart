import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/mobile_auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1;
  bool _isSubmitting = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await MobileAuthService.sendForgotPasswordCode(email: email);
      if (!mounted) {
        return;
      }

      setState(() {
        _step = 2;
      });
      _showMessage('Verification code sent. Please check your email.', success: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim().toLowerCase();
    final code = _codeController.text.trim();

    if (code.length != 6) {
      _showMessage('Please enter the 6-digit code.');
      return;
    }

    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await MobileAuthService.verifyForgotPasswordCode(email: email, code: code);
      if (!mounted) {
        return;
      }

      setState(() {
        _step = 3;
      });
      _showMessage('Code verified. You can now set a new password.', success: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 8) {
      _showMessage('New password must be at least 8 characters.');
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('New password and confirm password do not match.');
      return;
    }

    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await MobileAuthService.resetForgotPassword(
        email: email,
        code: code,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      if (!mounted) {
        return;
      }

      _showMessage('Password reset successful. Please login.', success: true);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF166534) : const Color(0xFF991B1B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF051E16),
        // Add a transparent app bar with a back button
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- ICON AREA ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A7B51).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        // Switch icon based on the step
                        _step == 1
                            ? Icons.lock_reset_rounded
                            : _step == 2
                                ? Icons.mark_email_read_rounded
                                : Icons.verified_user_rounded,
                        size: 45,
                        color: const Color(0xFF4ADE80),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _step == 1
                          ? 'Forgot Password'
                          : _step == 2
                              ? 'Check Your Email'
                              : 'Set New Password',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _step == 1
                          ? 'Enter your email address to receive\na password reset code.'
                          : _step == 2
                              ? 'Enter the 6-digit code sent to\n${_emailController.text}'
                              : 'Create a strong new password for\n${_emailController.text}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // --- INPUT CARD ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C2B22),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          // --- STEP 1: EMAIL INPUT ---
                          if (_step == 1) ...[
                            const Text(
                              'Email',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _emailController,
                              hintText: 'Enter your email address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _sendCode,
                                style: _buttonStyle(),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Send Code',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                          ] 
                          
                          // --- STEP 2: CODE INPUT ---
                          else if (_step == 2) ...[
                            const Text(
                              'Verification Code',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _codeController,
                              hintText: 'Enter 6-digit code',
                              icon: Icons.pin_outlined,
                              keyboardType: TextInputType.number,
                              maxLength: 6, // Restricts input to 6 characters
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _verifyCode,
                                style: _buttonStyle(),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Verify Code',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.center,
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _step = 1;
                                    _codeController.clear();
                                  });
                                },
                                child: const Text(
                                  'Use a different email',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            ),
                          ],

                          // --- STEP 3: NEW PASSWORD ---
                          if (_step == 3) ...[
                            const Text(
                              'New Password',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _newPasswordController,
                              hintText: 'Enter new password (min 8 chars)',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscureNewPassword,
                              showPasswordToggle: true,
                              onTogglePasswordVisibility: () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Confirm Password',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _confirmPasswordController,
                              hintText: 'Re-enter your new password',
                              icon: Icons.lock_reset_rounded,
                              obscureText: _obscureConfirmPassword,
                              showPasswordToggle: true,
                              onTogglePasswordVisibility: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _resetPassword,
                                style: _buttonStyle(),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Reset Password',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                          ],

                        ],
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

  // Reused button style helper
  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1A7B51),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
    );
  }

  // Reused Text Field with slight tweaks for code input
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    bool obscureText = false,
    bool showPasswordToggle = false,
    VoidCallback? onTogglePasswordVisibility,
  }) {
    final bool isCodeField = maxLength == 6;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: Colors.white, letterSpacing: isCodeField ? 2.0 : 0.0),
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        counterText: "", // Hides the "0/6" character counter beneath the field
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 0),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: showPasswordToggle
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: onTogglePasswordVisibility,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF081F17),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A7B51)),
        ),
      ),
    );
  }
}