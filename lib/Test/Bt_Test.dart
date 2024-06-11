import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Models/direction_detail_model.dart';

class CustomButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String buttonText;

  const CustomButton({
    required this.onPressed,
    required this.buttonText,
    Key? key,
  }) : super(key: key);

  @override
  _CustomButtonState createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _isPressed = !_isPressed; // Toggle the _isPressed variable
        });
      },
      child: Text(
        widget.buttonText,
        style: TextStyle(
          color: _isPressed ? Colors.red : Colors.black, // Change text color based on _isPressed
        ),
      ),
    );
  }
}
