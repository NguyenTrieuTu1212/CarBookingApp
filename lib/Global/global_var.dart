import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

String userName ="";
String userPhone="";
String userID = FirebaseAuth.instance.currentUser!.uid;

String geoapifyApiKey = '73e3bc86fab3490f8239f304f3145985';
String vietmapApiKey = "9f7a0d8e4b1b62942921a791702e132d3a22f4daa5d54b41";
//AIzaSyAI9kPkskayYti5ttrZL_UfBlL3OkMEbvs
//AIzaSyDuDxriw8CH8NbVLiXtKFQ2Nb64AoRSdyg
String googleMapKey ="AIzaSyBbMNaYG54dqrE4TH03TETRp7MyXOCuuu8";
String googeMapAPITest ="AIzaSyAI9kPkskayYti5ttrZL_UfBlL3OkMEbvs";
String serverKeyFCM ="key=AAAAHZmFRgM:APA91bEHPfHD4iZJJW485-somdn5EhzldAJ-Li5MhMC5YTcBVLWboNlL5fBv6T0kv7uHi-t0WkH9Shb-jTNJibEqoV9aow3ZOgY3NQnYYRh4r2CygZjjQPt8Owm4BhKf7lrJQiFwHGx7";

//AIzaSyDuDxriw8CH8NbVLiXtKFQ2Nb64AoRSdyg

const CameraPosition googleInitPos = CameraPosition(
  target: LatLng(37.42796133580664, -122.085749655962),
  zoom: 14.4746,
);