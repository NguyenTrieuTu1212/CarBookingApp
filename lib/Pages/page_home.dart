
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:app_car_booking/Auth/login_screen.dart';
import 'package:app_car_booking/Methods/common_methods.dart';
import 'package:app_car_booking/Models/AddressModel.dart';
import 'package:app_car_booking/Models/direction_detail_model.dart';
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
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import '../AppInfor/app_info.dart';
import '../Global/global_var.dart';
import '../Widgets/text_widget.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';



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


  LatLng? lstlngTest;



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
    await CommonMethods.convertGeoGraphicsIntoAddress(currentPosOfUser!, context);
    await getStatusOfUser();
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

  searchLocation(String locationName) async {
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
  }

  fetchClickedPlaceDetail(PanelController _pc,String placeID) async{

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
  }

  displayDirectionDetailTrip() async{
    var pickupGeoAddress = Provider.of<AppInfor>(context,listen: false).pickUpAddress;
    var dropOffGeoAddress = Provider.of<AppInfor>(context,listen: false).dropOffAddress;

    var pickupCoordinates = LatLng(pickupGeoAddress!.latPosition!, pickupGeoAddress.longPosition!);
    var dropOffCoordinates = LatLng(dropOffGeoAddress!.latPosition!, dropOffGeoAddress.longPosition!);


    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context)=> LoadingDialog(messageText: "Getting Direction......."),
    );

    _panelSearchLocationController.close();
    Navigator.pop(context);

    /*String urlDetailDirection ="https://maps.googleapis.com/maps/api/directions/json?origin=${pickupCoordinates.latitude},${pickupCoordinates.longitude}&destination=${dropOffCoordinates.latitude},${dropOffCoordinates.longitude}&mode=driving&key=AIzaSyDuDxriw8CH8NbVLiXtKFQ2Nb64AoRSdyg";

    var respone = await CommonMethods.sendRequestAPI(urlDetailDirection);
    if(respone == "Error") return;
    print("Drop off lat is: " + dropOffGeoAddress.latPosition.toString() + " " + dropOffGeoAddress.longPosition.toString());
    print("Reponse API detail trip is: " + respone!.toString());*/

    var detailDirectionModel = await CommonMethods.getDirectionDetail(pickupCoordinates, dropOffCoordinates);
    setState(() {
      tripDirectionDetailModel = detailDirectionModel;
    });


    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> listLatLngPolylinePoints = polylinePoints.decodePolyline(tripDirectionDetailModel!.encodedPoint!);

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
                child: const CircleAvatar(
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
          Positioned(
            top: 40,
            left: 350,
            child: GestureDetector(
              onTap: ()
              {
                getCurrentPositionUser();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
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
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: Icon(
                    Icons.my_location,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, ),
                                      child: TextFormField(
                                        onChanged: (inputText){
                                          searchLocation(inputText);
                                        },
                                        controller: destinationTextEditingController,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          prefixIcon: Icon(Icons.location_pin,color: Colors.redAccent,),
                                          hintText: "Where go ?",
                                          hintStyle: TextStyle(color: Colors.grey),
                                          border: InputBorder.none,
                                        ),
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
                                      color: Colors.black87,
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
                        ), // Text hiển thị "Select option"
                        Container(
                          width: 100,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(45.0),
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0), // Điều chỉnh giá trị của borderRadius để thay đổi độ bo góc
                              ),
                            ),
                            onPressed: ()  {
                              _panelBookCarController.hide();
                              _panelSearchLocationController.show();
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Cancel",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
                /*textWidget(
                    text: 'Standard',
                    color: Colors.white,
                    fontWeight: FontWeight.w700),*/
                textWidget(
                    text: (tripDirectionDetailModel!=null) ? "${CommonMethods.convertFromKilometersToMoney(tripDirectionDetailModel!.digitDistance!).toString()} VND" : "O vnd",
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
                textWidget(
                    text:  CommonMethods.convertTimeFormat(tripDirectionDetailModel?.timeDurationText.toString() ?? "0 MIN"),
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.normal,
                    fontSize: 12),
                textWidget(
                    text: tripDirectionDetailModel?.distanceText.toString() ?? "0 KM",
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