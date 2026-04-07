import 'package:flutter/material.dart';
import 'package:mobile/widget/navbar.dart';

import '../services/app_tab_service.dart';
import '../services/auth_session_service.dart';
import '../services/mobile_auth_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _status = '';
  bool _profileLoaded = false;

  final TextEditingController _currentPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isChangingPassword = false;
  bool _isResettingCoachGuide = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
  }

  Future<void> _loadCurrentUserProfile() async {
    final profile = await AuthSessionService.getCurrentUserProfile();

    if (!mounted) {
      return;
    }

    setState(() {
      _firstName = profile['firstName'] ?? '';
      _lastName = profile['lastName'] ?? '';
      _email = profile['email'] ?? '';
      _status = profile['status'] ?? '';
      _profileLoaded = true;
    });
  }

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  String get _initials {
    final String firstInitial = _firstName.isNotEmpty ? _firstName[0] : 'U';
    final String lastInitial = _lastName.isNotEmpty ? _lastName[0] : '';
    return '$firstInitial$lastInitial'.toUpperCase();
  }

  String get _fullName {
    final fullName = '$_firstName $_lastName'.trim();
    return fullName.isEmpty ? 'Unknown User' : fullName;
  }

  String get _roleBadge {
    if (_status.isEmpty) {
      return 'DRIVER';
    }

    return _status.toUpperCase();
  }

  String get _joinedAt {
    return _profileLoaded ? 'Authenticated Session' : 'Loading profile...';
  }

  bool get _mustChangePassword {
    return AuthSessionService.currentUserPasswordChangeNotifier.value;
  }

  void _confirmPasswordChange() {
    final String currentPass = _currentPassController.text.trim();
    final String newPass = _newPassController.text.trim();
    final String confirmPass = _confirmPassController.text.trim();

    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields.')),
      );
      return;
    }

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters.')),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password and confirm password do not match.')),
      );
      return;
    }

    _showConfirmPasswordDialog();
  }

  void _showConfirmPasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C2B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Confirm Password Change',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Are you sure you want to update your password?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _applyPasswordChange();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A7B51),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyPasswordChange() async {
    if (_isChangingPassword) {
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      await MobileAuthService.changePassword(
        currentPassword: _currentPassController.text.trim(),
        newPassword: _newPassController.text.trim(),
        confirmPassword: _confirmPassController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully. Redirecting to Dashboard.')),
      );

      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
      FocusScope.of(context).unfocus();

      AppTabService.selectTab(0);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    if (_mustChangePassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please change your password before logging out.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C2B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Do you want to logout from this account?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                await AuthSessionService.clearSession();
                if (!context.mounted) {
                  return;
                }

                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F1D1D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showResetCoachGuideDialog() {
    if (_mustChangePassword) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C2B22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Show Coach Guide Again',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'This will show the onboarding coach guide again the next time you open the main app screen.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: _isResettingCoachGuide
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _resetCoachGuide();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A7B51),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset Guide'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetCoachGuide() async {
    if (_isResettingCoachGuide) {
      return;
    }

    setState(() {
      _isResettingCoachGuide = true;
    });

    try {
      await AuthSessionService.resetCoachOverlaySeen();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coach guide reset. It will appear again on next app open.'),
          backgroundColor: Color(0xFF166534),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reset coach guide. Please try again.'),
          backgroundColor: Color(0xFF991B1B),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResettingCoachGuide = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF051E16),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppNavbar(
                title: 'Settings',
                subtitle: 'Profile and account actions',
              ),
              const SizedBox(height: 18),
              if (_mustChangePassword) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F1D1D).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.30)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Password change required',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Your account must change its password before you can continue to other parts of the app. Stay here and complete the password update to unlock navigation.',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2B22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: <Widget>[
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A7B51).withValues(alpha: 0.20),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.40)),
                          ),
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A7B51),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFF86EFAC).withValues(alpha: 0.45)),
                            ),
                            child: Text(
                              _roleBadge,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _email.isEmpty ? 'No email found' : _email,
                            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _joinedAt,
                            style: TextStyle(color: Colors.white54, fontSize: 11.8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2B22),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Change Password',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    _PasswordField(
                      label: 'Current Password',
                      controller: _currentPassController,
                      obscureText: _obscureCurrent,
                      onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    const SizedBox(height: 10),
                    _PasswordField(
                      label: 'New Password',
                      controller: _newPassController,
                      obscureText: _obscureNew,
                      onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    const SizedBox(height: 10),
                    _PasswordField(
                      label: 'Confirm Password',
                      controller: _confirmPassController,
                      obscureText: _obscureConfirm,
                      onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isChangingPassword ? null : _confirmPasswordChange,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A7B51),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isChangingPassword
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _mustChangePassword
                                    ? 'Update Password to Unlock App'
                                    : 'Confirm Password Change',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (!_mustChangePassword) ...<Widget>[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isResettingCoachGuide ? null : _showResetCoachGuideDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C2B22),
                      foregroundColor: const Color(0xFF86EFAC),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.white12),
                      ),
                    ),
                    icon: _isResettingCoachGuide
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF86EFAC)),
                            ),
                          )
                        : const Icon(Icons.school_rounded, size: 18),
                    label: Text(
                      _isResettingCoachGuide ? 'Resetting Guide...' : 'Show Coach Guide Again',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7F1D1D).withValues(alpha: 0.65),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text(
                      'Logout',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleObscure;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscureText,
    required this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF08241B),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4ADE80), width: 1.1),
            ),
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: Colors.white60,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
