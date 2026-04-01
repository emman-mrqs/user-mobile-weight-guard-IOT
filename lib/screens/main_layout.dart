import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mobile_notification_service.dart';
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
  bool _showCoachOverlay = true;
  int _coachStep = 0;

  static const List<_CoachStep> _coachSteps = <_CoachStep>[
    _CoachStep(
      title: 'Dashboard Home',
      description: 'See your operational summary, task progress, and quick status insights at a glance.',
      icon: Icons.space_dashboard_rounded,
      navIndex: 0,
    ),
    _CoachStep(
      title: 'Map Screen',
      description: 'Use the Trips map to monitor live vehicle movement, route direction, and cargo incidents.',
      icon: Icons.map_rounded,
      navIndex: 2,
    ),
    _CoachStep(
      title: 'Task Workflow',
      description: 'Manage assigned tasks, start checkpoints, and track each delivery operation step-by-step.',
      icon: Icons.task_alt_rounded,
      navIndex: 1,
    ),
    _CoachStep(
      title: 'Activity History',
      description: 'Review weight changes, overload alerts, and cargo loss events with detailed timestamps.',
      icon: Icons.monitor_heart_rounded,
      navIndex: 3,
    ),
    _CoachStep(
      title: 'Profile & Security',
      description: 'Update your password, manage your account information, and logout securely when needed.',
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
    // Start real-time notification polling when user enters the app
    MobileNotificationService.startPeriodicPolling();
  }

  @override
  void dispose() {
    // Stop polling when user leaves the app or logs out
    MobileNotificationService.stopPeriodicPolling();
    super.dispose();
  }

  void _dismissCoach() {
    setState(() {
      _showCoachOverlay = false;
    });
  }

  void _selectCoachStepByNavIndex(int index) {
    final int stepIndex = _coachSteps.indexWhere((step) => step.navIndex == index);
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
      _dismissCoach();
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF051E16),
        extendBody: true, // Crucial: lets the list scroll behind the floating nav bar
        
        body: Stack(
          children: <Widget>[
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            if (_showCoachOverlay)
              CoachGuideOverlay(
                title: _coachSteps[_coachStep].title,
                description: _coachSteps[_coachStep].description,
                icon: _coachSteps[_coachStep].icon,
                currentStep: _coachStep,
                totalSteps: _coachSteps.length,
                onNext: _nextCoachStep,
                onSkip: _dismissCoach,
              ),
          ],
        ),
        
        // Injecting your reusable widget here
        bottomNavigationBar: ModernBottomNav(
          currentIndex: _currentIndex,
          coachTipText: _showCoachOverlay
              ? 'Tip ${_coachStep + 1}/${_coachSteps.length} • ${_coachSteps[_coachStep].title}'
              : null,
          onTap: (index) {
            if (_showCoachOverlay) {
              _selectCoachStepByNavIndex(index);
              return;
            }
            setState(() {
              _currentIndex = index;
            });
          },
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