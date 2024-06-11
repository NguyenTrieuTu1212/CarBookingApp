

import 'dart:convert';
import 'dart:io';

import 'package:app_car_booking/Global/global_var.dart';
import 'package:app_car_booking/Methods/common_methods.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Models/direction_detail_model.dart';
import '../Widgets/loading_dialog.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:http/http.dart' as http;




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


  Future<void> getDirectionDetail() async {

    String urlAPIDirectionDetail = "https://maps.vietmap.vn/api/route?api-version=1.1&point=10.79631,106.70441&point=10.80174,106.71098&apikey=$vietmapApiKey";
    var responseFromApiDirectionDetail = await http.get(Uri.parse(urlAPIDirectionDetail));

    DirectionDetailModel detailModels = DirectionDetailModel();

    if (responseFromApiDirectionDetail.statusCode == 200) {
      var responseData = json.decode(responseFromApiDirectionDetail.body);
      if (responseData["paths"] != null && responseData["paths"].isNotEmpty) {
        var path = responseData["paths"][0];
        detailModels.digitDistance = path["distance"].toInt();
        detailModels.digitTimeDuration = path["time"];
        detailModels.encodedPoint = path["points"];
        //detailModels.listLatLngPolylinePoints = listLatLngPolylinePoints;
      }

    }
    print("Succesful");
    print(detailModels.digitTimeDuration);
    print(CommonMethods.convertIntToTimeFormat(detailModels.digitTimeDuration!));
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> listLatLngPolylinePoints =  polylinePoints.decodePolyline(detailModels!.encodedPoint!);
    print(listLatLngPolylinePoints);
  }

   /*Future<void> getDirectionDetail() async {
    //String apiKey = '73e3bc86fab3490f8239f304f3145985'; // Thay thế bằng API key thực của bạn
    //String urlAPIDirectionDetail = "https://api.geoapify.com/v1/routing?waypoints=${source.latitude},${source.longitude}|${destination.latitude},${destination.longitude}&mode=drive&apiKey=$apiKey";
     String urlAPIDirectionDetail = "https://api.geoapify.com/v1/routing?waypoints=10.8700083,106.8030533|10.85279065,106.77255839168646&mode=drive&apiKey=73e3bc86fab3490f8239f304f3145985";
     var responseFromApiDirectionDetail = await http.get(Uri.parse(urlAPIDirectionDetail));

    DirectionDetailModel detailModels = DirectionDetailModel();

    if(responseFromApiDirectionDetail.statusCode == 200){
      var responseData = json.decode(responseFromApiDirectionDetail.body);
      detailModels.distanceText = responseData["features"][0]["properties"]["distance"];
      detailModels.digitDistance = responseData["features"][0]["properties"]["distance"];
      detailModels.timeDurationText =  responseData["features"][0]["properties"]["time"];
      detailModels.digitTimeDuration = responseData["features"][0]["properties"]["time"];
      List coordinates = responseData["features"][0]["geometry"]["coordinates"][0];

      // Chuyển đổi thành danh sách PointLatLng
      List<PointLatLng> listLatLngPolylinePoints = coordinates.map((coordinate) {
        return PointLatLng(coordinate[1], coordinate[0]);
      }).toList();
      detailModels.listLatLngPolylinePoints = listLatLngPolylinePoints;
    }
    print("Succesful");
    print(detailModels.listLatLngPolylinePoints);
   }*/


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            onPressed: (){
              getDirectionDetail();
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
