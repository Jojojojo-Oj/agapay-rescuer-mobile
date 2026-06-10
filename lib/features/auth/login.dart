import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/notification_service.dart';
import '../../core/widgets/custom_text_input.dart';
import '../home/navigation_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'Unable to retrieve user after sign in',
        );
      }

      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final roles = (userData['roles'] ?? '').toString().toLowerCase();

      if (roles != 'rescuer' && roles != 'rescuers' && !roles.contains('rescuer')) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showError('Access denied: account is not a rescuer');
        return;
      }

      try {
        final fcmToken = await NotificationService().init();
        if (fcmToken != null) {
          await FirebaseFirestore.instance.collection('Users').doc(uid).set(
            {'fcmToken': fcmToken},
            SetOptions(merge: true),
          );

          await FirebaseFirestore.instance.collection('fcmTokens').doc(uid).set({
            'uid': uid,
            'token': fcmToken,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Notification init failed: $e');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RescuerNavigationShell(userData: userData),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(e.message ?? 'Login failed');
    } catch (_) {
      if (!mounted) return;
      _showError('Unexpected error occurred');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(208, 42, 39, 1),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rescuer Login',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Enter your credentials to access your dashboard',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),
                Image.asset('assets/images/logo.png', width: 150),
                const SizedBox(height: 20),
                SizedBox(
                  width: 330,
                  child: CustomTextInput(emailController, 'Enter Email', false),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 330,
                  child: CustomTextInput(passwordController, 'Enter Password', true),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: 330,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(208, 42, 39, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Sign In',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
