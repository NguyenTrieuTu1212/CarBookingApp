
import '../Models/online_nearby_driver.dart';
class ManagerDriverMethods{

  static List<OnlineNearbyDrivers> listDriverNearby = [];


  static void removeDriverFromList(String driverID){
    int idx = listDriverNearby.indexWhere((driver) => driver.uidDriver == driverID);
    if(listDriverNearby.length>0) listDriverNearby.removeAt(idx);
  }



  static void updateNearbyDriverLocation(OnlineNearbyDrivers onlineNearbyDrivers){
    int index = listDriverNearby.indexWhere((driver) => driver.uidDriver == onlineNearbyDrivers.uidDriver);
    listDriverNearby[index].latDriver = onlineNearbyDrivers.latDriver;
    listDriverNearby[index].lngDriver = onlineNearbyDrivers.lngDriver;
  }
}