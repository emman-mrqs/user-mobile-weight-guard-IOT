// import 'package:flutter/material.dart';
// import '../screens/login_screen.dart';

// // Create a quick placeholder for the dashboard so the router doesn't crash
// class DashboardPlaceholder extends StatelessWidget {
//   const DashboardPlaceholder({super.key});
//   @override
//   Widget build(BuildContext context) => const Scaffold(
//     backgroundColor: Color(0xFF020617), 
//     body: Center(child: Text('Dashboard Route Active', style: TextStyle(color: Colors.white))),
//   );
// }

// class AppRouter {
//   static const String loginRoute = '/';
//   static const String dashboardRoute = '/dashboard';

//   static Route<dynamic> generateRoute(RouteSettings settings) {
//     switch (settings.name) {
//       case loginRoute:
//         return MaterialPageRoute(builder: (_) => const LoginScreen());
//       case dashboardRoute:
//         return MaterialPageRoute(builder: (_) => const DashboardPlaceholder());
//       default:
//         return MaterialPageRoute(
//           builder: (_) => Scaffold(
//             body: Center(child: Text('No route defined for ${settings.name}')),
//           ),
//         );
//     }
//   }
// }