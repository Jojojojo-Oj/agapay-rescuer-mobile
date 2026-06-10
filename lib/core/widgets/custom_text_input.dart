import 'package:flutter/material.dart';

class CustomTextInput extends StatelessWidget {
  const CustomTextInput(this.controller, this.hintText, this.obscure,
      {super.key});

  final TextEditingController controller;
  final String hintText;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black,
      ),
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.grey, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color.fromRGBO(19, 37, 64, 1), width: 1.5),
        ),
        hintText: hintText,
      ),
    );
  }
}
