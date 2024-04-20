
import 'package:app_car_booking/AppInfor/app_info.dart';
import 'package:app_car_booking/Auth/login_screen.dart';
import 'package:app_car_booking/Auth/signup_screen.dart';
import 'package:app_car_booking/Map/map_display.dart';
import 'package:app_car_booking/Pages/page_home.dart';
import 'package:app_car_booking/Test/TestSlidingUp.dart';
import 'package:app_car_booking/Test/createDriver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';




Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Permission.locationWhenInUse.isDenied.then((valuePermission){
    if(valuePermission){
      Permission.locationWhenInUse.request();
    }
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget{

  const MyApp({super.key});
  @override
  Widget build(BuildContext context){
    return  ChangeNotifierProvider(
      create: (context) => AppInfor() ,
      child: MaterialApp(
        home:  AddDriver()/* FirebaseAuth.instance.currentUser == null ? HomePage() : HomePage()*/,
        title: "Fluter App",
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

}




