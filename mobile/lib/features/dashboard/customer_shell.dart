import 'package:flutter/material.dart';
import '../../core/theme.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _PlaceholderScreen(label: 'My Service',    icon: Icons.wifi),
    _PlaceholderScreen(label: 'Fault History', icon: Icons.history),
    _PlaceholderScreen(label: 'Notifications', icon: Icons.notifications),
    _PlaceholderScreen(label: 'Settings',      icon: Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.wifi),                  label: 'My Service'),
          BottomNavigationBarItem(icon: Icon(Icons.history),               label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined),label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined),     label: 'Settings'),
        ],
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _PlaceholderScreen({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.primaryLight),
            const SizedBox(height: 16),
            Text(label, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            )),
          ],
        ),
      ),
    );
  }
}