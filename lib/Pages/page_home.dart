
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:app_car_booking/Auth/login_screen.dart';
import 'package:app_car_booking/Methods/common_methods.dart';
import 'package:app_car_booking/Methods/manager_driver_methods.dart';
import 'package:app_car_booking/Methods/push_notification_service.dart';
import 'package:app_car_booking/Models/AddressModel.dart';
import 'package:app_car_booking/Models/direction_detail_model.dart';
import 'package:app_car_booking/Models/online_nearby_driver.dart';
import 'package:app_car_booking/Pages/trips_history_page.dart';
import 'package:app_car_booking/Widgets/info_dialog.dart';
import 'package:app_car_booking/Widgets/loading_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:restart_app/restart_app.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';
import '../AppInfor/app_info.dart';
import '../Global/global_var.dart';
import '../Global/trip_var.dart';
import '../Widgets/payment_dialog.dart';
import '../Widgets/text_widget.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {

  final Completer<GoogleMapController> googleMapCompleter = Completer<GoogleMapController>();
  CommonMethods commonMethods = new CommonMethods();
  GlobalKey<ScaffoldState> sKey = GlobalKey<ScaffoldState>();
  GoogleMapController? controllerGoogleMap;
  Position? currentPosOfUser;
  double serachContainerHeight = 276;


  // Select location pick up and drop off
  TextEditingController pickUpTextEditingController = TextEditingController();
  TextEditingController displayPickUpTextEditingController = TextEditingController();
  TextEditingController destinationTextEditingController = TextEditingController();
  TextEditingController displayDestinationTextEditingController = TextEditingController();
  List<Map<String,dynamic>> locationListDisplay = [];


  // Sliding Panel
  final PanelController _panelSearchLocationController = PanelController();
  final PanelController _panelBookCarController = PanelController();
  bool _isPanelDraggable = false;

  DirectionDetailModel? tripDirectionDetailModel;

  List<LatLng> listcoOrdinates = [];
  Set<Polyline> polylineSet ={};
  Set<Marker> setMarker = {};
  Set<Circle> setCircal ={};
  double requestContainerHeight =0;
  double tripContainerHeight = 0;
  double bottomMapPadding = 0;
  String stateOfApp = "normal";
  bool showClearIcon = false;
  bool iconGetCurrentActive = true;
  bool driverNearbyLoaded = false;
  BitmapDescriptor? iconDriverNearby;
  DatabaseReference? tripRequestRef;
  List<OnlineNearbyDrivers>?availableOnlineNearbyDriver;
  StreamSubscription<DatabaseEvent>? tripStreamSubscription;
  bool requestingDirectionDetailsInfo = false;


  makeIconCarDriverNearby(){
    if(iconDriverNearby == null){
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(context,size: Size(0.5,0.5));
      BitmapDescriptor.fromAssetImage(imageConfiguration, "assets/images/tracking.png").then((iconImage) => {
        iconDriverNearby = iconImage
      });
    }
  }

  void updateMapTheme(GoogleMapController controller) {
    getJsonFileFromThemes("themes/map_theme_night.json").then((value)=> setGoogleMapStyle(value, controller));
  }

  Future<String> getJsonFileFromThemes(String mapStylePath) async {
    ByteData byteData = await rootBundle.load(mapStylePath);
    var list = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    return utf8.decode(list);
  }

  setGoogleMapStyle(String googleMapStyle, GoogleMapController controller) {
    controller.setMapStyle(googleMapStyle);
  }

  getCurrentPositionUser() async{
    Position posCurrentUsr = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
    currentPosOfUser = posCurrentUsr;
    LatLng latLngUser = LatLng(currentPosOfUser!.latitude, currentPosOfUser!.longitude);
    CameraPosition cameraPosition = CameraPosition(target: latLngUser, zoom: 15);
    controllerGoogleMap!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
    await CommonMethods.convertGeoGraphicsIntoAddressUseAPIVietMap(currentPosOfUser!, context);
    await getStatusOfUser();
    await initailizeGeoFireListener();
  }

  getStatusOfUser() async{
    DatabaseReference usrRef = FirebaseDatabase.instance.ref()
        .child("users")
        .child(FirebaseAuth.instance.currentUser!.uid);
    await usrRef.once().then((snap) {
      if(snap.snapshot.value != null){
        if((snap.snapshot.value as Map)["blockedStatus"] == "no"){
          setState(() {
            userName = (snap.snapshot.value as Map)["name"];
            userPhone = (snap.snapshot.value as Map)["phone"];

          });
        }
        else{
          FirebaseAuth.instance.signOut();
          Navigator.push(context, MaterialPageRoute(builder: (c)=> LoginPage()));
          commonMethods.DisplayBox(context, "Error", "This account is blocked. Contact with admin", ContentType.failure);
        }
      }
    });
  }



  // ============================================ Geofy ===================================
  /*searchLocation(String locationName) async {

    if (locationName == null || locationName.isEmpty || locationName.length <= 1) {
      return;
    }

    // Replace with your actual API key
    final String urlApi = "https://api.geoapify.com/v1/geocode/autocomplete?text=$locationName&apiKey=$geoapifyApiKey&filter=countrycode:vn";

    try {
      final response = await http.get(Uri.parse(urlApi));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseFromPlaceApi = json.decode(response.body);

        if (responseFromPlaceApi["features"] != null) {
          final List<dynamic> features = responseFromPlaceApi["features"];
          final List<Map<String, dynamic>> locations = features.map((feature) {
            final properties = feature["properties"];
            return {
              "description": properties["formatted"],
              "place_id": properties["place_id"],
              "structured_formatting": {
                "main_text": properties["name"],
                "secondary_text": properties["address_line2"]
              }
            };
          }).toList();

          setState(() {
            locationListDisplay = locations;
          });
          print(locationListDisplay);
        } else {
          print("API response does not contain 'features'");
        }
      } else {
        print("Failed to load data from API, status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error occurred while calling API: $e");
    }
  }*/

  /*fetchClickedPlaceDetail(PanelController _pc, String placeID) async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => LoadingDialog(messageText: "Getting Detail......"),
    );

    String urlApiPlaceDetail = "https://api.geoapify.com/v2/place-details?id=$placeID&apiKey=$geoapifyApiKey";
    var responseFromPlaceDetailApi = await CommonMethods.sendRequestAPI(urlApiPlaceDetail);

    if (responseFromPlaceDetailApi == "Error") {
      commonMethods.DisplayBox(context, "Ooops....", "Something went wrong!! Try again in a few minutes!", ContentType.failure);
      Navigator.pop(context);
      return;
    }

    _pc.close();
    Navigator.pop(context);

    if (responseFromPlaceDetailApi["features"] != null && responseFromPlaceDetailApi["features"].isNotEmpty) {
      var result = responseFromPlaceDetailApi["features"][0]["properties"];

      AddressModel dropOffAddress = AddressModel();
      dropOffAddress.placeName = result["name"];
      dropOffAddress.latPosition = result["lat"];
      dropOffAddress.longPosition = result["lon"];
      dropOffAddress.placeID = placeID;

      Provider.of<AppInfor>(context, listen: false).updateDropOffAddress(dropOffAddress);
      print("Place Detail is: " + dropOffAddress.latPosition.toString());
    }

    displayDirectionDetailTrip();
  }*/

  searchLocation(String locationName) async {
    if (locationName == null || locationName.isEmpty || locationName.length <= 1) {
      return;
    }

    final String urlApi = "https://maps.vietmap.vn/api/autocomplete/v3?text=$locationName&apikey=$vietmapApiKey";

    try {
      final response = await http.get(Uri.parse(urlApi));

      if (response.statusCode == 200) {
        final List<dynamic> responseFromPlaceApi = json.decode(response.body);
        final List<Map<String, dynamic>> locations = responseFromPlaceApi.map((place) {
          return {
            "description": place["display"],
            "place_id": place["ref_id"],
            "structured_formatting": {
              "main_text": place["name"],
              "secondary_text": place["address"]
            }
          };
        }).toList();

        setState(() {
          locationListDisplay = locations;
        });
        print(locationListDisplay);
      } else {
        print("Failed to load data from API, status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error occurred while calling API: $e");
    }
  }

  fetchClickedPlaceDetail(PanelController _pc, String placeID) async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => LoadingDialog(messageText: "Getting Detail......"),
    );

    // Thay thế URL API của Geoapify bằng URL API của VietMap
    String urlApiPlaceDetail = "https://maps.vietmap.vn/api/place/v3?apikey=$vietmapApiKey&refid=$placeID";
    var responseFromPlaceDetailApi = await CommonMethods.sendRequestAPI(urlApiPlaceDetail);

    if (responseFromPlaceDetailApi == "Error") {
      commonMethods.DisplayBox(context, "Ooops....", "Something went wrong!! Try again in a few minutes!", ContentType.failure);
      Navigator.pop(context);
      return;
    }

    _pc.close();
    Navigator.pop(context);

    // Giả sử rằng phản hồi từ API VietMap chứa các chi tiết địa điểm tương tự như Geoapify
    if (responseFromPlaceDetailApi != null && responseFromPlaceDetailApi.isNotEmpty) {
      var result = responseFromPlaceDetailApi;

      AddressModel dropOffAddress = AddressModel();
      dropOffAddress.placeName = result["display"];
      dropOffAddress.latPosition = result["lat"];
      dropOffAddress.longPosition = result["lng"];
      dropOffAddress.placeID = placeID;

      Provider.of<AppInfor>(context, listen: false).updateDropOffAddress(dropOffAddress);
      print("Place Detail is: " + dropOffAddress.placeName.toString());
    }

    displayDirectionDetailTrip();
  }


  // =============================================================================================================


 /* searchLocation(String locationName) async {
    if (locationName.length > 1) {
      // Get Api from url
      String urlApi = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$locationName&key=$googeMapAPITest&components=country:vn";
      var responseFromPlaceApi = await CommonMethods.sendRequestAPI(urlApi) ?? {};
      if (responseFromPlaceApi == "Error") return;

      // Process Data if API response
      if(responseFromPlaceApi["status"] == "OK"){
        List<dynamic> predictions =[];
        List<Map<String,dynamic>> locations = [];
        predictions = responseFromPlaceApi["predictions"] ?? {};
        for(var prediction in predictions ){
          Map<String,dynamic> location = {
            "description" : prediction["description"],
            "place_id" : prediction["place_id"],
            "structured_formatting" : prediction["structured_formatting"],
          };
          locations.add(location);
        }
        setState(() {
          locationListDisplay = locations;
        });
        print(locationListDisplay);
      }
    }
  }*/

  /*fetchClickedPlaceDetail(PanelController _pc,String placeID) async{
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => LoadingDialog(messageText: "Getting Detail......"),
    );

    String urlApiPlaceDetail = "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeID&key=$googeMapAPITest";
    var responseFromPlaceDetailApi = await CommonMethods.sendRequestAPI(urlApiPlaceDetail);

    if(responseFromPlaceDetailApi == "Error") {
      commonMethods.DisplayBox(context, "Ooops....", "Something went wrong!! Try again in a few minutes !", ContentType.failure);
      Navigator.pop(context);
      return;
    }

    _pc.close();
    Navigator.pop(context);

    if(responseFromPlaceDetailApi["status"] == "OK"){
      AddressModel dropOffAddress = AddressModel();

      dropOffAddress.placeName = responseFromPlaceDetailApi["result"]["name"];
      dropOffAddress.latPosition = responseFromPlaceDetailApi["result"]["geometry"]["location"]["lat"];
      dropOffAddress.longPosition = responseFromPlaceDetailApi["result"]["geometry"]["location"]["lng"];
      dropOffAddress.placeID = placeID;

      Provider.of<AppInfor>(context, listen: false).updateDropOffAddress(dropOffAddress);
      print("Place Detail is: " + dropOffAddress.latPosition.toString());
    }
    displayDirectionDetailTrip();
  }*/

  displayDirectionDetailTrip() async{
    var pickupGeoAddress = Provider.of<AppInfor>(context,listen: false).pickUpAddress;
    var dropOffGeoAddress = Provider.of<AppInfor>(context,listen: false).dropOffAddress;

    var pickupCoordinates = LatLng(pickupGeoAddress!.latPosition!, pickupGeoAddress.longPosition!);
    var dropOffCoordinates = LatLng(dropOffGeoAddress!.latPosition!, dropOffGeoAddress.longPosition!);


    print(pickupCoordinates.latitude);
    print(pickupCoordinates.longitude);
    print(dropOffCoordinates.latitude);
    print(dropOffCoordinates.longitude);

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context)=> LoadingDialog(messageText: "Getting Direction......."),
    );

    var detailDirectionModel = await CommonMethods.getDirectionDetail(pickupCoordinates, dropOffCoordinates);
    print(detailDirectionModel);

    setState(() {
      tripDirectionDetailModel = detailDirectionModel;
    });

    _panelSearchLocationController.close();
    Navigator.pop(context);

    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> listLatLngPolylinePoints =  polylinePoints.decodePolyline(tripDirectionDetailModel!.encodedPoint!);//tripDirectionDetailModel!.listLatLngPolylinePoints!;
    print(listLatLngPolylinePoints);


    listcoOrdinates.clear();
    if(listLatLngPolylinePoints.isNotEmpty){
      listLatLngPolylinePoints.forEach((PointLatLng pointLatLng) {
              listcoOrdinates.add(
                  LatLng(pointLatLng.latitude,
                      pointLatLng.longitude));
      });
    }
    polylineSet.clear();

    setState(() {
      Polyline polyline = Polyline(
        polylineId: const PolylineId("polylineID"),
        color: Colors.green,
        points: listcoOrdinates,
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
      );
      polylineSet.add(polyline);
    });



    // Calculating to check that the position relative
