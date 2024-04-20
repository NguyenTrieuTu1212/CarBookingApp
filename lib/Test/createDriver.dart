

import 'dart:io';

import 'package:app_car_booking/Methods/common_methods.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../Widgets/loading_dialog.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';





class AddDriver extends StatefulWidget {
  const AddDriver({super.key});

  @override
  State<AddDriver> createState() => _AddDriverState();
}

class _AddDriverState extends State<AddDriver> {


  CommonMethods commonMethods = new CommonMethods();


  regristerNewDriver() async{
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => LoadingDialog(messageText: "Registering your account ....."),
    );

    // Add user in firebase
    final User? userFirebase = (
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: "testDriver@gmail.com",
            password: "123456789"
        ).catchError((errMsg){
          Navigator.pop(context);
          String msgError  = commonMethods.extractContent(errMsg.toString());
          commonMethods.DisplayBox(context, "Error !!!!", msgError, ContentType.failure);
        })
    ).user;
    if(!context.mounted) return;
    Navigator.pop(context);

    DatabaseReference userRef = FirebaseDatabase.instance.ref().child("drivers").child(userFirebase!.uid);

    Map userDataMap = {
      "email": "testDriver@gmail.com",
      "name" : "usernameEditText.text.trim()",
      "phone": "123456789",
      "password" : "123456789",
      "blockedStatus" : "no",
    };
    userRef.set(userDataMap);
    commonMethods.DisplayBox(context, "Congratulations", "Registered successfully", ContentType.success);

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            onPressed: (){
              regristerNewDriver();
            },
            shape: CircleBorder(),
            child: const Icon(
              Icons.add,
              color: Colors.pinkAccent,
              size: 40,
            ),
          )
        ],
      ),
    );
  }
}
