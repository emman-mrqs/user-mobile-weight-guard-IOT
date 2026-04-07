import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_session_service.dart';
import '../services/app_tab_service.dart';
import '../services/mobile_activity_service.dart';
import '../services/mobile_notification_service.dart';
import '../services/mobile_task_service.dart';
import '../services/trip_overlay_service.dart';
import '../widget/bottom_nav.dart';
import '../widget/coach_guide_overlay.dart';
import 'dashboard_screen.dart';
import 'task_screen.dart';
import 'trip_screen.dart';
import 'activity_screen.dart';
import 'settings_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool _showCoachOverlay = false;
  int _coachStep = 0;
  bool _hideBottomNavForTrip = false;
  bool _forcePasswordChange =
      AuthSessionService.currentUserPasswordChangeNotifier.value;

  static const List<_CoachStep> _coachSteps = <_CoachStep>[
    _CoachStep(
      title: 'Dashboard Home',
      description:
          'See your operational summary, task progress, and quick status insights at a glance.',
      icon: Icons.space_dashboard_rounded,
      navIndex: 0,
    ),
    _CoachStep(
      title: 'Map Screen',
      description:
          'Use the Trips map to monitor live vehicle movement, route direction, and cargo incidents.',
      icon: Icons.map_rounded,
      navIndex: 2,
    ),
    _CoachStep(
      title: 'Task Workflow',
      description:
          'Manage assigned tasks, start checkpoints, and track each delivery operation step-by-step.',
      icon: Icons.task_alt_rounded,
      navIndex: 1,
    ),
    _CoachStep(
      title: 'Activity History',
      description:
          'Review weight changes, overload alerts, and cargo loss events with detailed timestamps.',
      icon: Icons.monitor_heart_rounded,
      navIndex: 3,
    ),
    _CoachStep(
      title: 'Profile & Security',
      description:
          'Update your password, manage your account information, and logout securely when needed.',
      icon: Icons.tune_rounded,
      navIndex: 4,
    ),
  ];

  // List of screens corresponding to the 5 tabs
  final List<Widget> _screens = [
    const DashboardScreen(), // Home (Index 0)
    const TaskScreen(),
    const TripScreen(),
    const ActivityScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AppTabService.currentIndexNotifier.addListener(_handleExternalTabChange);
    TripOverlayService.hideMainBottomNavNotifier.addListener(
      _handleTripOverlayChange,
    );
    AuthSessionService.currentUserPasswordChangeNotifier.addListener(
      _handlePasswordChangeRequirement,
    );
    // Start real-time notification polling when user enters the app
    MobileNotificationService.startPeriodicPolling();
    MobileTaskService.startPeriodicPolling();
    MobileActivityService.startPeriodicPolling();
    _loadCoachOverlayState();
    _loadPasswordChangeRequirement();
  }

  void _handleExternalTabChange() {
    final int nextIndex = AppTabService.currentIndexNotifier.value;
    if (!mounted || nextIndex == _currentIndex) {
      return;
    }

    if (_forcePasswordChange && nextIndex != 4) {
      if (_currentIndex != 4) {
        setState(() {
          _currentIndex = 4;
        });
      }
      AppTabService.selectTab(4);
      return;
    }

    setState(() {
      _currentIndex = nextIndex;
    });
  }

  void _handleTripOverlayChange() {
    final bool shouldHide = TripOverlayService.hideMainBottomNavNotifier.value;
    if (!mounted || shouldHide == _hideBottomNavForTrip) {
      return;
    }

    setState(() {
      _hideBottomNavForTrip = shouldHide;
    });
  }

  void _handlePasswordChangeRequirement() {
    final bool shouldForce =
        AuthSessionService.currentUserPasswordChangeNotifier.value;
    if (!mounted || shouldForce == _forcePasswordChange) {
      return;
    }

    setState(() {
      _forcePasswordChange = shouldForce;
      _syncForcedPasswordChangeTab();
    });
  }

  Future<void> _loadPasswordChangeRequirement() async {
    final bool shouldForce =
        await AuthSessionService.mustChangePasswordRequired();
    if (!mounted) {
      return;
    }

    setState(() {
      _forcePasswordChange = shouldForce;
      _syncForcedPasswordChangeTab();
    });
  }

  Future<void> _loadCoachOverlayState() async {
    final seen = await AuthSessionService.hasSeenCoachOverlay();
    if (!mounted) {
      return;
    }

    setState(() {
      _showCoachOverlay = !seen;
      _coachStep = 0;
    });
  }

  void _syncForcedPasswordChangeTab() {
    if (!_forcePasswordChange) {
      return;
    }

    _currentIndex = 4;
    AppTabService.selectTab(4);
  }

  @override
  void dispose() {
    AppTabService.currentIndexNotifier.removeListener(_handleExternalTabChange);
    TripOverlayService.hideMainBottomNavNotifier.removeListener(
      _handleTripOverlayChange,
    );
    AuthSessionService.currentUserPasswordChangeNotifier.removeListener(
      _handlePasswordChangeRequirement,
    );
    // Stop polling when user leaves the app or logs out
    MobileNotificationService.stopPeriodicPolling();
    MobileTaskService.stopPeriodicPolling();
    MobileActivityService.stopPeriodicPolling();
    super.dispose();
  }

  Future<void> _closeCoachToDashboard() async {
    await AuthSessionService.markCoachOverlaySeen();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = _forcePasswordChange ? 4 : 0;
      _showCoachOverlay = false;
      if (_forcePasswordChange) {
        AppTabService.selectTab(4);
      }
    });
  }

  void _selectCoachStepByNavIndex(int index) {
    if (_forcePasswordChange && index != 4) {
      return;
    }

    final int stepIndex = _coachSteps.indexWhere(
      (step) => step.navIndex == index,
    );
    if (stepIndex < 0) {
      return;
    }
    setState(() {
      _currentIndex = index;
      _coachStep = stepIndex;
    });
  }

  void _nextCoachStep() {
    if (_coachStep >= _coachSteps.length - 1) {
      _closeCoachToDashboard();
      return;
    }

    final int nextStep = _coachStep + 1;
    setState(() {
      _coachStep = nextStep;
      _currentIndex = _coachSteps[nextStep].navIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hideMainBottomNav = _forcePasswordChange
        ? true
        : _currentIndex == 2 && _hideBottomNavForTrip;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF051E16),
        extendBody:
            true, // Crucial: lets the list scroll behind the floating nav bar

        body: Stack(
          children: <Widget>[
            IndexedStack(index: _currentIndex, children: _screens),
            if (_showCoachOverlay)
              CoachGuideOverlay(
                title: _coachSteps[_coachStep].title,
                description: _coachSteps[_coachStep].description,
                icon: _coachSteps[_coachStep].icon,
                currentStep: _coachStep,
                totalSteps: _coachSteps.length,
                onNext: _nextCoachStep,
                onSkip: _closeCoachToDashboard,
              ),
          ],
        ),

        // Injecting your reusable widget here
        bottomNavigationBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final Animation<Offset> slide = Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: hideMainBottomNav
              ? const SizedBox.shrink(
                  key: ValueKey<String>('bottom-nav-hidden'),
                )
              : ModernBottomNav(
                  key: const ValueKey<String>('bottom-nav-visible'),
                  currentIndex: _currentIndex,
                  coachTipText: _showCoachOverlay
                      ? 'Tip ${_coachStep + 1}/${_coachSteps.length} • ${_coachSteps[_coachStep].title}'
                      : null,
                  onTap: (index) {
                    if (_forcePasswordChange && index != 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please change your password first.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      setState(() {
                        _currentIndex = 4;
                      });
                      AppTabService.selectTab(4);
                      return;
                    }

                    if (_showCoachOverlay) {
                      _selectCoachStepByNavIndex(index);
                      return;
                    }
                    setState(() {
                      _currentIndex = index;
                    });
                    AppTabService.selectTab(index);

                    if (index == 1) {
                      MobileTaskService.refreshCurrentTask(forceRefresh: true);
                    }
                  },
                ),
        ),
      ),
    );
  }
}

class _CoachStep {
  final String title;
  final String description;
  final IconData icon;
  final int navIndex;

  const _CoachStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.navIndex,
  });
}
