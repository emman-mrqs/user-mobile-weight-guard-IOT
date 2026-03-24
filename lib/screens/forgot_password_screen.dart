import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // This boolean controls which step we are on
  bool _isCodeSent = false; 

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _sendCode() {
    // In the future, call your backend here to send the email
    if (_emailController.text.isNotEmpty) {
      setState(() {
        _isCodeSent = true;
      });
    }
  }

  void _verifyCode() {
    // In the future, call your backend to verify the 6-digit code
    if (_codeController.text.length == 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verification successful. Please login.")),
      );
      // Navigate back to the Login Screen
      Navigator.pop(context);
    }
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
                        color: const Color(0xFF1A7B51).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        // Switch icon based on the step
                        _isCodeSent ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
                        size: 45,
                        color: const Color(0xFF4ADE80),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isCodeSent ? 'Check Your Email' : 'Forgot Password',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCodeSent 
                          ? 'Enter the 6-digit code sent to\n${_emailController.text}'
                          : 'Enter your email address to receive\na password reset code.',
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
                          if (!_isCodeSent) ...[
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
                                onPressed: _sendCode,
                                style: _buttonStyle(),
                                child: const Text(
                                  'Send Code',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ] 
                          
                          // --- STEP 2: CODE INPUT ---
                          else ...[
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
                                onPressed: _verifyCode,
                                style: _buttonStyle(),
                                child: const Text(
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
                                    _isCodeSent = false; // Go back to email step
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
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, letterSpacing: 2.0), // Wider spacing looks good for codes
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        counterText: "", // Hides the "0/6" character counter beneath the field
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 0),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
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
          borderSide: const BorderSide(color: const Color(0xFF1A7B51)),
        ),
      ),
    );
  }
}