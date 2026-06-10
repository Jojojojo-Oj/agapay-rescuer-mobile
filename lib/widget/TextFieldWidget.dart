// Deprecated path. Bridge to core/widgets/custom_text_input.dart
import 'package:flutter/material.dart';
import '../core/widgets/custom_text_input.dart';

class CustomTextinput extends StatelessWidget {
  const CustomTextinput(this.txtfController, this.hinttxt, this.psfl,
      {super.key});

  final TextEditingController txtfController;
  final String hinttxt;
  final bool psfl;

  @override
  Widget build(BuildContext context) {
    return CustomTextInput(txtfController, hinttxt, psfl);
  }
}