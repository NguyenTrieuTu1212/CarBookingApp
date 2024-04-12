import 'dart:convert';
import 'dart:ui';
import 'package:app_car_booking/AppInfor/app_info.dart';
import 'package:app_car_booking/Global/global_var.dart';
import 'package:app_car_booking/Models/direction_detail_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../Models/AddressModel.dart';

class CommonMethods{
  checkConnectivity(BuildContext context) async{
    var connectionResult = await Connectivity().checkConnectivity();
    /*if(connectionResult != ConnectivityResult.mobile && connectionResult != ConnectivityResult.wifi){
      if(context.mounted) return;
      DisplayBox(context, "Oh No !!!! ", "Connection errors!! Please check the connection",ContentType.warning);
    }*/
  }


  DisplaySnackBar(String message,BuildContext context){
    var snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  DisplayBox(BuildContext context,String titleOfBox, String messageOfBox, ContentType contentTypeOfBox){
    final materialBanner = MaterialBanner(
      elevation: 0,
      backgroundColor: Colors.transparent,
      forceActionsBelow: false,
      content: AwesomeSnackbarContent(
        title: titleOfBox,
        message: messageOfBox,
        contentType: contentTypeOfBox,
        inMaterialBanner: true,
      ),
      actions: const [SizedBox.shrink()],
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(materialBanner);
    Future.delayed(Duration(seconds: 3), () {
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
  }

  String extractContent(String inputString) {
    int startIndex = inputString.indexOf("[");
    int endIndex = inputString.indexOf("]");

    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return inputString.substring(endIndex + 1).trim();
    } else return "";
  }

  static String convertTimeFormat(String inputString){
    String timeConvert = "";

    for(int i=0;i<inputString.length;i++){
      List<String?> numbers = RegExp(r'\d+').allMatches(inputString).map((match) => match.group(0)).toList();

      if (numbers.length == 1) {
        if (inputString.contains("hour")) {
          return "${numbers[0]} h";
        }
        else {
          return "${numbers[0]} min";
        }
      }

      else if (numbers.length == 2) {
        return "${numbers[0]}h ${numbers[1]}min";
      }
      else {
        return "Invalid input";
      }
    }
    return timeConvert;
  }
  static sendRequestAPI(String apiUrl) async{
    http.Response reponseFromApi = await http.get(Uri.parse(apiUrl));
    try
    {
      if(reponseFromApi.statusCode == 200){
        String jsonData = reponseFromApi.body;
        var dataDecode = jsonDecode(jsonData);
        return dataDecode;
      }else{
        return "Error";
      }
    }
    catch(errMsg)
    {
      return "Error";
    }
  }

  static Future<String> convertGeoGraphicsIntoAddress(Position position,BuildContext context) async{
    String address = "";
    // another key API
    String apiGeoUrl = "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=AIzaSyDuDxriw8CH8NbVLiXtKFQ2Nb64AoRSdyg";
    var responseFromApi = await sendRequestAPI(apiGeoUrl);
    if(responseFromApi != "Error"){
      address = responseFromApi["results"][0]["formatted_address"];
      AddressModel model =  AddressModel();
      model.addressHumman = address;
      model.latPosition = position.latitude;
      model.longPosition = position.longitude;
      Provider.of<AppInfor>(context, listen: false).updatePickUpAddress(model);
    }
    return address;
  }


  static Future<DirectionDetailModel> getDirectionDetail(LatLng source, LatLng destination) async{

    String urlAPIDirectionDetail = "https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&key=$googeMapAPITest";
    var responseFromApiDirectionDetail = await sendRequestAPI(urlAPIDirectionDetail);
    DirectionDetailModel detailModels = DirectionDetailModel();
    if(responseFromApiDirectionDetail != "Error"){
      detailModels.distanceText = responseFromApiDirectionDetail["routes"][0]["legs"][0]["distance"]["text"];
      detailModels.digitDistance = responseFromApiDirectionDetail["routes"][0]["legs"][0]["distance"]["value"];
      detailModels.timeDurationText =  responseFromApiDirectionDetail["routes"][0]["legs"][0]["duration"]["text"];
      detailModels.digitTimeDuration = responseFromApiDirectionDetail["routes"][0]["legs"][0]["duration"]["value"];
    }
    return detailModels;
  }




}