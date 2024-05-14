


import 'dart:convert';

import 'package:app_car_booking/Global/global_var.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../AppInfor/app_info.dart';

class PushNotificationService{
  static sendNotificationToSelectedDriver(String deviceToken, BuildContext context,String tripID) async {
    String dropOffDestinationAddress = Provider.of<AppInfor>(context, listen: false).dropOffAddress!.placeName.toString();
    String pickUpAddress = Provider.of<AppInfor>(context, listen: false).pickUpAddress!.placeName.toString();

    Map<String, String> headerNotificationMap =
    {
      "Content-Type": "application/json",
      "Authorization": serverKeyFCM,
    };

    Map titleBodyNotificationMap =
    {
      "title": "NET TRIP REQUEST from $userName",
      "body": "PickUp Location: $pickUpAddress \nDropOff Location: $dropOffDestinationAddress",
    };

    Map dataMapNotification =
    {
      "click_action": "FLUTTER_NOTIFICATION_CLICK",
      "id": "1",
      "status": "done",
      "tripID": tripID,
    };

    Map bodyNotificationMap =
    {
      "notification": titleBodyNotificationMap,
      "data": dataMapNotification,
      "priority": "high",
      "to": deviceToken,
    };
    await http.post(
      Uri.parse("https://fcm.googleapis.com/fcm/send"),
      headers: headerNotificationMap,
      body: jsonEncode(bodyNotificationMap),
    );
  }
}