import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/home/navigation_shell.dart';
import 'login.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('Users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final roles = (userData['roles'] ?? '').toString().toLowerCase();

            if (roles == 'rescuer' || roles == 'rescuers' || roles.contains('rescuer')) {
              return RescuerNavigationShell(userData: userData);
            } else {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }
          },
        );
      },
    );
  }
}
