import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cases_screen.dart';
import 'emergency_scan_screen.dart';
import 'map_screen.dart';
import 'rescuer_home_screen.dart';
import 'settings_screen.dart';

class RescuerNavigationShell extends StatefulWidget {
  final Map<String, dynamic> userData;

  const RescuerNavigationShell({super.key, required this.userData});

  @override
  State<RescuerNavigationShell> createState() => _RescuerNavigationShellState();
}

class _RescuerNavigationShellState extends State<RescuerNavigationShell> {
  int _currentIndex = 0;

  late final List<String> _titles;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _titles = const ['List', 'Map', 'SOS Beacon Scanner', 'Cases', 'Settings'];
    _screens = [
      RescuerHomeScreen(userData: widget.userData, embedded: true),
      MapScreen(embedded: true, userData: widget.userData),
      const EmergencyScanScreen(),
      CasesScreen(userData: widget.userData),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        title: Text(
          _titles[_currentIndex],
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined),
                activeIcon: Icon(Icons.list_alt),
                label: 'List',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner_outlined),
                activeIcon: Icon(Icons.qr_code_scanner),
                label: 'Scan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.folder_open_outlined),
                activeIcon: Icon(Icons.folder_open),
                label: 'Cases',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
