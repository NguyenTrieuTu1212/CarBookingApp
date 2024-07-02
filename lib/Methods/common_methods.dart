import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:app_car_booking/AppInfor/app_info.dart';
import 'package:app_car_booking/Global/global_var.dart';
import 'package:app_car_booking/Models/direction_detail_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../Models/AddressModel.dart';




const int level1 = 2;
const int level2 = 5;
const int level3 = 100;

const int costInLevel1 = 12000;
const int costInLevel2 = 3800;
const int costInLevel3 = 4000;

const double discount =0.2;

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

  static String convertDoubleToTimeFormat(double timeRequireFormat) {
    // Chuyển đổi và làm tròn phần nguyên của thời gian
    int totalMinutes = (timeRequireFormat / 60).round();

    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;

    String hoursStr = hours > 0 ? "$hours Hour" : "";
    String minutesStr = minutes > 0 ? "$minutes Minute" : "";

    return "$hoursStr$minutesStr".trim();
  }

  static String convertIntToTimeFormat(int timeRequireFormat) {
    int totalMinutes = (timeRequireFormat / 1000 / 60).round();

    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;

    if(hours > 0){
      String hoursStr = hours > 0 ? "$hours H" : "";
      String minutesStr = minutes > 0 ? "$minutes m" : "";
      return "$hoursStr $minutesStr".trim();
    }else{
      String hoursStr = hours > 0 ? "$hours Hour" : "";
      String minutesStr = minutes > 0 ? "$minutes minute" : "";
      return "$hoursStr$minutesStr".trim();
    }

  }

  static String convertDistance(int distance) {
    if (distance >= 1000) {
      double distanceInKm = distance / 1000.0;
      return "${distanceInKm.toStringAsFixed(1)} Km";
    } else {
      return "$distance m";
    }
  }

  static Future<String> convertGeoGraphicsIntoAddressUseAPIVietMap(Position position, BuildContext context) async {
    String address = "";
    String apiGeoUrl = "https://maps.vietmap.vn/api/reverse/v3?apikey=$vietmapApiKey&lng=${position.longitude}&lat=${position.latitude}";

    var response = await http.get(Uri.parse(apiGeoUrl));

    if (response.statusCode == 200) {
      var responseFromApi = json.decode(response.body);

      if (responseFromApi != null && responseFromApi.isNotEmpty) {
        var result = responseFromApi[0];  // Vì kết quả trả về là một list nên lấy phần tử đầu tiên

        address = result["display"];
        AddressModel model = AddressModel();
        model.addressHumman = address;
        model.placeName = result["name"] ?? address;
        model.latPosition = position.latitude;
        model.longPosition = position.longitude;
        Provider.of<AppInfor>(context, listen: false).updatePickUpAddress(model);
      }
    } else {
      address = "Error";
    }

    return address;
  }

  static Future<String> convertGeoGraphicsIntoAddress(Position position, BuildContext context) async {
    String address = "";
    String apiGeoUrl = "https://api.geoapify.com/v1/geocode/reverse?lat=${position.latitude}&lon=${position.longitude}&apiKey=$geoapifyApiKey";

    var response = await http.get(Uri.parse(apiGeoUrl));

    if (response.statusCode == 200) {
      var responseFromApi = json.decode(response.body);

      if (responseFromApi["features"] != null && responseFromApi["features"].isNotEmpty) {
        var result = responseFromApi["features"][0]["properties"];

        address = result["formatted"];
        AddressModel model = AddressModel();
        model.addressHumman = address;
        model.placeName = result["name"] ?? address;
        model.latPosition = position.latitude;
        model.longPosition = position.longitude;
        Provider.of<AppInfor>(context, listen: false).updatePickUpAddress(model);
      }
    } else {
      address = "Error";
    }

    return address;
  }

  static Future<DirectionDetailModel> getDirectionDetail(LatLng source, LatLng destination) async {
    String urlAPIDirectionDetail = "https://maps.vietmap.vn/api/route?api-version=1.1&point=${source.latitude},${source.longitude}&point=${destination.latitude},${destination.longitude}&apikey=$vietmapApiKey";
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
    return detailModels;
  }

  /*static Future<DirectionDetailModel> getDirectionDetail(LatLng source, LatLng destination) async {
    String urlAPIDirectionDetail = "https://api.geoapify.com/v1/routing?waypoints=${source.latitude},${source.longitude}|${destination.latitude},${destination.longitude}&mode=drive&apiKey=$geoapifyApiKey";
    var responseFromApiDirectionDetail = await http.get(Uri.parse(urlAPIDirectionDetail));

    DirectionDetailModel detailModels = DirectionDetailModel();

    if(responseFromApiDirectionDetail.statusCode == 200){
      var responseData = json.decode(responseFromApiDirectionDetail.body);
      detailModels.distanceText = responseData["features"][0]["properties"]["distance"];
      detailModels.digitDistance = responseData["features"][0]["properties"]["distance"];
      detailModels.timeDurationText =  responseData["features"][0]["properties"]["time"];
      detailModels.digitTimeDuration = responseData["features"][0]["properties"]["time"];
      //detailModels.encodedPoint = responseData["features"][0]["geometry"]["coordinates"];
      List coordinates = responseData["features"][0]["geometry"]["coordinates"][0];

      // Chuyển đổi thành danh sách PointLatLng
      List<PointLatLng> listLatLngPolylinePoints = coordinates.map((coordinate) {
        return PointLatLng(coordinate[1], coordinate[0]);
      }).toList();
      detailModels.listLatLngPolylinePoints = listLatLngPolylinePoints;
    }
    return detailModels;
  }*/

  /*static Future<String> convertGeoGraphicsIntoAddress(Position position,BuildContext context) async{
    String address = "";
    // another key API
    String apiGeoUrl = "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$googeMapAPITest";
    var responseFromApi = await sendRequestAPI(apiGeoUrl);
    if(responseFromApi != "Error"){
      address = responseFromApi["results"][0]["formatted_address"];
      AddressModel model =  AddressModel();
      model.addressHumman = address;
      model.placeName = address;
      model.latPosition = position.latitude;
      model.longPosition = position.longitude;
      Provider.of<AppInfor>(context, listen: false).updatePickUpAddress(model);
    }
    return address;
  }*/

  /*static Future<DirectionDetailModel> getDirectionDetail(LatLng source, LatLng destination) async{

    String urlAPIDirectionDetail = "https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&key=$googeMapAPITest";
    var responseFromApiDirectionDetail = await sendRequestAPI(urlAPIDirectionDetail);
    DirectionDetailModel detailModels = DirectionDetailModel();
    if(responseFromApiDirectionDetail != "Error"){
      detailModels.distanceText = responseFromApiDirectionDetail["routes"][0]["legs"][0]["distance"]["text"];
      detailModels.digitDistance = responseFromApiDirectionDetail["routes"][0]["legs"][0]["distance"]["value"];
      detailModels.timeDurationText =  responseFromApiDirectionDetail["routes"][0]["legs"][0]["duration"]["text"];
      detailModels.digitTimeDuration = responseFromApiDirectionDetail["routes"][0]["legs"][0]["duration"]["value"];
      detailModels.encodedPoint = responseFromApiDirectionDetail["routes"][0]["overview_polyline"]["points"];
    }
    return detailModels;
  }
*/
  // (0,2] km => Price : 12000
  // [3,5] Km => Price : 3800vnd/1km
  // (5,infinity) km => Price : 3100vnd/1km
  static String convertFromKilometersToMoney(int amountKilometers){
    int moneyHaveToPay = 0;
    int km = amountKilometers~/1000.0;
    int m = amountKilometers%1000 ;
    String formattedAmount = '';
    String result = '';
    if(km <= level1){
      moneyHaveToPay = costInLevel1 + calculateTheNumberOfMetersLeftOver(m,level1);
    }else
    {
      if(km <= level2){
        moneyHaveToPay = costInLevel1 + (km - level1) * costInLevel2 + calculateTheNumberOfMetersLeftOver(m, costInLevel2);
      }else{
        moneyHaveToPay = costInLevel1 + (level2 - level1) * costInLevel2 + (km - level2) * costInLevel3 + calculateTheNumberOfMetersLeftOver(m, costInLevel3);
        if(km > 100) moneyHaveToPay = (moneyHaveToPay * (1-discount)).toInt();
      }
    }
    formattedAmount = moneyHaveToPay.toString();
    while (formattedAmount.length > 3) {
      result = '.${formattedAmount.substring(formattedAmount.length - 3)}$result';
      formattedAmount = formattedAmount.substring(0, formattedAmount.length - 3);
    }
    result = formattedAmount + result;

    return result;
  }

  static int calculateTheNumberOfMetersLeftOver(int meters,int cost){
    /*double m = meters/1000.0;
    double costToPay = m * cost;*/
    return ((meters/1000.0) * cost).toInt();
  }
}