// to the frame, and pan & zoom the camera accordingly.
    double miny = (pickupCoordinates.latitude <= dropOffCoordinates.latitude)
        ? pickupCoordinates.latitude
        : dropOffCoordinates.latitude;
    double minx = (pickupCoordinates.longitude <= dropOffCoordinates.longitude)
        ? pickupCoordinates.longitude
        : dropOffCoordinates.longitude;
    double maxy = (pickupCoordinates.latitude <= dropOffCoordinates.latitude)
        ? dropOffCoordinates.latitude
        : pickupCoordinates.latitude;
    double maxx = (pickupCoordinates.longitude <= dropOffCoordinates.longitude)
        ? dropOffCoordinates.longitude
        : pickupCoordinates.longitude;

    double southWestLatitude = miny;
    double southWestLongitude = minx;

    double northEastLatitude = maxy;
    double northEastLongitude = maxx;


    controllerGoogleMap!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          northeast: LatLng(northEastLatitude, northEastLongitude),
          southwest: LatLng(southWestLatitude, southWestLongitude),
        ),
        100.0,
      ),
    );



    Marker pickUpMarker = Marker(
      markerId: const MarkerId("Pick up location"),
      position: listcoOrdinates[0],
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );
    Marker dropOffMarker = Marker(
      markerId: const MarkerId("Drop off location"),
      position: listcoOrdinates[listcoOrdinates.length-1],
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
    setState(() {
      setMarker.add(pickUpMarker);
      setMarker.add(dropOffMarker);
    });


    Circle circlePickUpLocation = Circle(
      circleId: const CircleId("Pick up circel"),
      center: pickupCoordinates,
      strokeColor: Colors.greenAccent,
      strokeWidth: 4,
      fillColor: Colors.greenAccent,
      radius: 20,

    );
    setState(() {
      setCircal.add(circlePickUpLocation);
    });

  }

  resetApp(){
    setState(() {
      listcoOrdinates.clear();
      polylineSet.clear();
      destinationTextEditingController.text = "";
      locationListDisplay.clear();
      setMarker.clear();
      setCircal.clear();
      LatLng latLngUser = LatLng(currentPosOfUser!.latitude, currentPosOfUser!.longitude);
      CameraPosition cameraPosition = CameraPosition(target: latLngUser, zoom: 15);
      controllerGoogleMap!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
      _panelBookCarController.show();
      requestContainerHeight = 0;
      tripContainerHeight = 0;
      bottomMapPadding = 0;
      status = "";
      nameDriver = "";
      photoDriver = "";
      phoneNumberDriver = "";
      carDetailsDriver = "";
      tripStatusDisplay = 'Driver is Arriving';
    });

  }

  updateAvailableNearbyDriverOnline(){
    setState(() {
      setMarker.clear();
    });

    Set<Marker> markerTemp = Set<Marker>();

    for(OnlineNearbyDrivers driverOnline in ManagerDriverMethods.listDriverNearby){
      LatLng postionDriver =LatLng(driverOnline.latDriver!, driverOnline.lngDriver!);
      Marker markerDriverNearby = Marker(
          markerId: MarkerId("Driver Online Nearby"),
          position: postionDriver,
          icon: iconDriverNearby!,
      );
      markerTemp.add(markerDriverNearby);
    }
    setState(() {
      setMarker = markerTemp;
    });

  }

  initailizeGeoFireListener(){
    Geofire.initialize("onlineDrivers");
    Geofire.queryAtLocation(currentPosOfUser!.latitude, currentPosOfUser!.longitude, 70)!.listen((driverEvent) {
      var onlineDriverChild = driverEvent["callBack"];
      switch(onlineDriverChild){
        case Geofire.onGeoQueryReady:
          driverNearbyLoaded = true;
          updateAvailableNearbyDriverOnline();
          break;

        case Geofire.onKeyEntered:
          OnlineNearbyDrivers onlineNearbyDrivers = OnlineNearbyDrivers();
          onlineNearbyDrivers.uidDriver=driverEvent["key"];
          onlineNearbyDrivers.latDriver = driverEvent["latitude"];
          onlineNearbyDrivers.lngDriver=driverEvent["longitude"];
          ManagerDriverMethods.listDriverNearby.add(onlineNearbyDrivers);
          if(driverNearbyLoaded == true){
            updateAvailableNearbyDriverOnline();
          }
          break;

        case Geofire.onKeyMoved:
          OnlineNearbyDrivers onlineNearbyDrivers = OnlineNearbyDrivers();
          onlineNearbyDrivers.uidDriver=driverEvent["key"];
          onlineNearbyDrivers.latDriver = driverEvent["latitude"];
          onlineNearbyDrivers.lngDriver=driverEvent["longitude"];
          ManagerDriverMethods.updateNearbyDriverLocation(onlineNearbyDrivers);
          updateAvailableNearbyDriverOnline();
          break;


        case Geofire.onKeyExited:
          ManagerDriverMethods.removeDriverFromList(driverEvent["key"]);
          updateAvailableNearbyDriverOnline();
          break;


      }
    });
  }

  cancelRideRequest() {
    //remove ride request from database
    tripRequestRef!.remove();

    setState(() {
      stateOfApp = "normal";
    });
  }

  makeTripRequest(){
    tripRequestRef = FirebaseDatabase.instance.ref().child("tripRequests").push();
    var pickUpLocation = Provider.of<AppInfor>(context, listen: false).pickUpAddress;
    var dropOffDestinationLocation = Provider.of<AppInfor>(context, listen: false).dropOffAddress;
    Map pickUpCoOrdinatesMap =
    {
      "latitude": pickUpLocation!.latPosition.toString(),
      "longitude": pickUpLocation.latPosition.toString(),
    };

    Map dropOffDestinationCoOrdinatesMap =
    {
      "latitude": dropOffDestinationLocation!.latPosition.toString(),
      "longitude": dropOffDestinationLocation.longPosition.toString(),
    };

    Map driverCoOrdinates =
    {
      "latitude": "",
      "longitude": "",
    };

    Map dataMap =
    {
      "tripID": tripRequestRef!.key,
      "publishDateTime": DateTime.now().toString(),

      "userName": userName,
      "userPhone": userPhone,
      "userID": userID,
      "pickUpLatLng": pickUpCoOrdinatesMap,
      "dropOffLatLng": dropOffDestinationCoOrdinatesMap,
      "pickUpAddress": pickUpLocation.placeName,
      "dropOffAddress": dropOffDestinationLocation.placeName,

      "driverID": "waiting",
      "carDetails": "",
      "driverLocation": driverCoOrdinates,
      "driverName": "",
      "driverPhone": "",
      "driverPhoto": "",
      "fareAmount": "",
      "status": "new",
    };
    tripRequestRef!.set(dataMap);
    tripStreamSubscription = tripRequestRef!.onValue.listen((eventSnapshot)
    async {
      if(eventSnapshot.snapshot.value == null)
      {
        return;
      }

      if((eventSnapshot.snapshot.value as Map)["driverName"] != null)
      {
        nameDriver = (eventSnapshot.snapshot.value as Map)["driverName"];
      }

      if((eventSnapshot.snapshot.value as Map)["driverPhone"] != null)
      {
        phoneNumberDriver = (eventSnapshot.snapshot.value as Map)["driverPhone"];
      }

      if((eventSnapshot.snapshot.value as Map)["driverPhoto"] != null)
      {
        photoDriver = (eventSnapshot.snapshot.value as Map)["driverPhoto"];
      }

      if((eventSnapshot.snapshot.value as Map)["carDetails"] != null)
      {
        carDetailsDriver = (eventSnapshot.snapshot.value as Map)["carDetails"];
      }

      if((eventSnapshot.snapshot.value as Map)["status"] != null)
      {
        status = (eventSnapshot.snapshot.value as Map)["status"];
      }


      if((eventSnapshot.snapshot.value as Map)["driverLocation"] != null)
      {
        double driverLatitude = double.parse((eventSnapshot.snapshot.value as Map)["driverLocation"]["latitude"].toString());
        double driverLongitude = double.parse((eventSnapshot.snapshot.value as Map)["driverLocation"]["longitude"].toString());
        LatLng driverCurrentLocationLatLng = LatLng(driverLatitude, driverLongitude);

        if(status == "accepted")
        {
          //update info for pickup to user on UI
          //info from driver current location to user pickup location
          updateFromDriverCurrentLocationToPickUp(driverCurrentLocationLatLng);
        }
        else if(status == "arrived")
        {
          //update info for arrived - when driver reach at the pickup point of user
          setState(() {
            tripStatusDisplay = 'Driver has Arrived';
          });
        }
        else if(status == "ontrip")
        {
          //update info for dropoff to user on UI
          //info from driver current location to user dropoff location
          updateFromDriverCurrentLocationToDropOffDestination(driverCurrentLocationLatLng);
        }
      }

      if(status == "accepted")
      {
        displayTripDetailsContainer();

        Geofire.stopListener();

        //remove drivers markers
        setState(() {
          setMarker.removeWhere((element) => element.markerId.value.contains("driver"));
        });
      }

      if(status == "ended")
      {
        if((eventSnapshot.snapshot.value as Map)["fareAmount"] != null)
        {
          double fareAmount = double.parse((eventSnapshot.snapshot.value as Map)["fareAmount"].toString());

          var responseFromPaymentDialog = await showDialog(
            context: context,
            builder: (BuildContext context) => PaymentDialog(fareAmount: fareAmount.toString()),
          );

          if(responseFromPaymentDialog == "paid")
          {
            tripRequestRef!.onDisconnect();
            tripRequestRef = null;

            tripStreamSubscription!.cancel();
            tripStreamSubscription = null;
            resetApp();
            Restart.restartApp();
          }
        }
      }

    });
  }

  updateFromDriverCurrentLocationToPickUp(driverCurrentLocationLatLng) async {
    if(!requestingDirectionDetailsInfo)
    {
      requestingDirectionDetailsInfo = true;

      var userPickUpLocationLatLng = LatLng(currentPosOfUser!.latitude, currentPosOfUser!.longitude);

      var directionDetailsPickup = await CommonMethods.getDirectionDetail(driverCurrentLocationLatLng, userPickUpLocationLatLng);

      if(directionDetailsPickup == null)
      {
        return;
      }

      setState(() {
        tripStatusDisplay = "Driver is Coming - ${directionDetailsPickup.digitDistance.toString()}";
      });

      requestingDirectionDetailsInfo = false;
    }
  }

  updateFromDriverCurrentLocationToDropOffDestination(driverCurrentLocationLatLng) async {
    if(!requestingDirectionDetailsInfo)
    {
      requestingDirectionDetailsInfo = true;

      var dropOffLocation = Provider.of<AppInfor>(context, listen: false).dropOffAddress;
      var userDropOffLocationLatLng = LatLng(dropOffLocation!.latPosition!, dropOffLocation.longPosition!);

      var directionDetailsPickup = await CommonMethods.getDirectionDetail(driverCurrentLocationLatLng, userDropOffLocationLatLng);

      if(directionDetailsPickup == null)
      {
        return;
      }

      setState(() {
        tripStatusDisplay = "Driving to DropOff Location - ${directionDetailsPickup.digitDistance.toString()}";
      });

      requestingDirectionDetailsInfo = false;
    }
  }

  displayTripDetailsContainer() {
    setState(() {
      requestContainerHeight = 0;
      tripContainerHeight = 291;
      bottomMapPadding = 281;
    });
  }

  noDriverAvailable(){
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => InfoDialog(
          title: "No Driver Available",
          description: "No driver found nearby location !!  \n Please try again shortly.",
        ),
    );
  }

  searchDriver(){
    if(availableOnlineNearbyDriver!.length ==0){
      cancelRideRequest();
      resetApp();
      noDriverAvailable();
      return;
    }
    var currentDriver = availableOnlineNearbyDriver![0];
    sendNotificationToDriver(currentDriver);
    availableOnlineNearbyDriver!.removeAt(0);
  }

  sendNotificationToDriver(OnlineNearbyDrivers currentDriver){
    DatabaseReference currentDriverRef = FirebaseDatabase.instance
        .ref()
        .child("drivers")
        .child(currentDriver.uidDriver.toString())
        .child("newTripStatus");

    currentDriverRef.set(tripRequestRef!.key);
    DatabaseReference tokenCurrentDriverRef = FirebaseDatabase.instance
        .ref()
        .child("drivers")
        .child(currentDriver.uidDriver.toString())
        .child("deviceToken");
    tokenCurrentDriverRef.once().then((dataSnapshot) {
      if(dataSnapshot.snapshot.value != null){
        String deviceToken = dataSnapshot.snapshot.value.toString();
        PushNotificationService.sendNotificationToSelectedDriver(deviceToken, context,tripRequestRef!.key.toString());
      }else return;
      const oneTickPerSec = Duration(seconds: 1);

      var timerCountDown = Timer.periodic(oneTickPerSec, (timer)
      {
        requestTimeoutDriver = requestTimeoutDriver - 1;

        //when trip request is not requesting means trip request cancelled - stop timer
        if(stateOfApp != "requesting")
        {
          timer.cancel();
          currentDriverRef.set("cancelled");
          currentDriverRef.onDisconnect();
          requestTimeoutDriver = 20;
        }

        //when trip request is accepted by online nearest available driver
        currentDriverRef.onValue.listen((dataSnapshot)
        {
          if(dataSnapshot.snapshot.value.toString() == "accepted")
          {
            timer.cancel();
            currentDriverRef.onDisconnect();
            requestTimeoutDriver = 20;
          }
        });

        //if 20 seconds passed - send notification to next nearest online available driver
        if(requestTimeoutDriver == 0)
        {
          currentDriverRef.set("timeout");
          timer.cancel();
          currentDriverRef.onDisconnect();
          requestTimeoutDriver = 20;

          //send notification to next nearest online available driver
          searchDriver();
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _panelBookCarController.hide();
      _panelSearchLocationController.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    String address = Provider
        .of<AppInfor>(context, listen: false)
        .pickUpAddress
        ?.addressHumman ?? "";
    pickUpTextEditingController.text = address;
    displayPickUpTextEditingController.text = address;
    const BorderRadiusGeometry radius = BorderRadius.only(
      topLeft: Radius.circular(24.0),
      topRight: Radius.circular(24.0),
    );

    makeIconCarDriverNearby();
    return Scaffold(
      key: sKey,
      drawer: Container(
        width: 255,
        color: Colors.black87,
        child: Drawer(
          backgroundColor: Colors.white10,
          child: ListView(
            children: [

              const Divider(
                height: 1,
                color: Colors.grey,
                thickness: 1,
              ),

              //header
              Container(
                color: Colors.black54,
                height: 160,
                child: DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Colors.white10,
                  ),
                  child: Row(
                    children: [

                      Image.asset(
                        "assets/images/avatarman.png",
                        width: 60,
                        height: 60,
                      ),

                      const SizedBox(width: 16,),

                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4,),

                          const Text(
                            "Profile",
                            style: TextStyle(
                              color: Colors.white38,
                            ),
                          ),

                        ],
                      ),

                    ],
                  ),
                ),
              ),

              const Divider(
                height: 1,
                color: Colors.grey,
                thickness: 1,
              ),

              const SizedBox(height: 10,),

              GestureDetector(

                // Button Logout feature
                onTap: ()
                {
                  Navigator.push(context, MaterialPageRoute(builder: (c)=> TripsHistoryPage()));
                },
                child: ListTile(
                  leading: IconButton(
                    onPressed: (){},
                    icon: const Icon(Icons.history, color: Colors.grey,),
                  ),
                  title: const Text("History", style: TextStyle(color: Colors.grey),),
                ),
              ),
              //body
              ListTile(
                leading: IconButton(
                  onPressed: (){},
                  icon: const Icon(Icons.info, color: Colors.grey,),
                ),
                title: const Text("About", style: TextStyle(color: Colors.grey),),
              ),

              GestureDetector(

                // Button Logout feature
                onTap: ()
                {
                  FirebaseAuth.instance.signOut();
                  Navigator.push(context, MaterialPageRoute(builder: (c)=> LoginPage()));
                },
                child: ListTile(
                  leading: IconButton(
                    onPressed: (){},
                    icon: const Icon(Icons.logout, color: Colors.grey,),
                  ),
                  title: const Text("Logout", style: TextStyle(color: Colors.grey),),
                ),
              ),

            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: true,
            polylines: polylineSet,
            markers: setMarker,
            circles: setCircal,
            myLocationButtonEnabled: false,
            initialCameraPosition: googleInitPos,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController mapController){
              controllerGoogleMap = mapController;
              googleMapCompleter.complete(controllerGoogleMap);
              updateMapTheme(controllerGoogleMap!);
              getCurrentPositionUser();
            },
          ),
          Positioned(
            top: 36,
            left: 19,
            child: GestureDetector(
              onTap: ()
              {
                sKey.currentState!.openDrawer();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const
                  [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                      spreadRadius: 0.5,
                      offset: Offset(0.7, 0.7),
                    ),
                  ],
                ),
                child:  const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: Icon(
                    Icons.menu,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          // Button floating get current user
          if(iconGetCurrentActive)
            Positioned(
            top: 660, // Điều chỉnh vị trí theo y
            right: 15, // Điều chỉnh vị trí theo x
            child: FloatingActionButton(
              onPressed: () {
                getCurrentPositionUser();
              },
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 10,
              mini: true,
              shape: CircleBorder(),
              child: Icon(Icons.my_location),
            ),
          ),
          // Sliding up Panel Search
          SlidingUpPanel(
            onPanelOpened: () {
              setState(() {
                _isPanelDraggable = true; // Khi panel mở, cho phép kéo xuống để đóng nó
              });
            },
            onPanelClosed: () {
              setState(() {
                _isPanelDraggable = false; // Khi panel đóng, không cho phép kéo lên để mở lại
              });
            },
            controller: _panelSearchLocationController,
            maxHeight: 700,
            panel:  Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start, // Đẩy biểu tượng lên phía trên
                children: [
                  Container(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.only(top:10),
                        height: 5,
                        width: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey,
                        ),

                      ),
                    ),
                  ),
                  const SizedBox(height: 4.0,),
                  SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        const Text(
                          "Set your destination",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 25,
                          ),
                        ),
                        const SizedBox(height: 4.0,),
                        const Text(
                          "Type and pick from suggestion",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 15,
                          ),
                        ),
                        const Divider(height: 35,color: Colors.green,),
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 20.0),
                              child: Column(
                                children: [
                                  Container(
                                    height: 8.0,
                                    width: 8.0,
                                    margin: const EdgeInsets.all(2.0),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    height: 40.0,
                                    width: 2.0,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                    ),
                                  ),
                                  Container(
                                    height: 8.0,
                                    width: 8.0,
                                    margin: const EdgeInsets.all(2.0),
                                    decoration: const BoxDecoration(color: Colors.green,),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 20.0),
                                child: Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(color: Colors.green, width: 1.0),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, ), // Điều chỉnh padding tại đây
                                      child: TextFormField(
                                        readOnly: true,
                                        controller: pickUpTextEditingController,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          prefixIcon:  Icon(Icons.my_location,color: Colors.greenAccent),
                                          border: InputBorder.none,
                                          hintText: 'Enter your text here',
                                          hintStyle: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5.0,),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(color: Colors.green, width: 1.0),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              onChanged: (inputText) {
                                                setState(() {
                                                  searchLocation(inputText);
                                                  showClearIcon = inputText.isNotEmpty;
                                                });
                                              },
                                              controller: destinationTextEditingController,
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                prefixIcon: Icon(Icons.location_pin, color: Colors.redAccent),
                                                hintText: "Where go?",
                                                hintStyle: TextStyle(color: Colors.grey),
                                                border: InputBorder.none,
                                              ),
                                            ),
                                          ),

                                          if(showClearIcon)
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  destinationTextEditingController.text = '';
                                                  showClearIcon = false;
                                                });
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(bottom: 5.0,left: 15.0,),
                                                child: Icon(Icons.close, color: Colors.grey,size: 25,),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10,),
                        Container(
                          height: 390,
                          child: ListView.builder(

                            itemCount: locationListDisplay.length,
                            padding: const EdgeInsets.only(right: 10),
                            itemBuilder: (BuildContext context, int index) {
                              return ListTile(
                                onTap: () {
                                  // Khi một ListTile được chọn, cập nhật selectedLocation bằng thông tin tương ứng với index
                                  setState(() {
                                    String selectedLocation = locationListDisplay[index]["description"].toString();
                                    String placeID = locationListDisplay[index]["place_id"].toString();
                                    print("Select is $placeID");
                                    destinationTextEditingController.text = selectedLocation.toString();
                                    displayDestinationTextEditingController.text = selectedLocation.toString();
                                    fetchClickedPlaceDetail(_panelSearchLocationController,placeID);
                                    _panelBookCarController.show();
                                    _panelSearchLocationController.hide();
                                  });

                                },
                                leading: const Icon(Icons.location_on),
                                title: Text(
                                  locationListDisplay[index]["description"].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locationListDisplay[index]["structured_formatting"]["secondary_text"].toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Container(
                                      height: 1,
                                      margin: const EdgeInsets.only(top: 8.0),
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 15.0,),
                      ],
                    ),
                  ),
                  Container(
                    width: 350, // Đặt chiều rộng mong muốn cho FilledButton
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48.0),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5.0), // Điều chỉnh giá trị của borderRadius để thay đổi độ bo góc
                        ),
                      ),
                      onPressed: () {
                        // Hành động khi nút được nhấn
                      },
                      child: const Text(
                        "Confirm destination",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  )
                ],

              ),
            ),
            collapsed: Container(
              width: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: radius,
              ),
              child:  Column(
                mainAxisAlignment: MainAxisAlignment.start, // Đẩy biểu tượng lên phía trên
                children: [
                  Container(
                    child:  SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          const SizedBox(height: 20.0,),
                          const Text(
                            "Pickup Destination Address",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: 20.0,
                            ),
                          ),
                          const Text(
                            "Drag the map to move a pin",
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Colors.grey,
                              fontSize: 15.0,
                            ),
                          ),
                          const SizedBox(height: 5.0,),
                          Container(
                            width: 350,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(45.0),
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5.0), // Điều chỉnh giá trị của borderRadius để thay đổi độ bo góc
                                ),
                              ),
                              onPressed: ()  {
                                print("Clicked Button");
                                getCurrentPositionUser();
                                _panelSearchLocationController.open();
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 2.0,),
                                  Icon(Icons.map_outlined,color: Colors.white,size: 25,),
                                  SizedBox(width: 10.0,),
                                  Text(
                                    "Search map now",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),

            ),
            borderRadius: radius,
            minHeight: 150,
            isDraggable: _isPanelDraggable,
          ),
          // Sliding up Panel Display detail trip
          SlidingUpPanel(
            controller: _panelBookCarController,
            panel: const Center(),
            collapsed: Container(
              width: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: radius,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0,vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Select an option : ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.black,
                          ),
                        ),
                        Positioned(
                          top: 40,
                          left: 350,
                          child: GestureDetector(
                            onTap: () async {
                              resetApp();
                              makeIconCarDriverNearby();
                              await Future.delayed(Duration(milliseconds: 200));
                              _panelBookCarController.hide();
                              _panelSearchLocationController.show();
                              setState(() {
                                iconGetCurrentActive = true;
                                showClearIcon = false;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red), // Màu viền đỏ
                                color: Colors.transparent, // Màu trong suốt
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 5,
                                    spreadRadius: 0.5,
                                    offset: Offset(0.7, 0.7),
                                  ),
                                ],
                              ),
                              child: const CircleAvatar(
                                backgroundColor: Colors.transparent,
                                radius: 20,
                                child: Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 90,
                    width: 350, // Assuming Get.width provides the width of the screen
                    child: StatefulBuilder(builder: (context, set) {
                      return ListView.builder(
                        itemBuilder: (ctx, i) {
                          return InkWell(
                            onTap: () {
                              set(() {
                                selectedRide = i; // Assuming selectedRide is a variable that tracks the index of the selected ride
                              });
                            },
                            child: buildDriverCard(selectedRide == i), // Assuming buildDriverCard is a function that creates a driver card widget
                          );
                        },
                        itemCount: 3, // Assuming there are 3 driver cards
                        scrollDirection: Axis.horizontal,
                      );
                    }),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 40.0),
                      child: Row(
                        children: [
                          const SizedBox(height: 2.0,),
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: Colors.green, width: 1.0),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: SizedBox(
                                  width: 210, // Đây là chiều cao mong muốn
                                  child: TextFormField(
                                    readOnly: true,
                                    controller: displayDestinationTextEditingController,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      prefixIcon: Icon(Icons.location_pin,color: Colors.redAccent,),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: GestureDetector(
                                  onTap: () async {
                                    _panelSearchLocationController.show();
                                    await Future.delayed(Duration(milliseconds: 100)); // Chờ 0.1 giây để đảm bảo hiệu ứng hoạt động trước khi mở panel tiếp theo
                                    _panelSearchLocationController.open();
                                    await Future.delayed(Duration(milliseconds: 100)); // Tương tự, chờ 0.1 giây trước khi ẩn panel khác
                                    _panelBookCarController.hide();
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10), // Khoảng cách giữa hộp và nút
                          FilledButton(
                            style: ButtonStyle(
                              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0), // Đây là đoạn mã để bo góc
                                ),
                              ),
                              backgroundColor: MaterialStateProperty.all<Color>(Color(0xff2DBB54)),
                              minimumSize: MaterialStateProperty.all<Size>(Size(20, 50)), // Đặt kích thước nút 200x50

                            ),
                            onPressed: () {
                              setState(() {
                                _panelSearchLocationController.hide();
                                _panelBookCarController.hide();
                                requestContainerHeight = 200;
                                iconGetCurrentActive = false;
                                stateOfApp = "requesting";
                                makeTripRequest();
                                availableOnlineNearbyDriver = ManagerDriverMethods.listDriverNearby;
                                searchDriver();
                              });
                            },
                            child: const Text(
                              "Confirm",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                              ),
                            ), // Văn bản trên nút
                          ),
                        ],
                      ),
                    ),
                  ),


                ],
              ),
            ),
            borderRadius: radius,
            minHeight: 250,
            isDraggable: false,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: requestContainerHeight,
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                boxShadow:
                [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15.0,
                    spreadRadius: 0.5,
                    offset: Offset(
                      0.7,
                      0.7,
                    ),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Waiting for driver... Please wait a moment..",

                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 10,),
                    SizedBox(
                      width: 200,
                      child: LoadingAnimationWidget.flickr(
                        leftDotColor: Colors.greenAccent,
                        rightDotColor: Colors.pinkAccent,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 15,),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          requestContainerHeight = 0;
                          _panelBookCarController.show();
                        });
                      },
                      child: Stack(
                        children: [
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(width: 1.5, color: Colors.pink), // Màu viền hồng
                            ),
                          ),
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Để nền trong suốt
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.close,
                                color: Colors.pink, // Màu icon hồng
                                size: 25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12,),
                  ],
                ),
              ),
            ),
          ),

          // Call driver
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: tripContainerHeight,
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                boxShadow:
                [
                  BoxShadow(
                    color: Colors.white24,
                    blurRadius: 15.0,
                    spreadRadius: 0.5,
                    offset: Offset(
                      0.7,
                      0.7,
                    ),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const SizedBox(height: 5,),

                    //trip status display text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tripStatusDisplay,
                          style: const TextStyle(fontSize: 19, color: Colors.grey,),
                        ),
                      ],
                    ),

                    const SizedBox(height: 19,),

                    const Divider(
                      height: 1,
                      color: Colors.white70,
                      thickness: 1,
                    ),

                    const SizedBox(height: 19,),

                    //image - driver name and driver car details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        ClipOval(
                          child: Image.network(
                            photoDriver == ''
                                ? "https://firebasestorage.googleapis.com/v0/b/move-eese-app-admin.appspot.com/o/001%20avatarman.png?alt=media&token=b8957955-6671-48df-ad6b-cd26b940b6e5"
                                : photoDriver,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),

                        const SizedBox(width: 8,),

                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Text(nameDriver, style: const TextStyle(fontSize: 20, color: Colors.grey,),),

                            Text(carDetailsDriver, style: const TextStyle(fontSize: 14, color: Colors.grey,),),

                          ],
                        ),

                      ],
                    ),

                    const SizedBox(height: 19,),

                    const Divider(
                      height: 1,
                      color: Colors.white70,
                      thickness: 1,
                    ),

                    const SizedBox(height: 19,),

                    //call driver btn
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        GestureDetector(
                          onTap: ()
                          {
                            launchUrl(Uri.parse("tel://$phoneNumberDriver"));
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [

                              Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(Radius.circular(25)),
                                  border: Border.all(
                                    width: 1,
                                    color: Colors.white,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.phone,
                                  color: Colors.white,
                                ),
                              ),

                              const SizedBox(height: 11,),

                              const Text("Call", style: TextStyle(color: Colors.grey,),),

                            ],
                          ),
                        ),

                      ],
                    ),

                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  int selectedRide = 0;
  buildDriverCard(bool selected) {
    return Container(
      margin: EdgeInsets.only(right: 8, left: 8, top: 4, bottom: 4),
      height: 85,
      width: 165,
      decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: selected
                    ? Color(0xff2DBB54).withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                offset: Offset(0, 5),
                blurRadius: 5,
                spreadRadius: 1)
          ],
          borderRadius: BorderRadius.circular(12),
          color: selected ? Color(0xff2DBB54) : Colors.grey),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.only(left: 10, top: 10, bottom: 10, right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textWidget(
                    text: (tripDirectionDetailModel!=null) ? "${CommonMethods.convertFromKilometersToMoney(tripDirectionDetailModel!.digitDistance!)} VND" : "O VND",
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
                textWidget(
                    text:  (tripDirectionDetailModel!=null) ? CommonMethods.convertIntToTimeFormat(tripDirectionDetailModel!.digitTimeDuration!) : "0H 00s",
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.normal,
                    fontSize: 12),
                textWidget(
                    text: (tripDirectionDetailModel!=null) ? CommonMethods.convertDistance(tripDirectionDetailModel!.digitDistance!) : "0 Km",
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.normal,
                    fontSize: 12),
              ],
            ),
          ),
          Positioned(
              right: -20,
              top: 0,
              bottom: 0,
              child: Image.asset('assets/images/carmask.png'))
        ],
      ),
    );
  }
}