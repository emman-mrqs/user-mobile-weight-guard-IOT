import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/mobile_auth_service.dart';
import 'forgot_password_screen.dart';
import 'main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // --- FIX: ADDED MISSING FOCUS NODES ---
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  Future<void> _login() async {
    if (_isLoading) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Email and password are required.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await MobileAuthService.login(email: email, password: password);

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    // These will now dispose correctly without breaking the app!
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
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
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A7B51).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        size: 45,
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'WeighGuard',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Real-Time Cargo & Vehicle Monitoring',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 48),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C2B22),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          const Text(
                            'Email',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hintText: 'Enter your email or username',
                            icon: Icons.email_outlined,
                            focusNode: _emailFocus, // Passed the focus node
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            'Password',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _passwordController,
                            hintText: 'Enter your password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            focusNode: _passwordFocus, // Passed the focus node
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFEF5350),
                                fontSize: 13,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 24),
                          ],

                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A7B51),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
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

  // --- FIX: Updated this widget to accept the FocusNode ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    FocusNode? focusNode, 
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode, // Assign it here
      obscureText: isPassword && _obscurePassword,
      style: const TextStyle(color: Colors.white),
      onTapOutside: (PointerDownEvent event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
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