import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';


// Initialize notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// MongoDB Service Singleton
class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  Db? _vehicleDb;
  Db? _partnerDb;
  bool _isVehicleConnected = false;
  bool _isPartnerConnected = false;
  static List<String> allVehicleNames = [];

  factory MongoDBService() => _instance;

  MongoDBService._internal();

  Future<void> connect() async {
    const maxRetries = 5;
    const baseRetryDelay = Duration(seconds: 5);
    bool vehicleSuccess = false;
    bool partnerSuccess = false;

    // Connect to vehicle DB
    if (!_isVehicleConnected || _vehicleDb == null) {
      for (int i = 0; i < maxRetries; i++) {
        try {
          _vehicleDb = await Db.create(
              'mongodb+srv://agrix:agrix1234@cluster0.1r955.mongodb.net/vehicle-tracker?retryWrites=true&w=majority&appName=Cluster0');
          await _vehicleDb!.open();
          _isVehicleConnected = true;
          print('Connected to vehicle DB: ${_vehicleDb!.databaseName} at ${DateTime.now().toUtc().toIso8601String()}');
          break;
        } catch (e, stackTrace) {
          print('Vehicle DB connection attempt ${i + 1} failed: $e\nStackTrace: $stackTrace');
          _isVehicleConnected = false;
          _vehicleDb = null;
          if (i == maxRetries - 1) {
            print('Failed to connect to vehicle DB after $maxRetries retries');
          }else {
            await Future.delayed(Duration(seconds: (math.pow(2, i) * baseRetryDelay.inSeconds).toInt()));
          }
        }
      }
    }

    // Connect to partner DB
    if (!_isPartnerConnected || _partnerDb == null) {
      for (int i = 0; i < maxRetries; i++) {
        try {
          _partnerDb = await Db.create(
              'mongodb+srv://agrix:agrix1234@cluster0.1r955.mongodb.net/Dashboard?retryWrites=true&w=majority&appName=Cluster0');
          await _partnerDb!.open();
          _isPartnerConnected = true;
          print('Connected to partner DB: ${_partnerDb!.databaseName} at ${DateTime.now().toUtc().toIso8601String()}');
          break;
        } catch (e, stackTrace) {
          print('Partner DB connection attempt ${i + 1} failed: $e\nStackTrace: $stackTrace');
          _isPartnerConnected = false;
          _partnerDb = null;
          if (i == maxRetries - 1) {
            print('Failed to connect to partner DB after $maxRetries retries');
          }
          await Future.delayed(Duration(seconds: (math.pow(2, i) * baseRetryDelay.inSeconds).toInt()));
        }
      }
    }
  }

  Future<List<String>> getAllVehicleNames() async {
    if (!_isPartnerConnected || _partnerDb == null) {
      try {
        await connect();
      } catch (e) {
        print('Failed to connect for vehicle names: $e');
        return [];
      }
    }
    try {
      final partners = await _partnerDb!.collection('partners').find().toList();
      final vehicles = partners.expand((p) => (p['vehicles'] as List<dynamic>? ?? []).map((v) => v as String)).toSet().toList();
      allVehicleNames = vehicles;
      print('Fetched ${vehicles.length} vehicle names at ${DateTime.now().toUtc().toIso8601String()}');
      return vehicles;
    } catch (e, stackTrace) {
      print('Error fetching vehicle names: $e\nStackTrace: $stackTrace');
      return [];
    }
  }

  Future<void> saveVehicleData(String vehicleNo, Map<String, dynamic> data, {bool fromApi = false}) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> sanitizedData = Map.from(data);
    sanitizedData['fetchedAt'] = DateTime.now().toUtc().toIso8601String();

    if (!_isVehicleConnected || _vehicleDb == null) {
      try {
        await connect();
      } catch (e) {
        print('Failed to connect for saving $vehicleNo: $e');
        _queueData(prefs, vehicleNo, sanitizedData);
        return;
      }
    }

    try {
      final collection = _vehicleDb!.collection(vehicleNo);
      await collection.insertOne(sanitizedData);
      print('Inserted document for $vehicleNo: ${sanitizedData['fetchedAt']}');
    } catch (e, stackTrace) {
      print('Error saving vehicle data for $vehicleNo: $e\nStackTrace: $stackTrace');
      _queueData(prefs, vehicleNo, sanitizedData);
    }
  }

  Future<void> syncQueuedData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isVehicleConnected || _vehicleDb == null) {
      try {
        await connect();
      } catch (e) {
        print('Failed to connect for syncing queued data: $e');
        return;
      }
    }

    try {
      for (var vehicleNo in allVehicleNames) {
        String? queuedDataJson = prefs.getString('queued_gps_data_$vehicleNo');
        if (queuedDataJson != null) {
          List<Map<String, dynamic>> queuedData = List<Map<String, dynamic>>.from(jsonDecode(queuedDataJson));
          final collection = _vehicleDb!.collection(vehicleNo);
          for (var data in queuedData) {
            try {
              await collection.insertOne(data);
              print('Synced queued document for $vehicleNo: ${data['fetchedAt']}');
            } catch (e, stackTrace) {
              print('Error syncing document for $vehicleNo: $e\nStackTrace: $stackTrace');
            }
          }
          await prefs.remove('queued_gps_data_$vehicleNo');
          print('Cleared queued data for $vehicleNo');
        }
      }
    } catch (e, stackTrace) {
      print('Error syncing queued data: $e\nStackTrace: $stackTrace');
    }
  }

  Future<Map<String, dynamic>?> getLatestVehicleData(String vehicleNo) async {
    if (!_isVehicleConnected || _vehicleDb == null) {
      try {
        await connect();
      } catch (e) {
        print('Failed to connect for fetching $vehicleNo: $e');
        return null;
      }
    }
    try {
      final collection = _vehicleDb!.collection(vehicleNo);
      final result = await collection
          .find(where.sortBy('fetchedAt', descending: true).limit(1))
          .toList();
      print('Fetched latest data for $vehicleNo at ${DateTime.now().toUtc().toIso8601String()}');
      return result.isNotEmpty ? result.first : null;
    } catch (e, stackTrace) {
      print('Error fetching latest data for $vehicleNo: $e\nStackTrace: $stackTrace');
      return null;
    }
  }

  Future<List<User>> getAllPartners() async {
    if (!_isPartnerConnected || _partnerDb == null) {
      try {
        await connect();
      } catch (e) {
        print('Failed to connect for partners: $e');
        return [];
      }
    }
    try {
      final partners = await _partnerDb!.collection('partners').find().toList();
      print('Fetched ${partners.length} partners at ${DateTime.now().toUtc().toIso8601String()}');
      return partners.map((p) => User.fromJson(p)).toList();
    } catch (e, stackTrace) {
      print('Error fetching partners: $e\nStackTrace: $stackTrace');
      return [];
    }
  }

  Future<void> savePartner(User user) async {
    if (!_isPartnerConnected || _partnerDb == null) {
      try {
        await connect();
      } catch (e) {
        print('Failed to connect for saving partner ${user.userId}: $e');
        return;
      }
    }
    try {
      final now = DateTime.now().toUtc();
      final partnerData = {
        'partnerId': user.partnerId ?? 'AGRXP${now.millisecondsSinceEpoch}',
        'userId': user.userId,
        'name': user.name,
        'vehicles': user.vehicles,
        'attachments': user.attachments ?? [],
        'createdAt': user.createdAt?.toIso8601String() ?? now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'phone': user.phone,
        'email': user.email,
      };
      print('Saving partner: $partnerData at ${DateTime.now().toUtc().toIso8601String()}');
      await _partnerDb!.collection('partners').updateOne(
        where.eq('userId', user.userId),
        {r'$set': partnerData},
        upsert: true,
      );
      print('Partner ${user.userId} saved successfully');
    } catch (e, stackTrace) {
      print('Error saving partner ${user.userId}: $e\nStackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> deletePartner(String userId) async {
    if (!_isPartnerConnected || _partnerDb == null) {
      try {
        await connect();
      } catch (e) {
        print('Failed to connect for deleting partner $userId: $e');
        return;
      }
    }
    try {
      await _partnerDb!.collection('partners').deleteOne(where.eq('userId', userId));
      print('Deleted partner $userId at ${DateTime.now().toUtc().toIso8601String()}');
    } catch (e, stackTrace) {
      print('Error deleting partner $userId: $e\nStackTrace: $stackTrace');
    }
  }

  void _queueData(SharedPreferences prefs, String vehicleNo, Map<String, dynamic> sanitizedData) {
    try {
      String? queuedDataJson = prefs.getString('queued_gps_data_$vehicleNo');
      List<Map<String, dynamic>> queuedData = queuedDataJson != null
          ? List<Map<String, dynamic>>.from(jsonDecode(queuedDataJson))
          : [];
      queuedData.add(sanitizedData);
      prefs.setString('queued_gps_data_$vehicleNo', jsonEncode(queuedData));
      print('Queued data for $vehicleNo at ${DateTime.now().toUtc().toIso8601String()}');
    } catch (e, stackTrace) {
      print('Error queuing data for $vehicleNo: $e\nStackTrace: $stackTrace');
    }
  }

  Future<void> close() async {
    if (_isVehicleConnected && _vehicleDb != null) {
      await _vehicleDb!.close();
      print('Vehicle DB closed at ${DateTime.now().toUtc().toIso8601String()}');
    }
    if (_isPartnerConnected && _partnerDb != null) {
      await _partnerDb!.close();
      print('Partner DB closed at ${DateTime.now().toUtc().toIso8601String()}');
    }
    _isVehicleConnected = false;
    _isPartnerConnected = false;
    _vehicleDb = null;
    _partnerDb = null;
  }

  bool get isConnected => _isVehicleConnected || _isPartnerConnected;
}

Future<bool> requestPermissions() async {
  // Request notification permission (Android 13+)
  if (!await Permission.notification.request().isGranted) {
    print("Notification permission denied");
    // Continue, as notifications may still work for foreground services
  }

  // Request battery optimization exemption
  if (!await Permission.ignoreBatteryOptimizations.request().isGranted) {
    print("Battery optimization not disabled");
    // Continue, as this is user-dependent
  }

  // Request location permissions (optional, if API data includes location)
  if (!await Permission.location.request().isGranted) {
    print("Location permission denied");
    return false;
  }
  if (!await Permission.locationAlways.request().isGranted) {
    print("Background location permission denied");
    return false;
  }

  print("All permissions granted");
  return true;
}

class MachineDataService {
  static final MachineDataService _instance = MachineDataService._internal();
  List<Map<String, dynamic>> machines = [];
  Map<String, String> previousStates = {};
  bool hasLoadedData = false;
  DateTime? lastFetchTime;

  factory MachineDataService() => _instance;
  MachineDataService._internal();

  void addVehicles(List<String> vehicleNumbers) {
    for (var vehicleNo in vehicleNumbers) {
      if (!machines.any((m) => m['Vehicle_No'] == vehicleNo)) {
        machines.add({
          'Vehicle_No': vehicleNo,
          'Vehicle_Name': vehicleNo,
          'Status': 'Inactive',
          'Location': 'Unknown',
          'IGN': 'OFF',
        });
        previousStates[vehicleNo] = 'Inactive';
      }
    }
  }

  Future<void> showNotification(String vehicleNo, String status, String ign) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'machine_status_channel',
      'Machine Status Notifications',
      channelDescription: 'Notifications for machine status changes',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      vehicleNo.hashCode,
      'Machine Status Changed',
      'Vehicle: $vehicleNo, Status: $status, IGN: $ign',
      notificationDetails,
      payload: vehicleNo,
    );
  }
}

Future<void> requestBatteryOptimizationPermission() async {
  final status = await Permission.ignoreBatteryOptimizations.status;
  if (!status.isGranted) {
    await Permission.ignoreBatteryOptimizations.request();
  }
}

Future<void> main() async {
  flutter.WidgetsFlutterBinding.ensureInitialized();

  // Initialize MongoDB
  final mongoService = MongoDBService();
  await mongoService.connect();

  // Load users from MongoDB
  try {
    UserManager.users = await mongoService.getAllPartners();
    print('Main: Loaded ${UserManager.users.length} users from Dashboard.partners');
    for (var user in UserManager.users) {
      print('Main: User ${user.userId}, Name: ${user.name}, Vehicles: ${user.vehicles}');
    }
  } catch (e) {
    print('Main: Error loading users: $e');
  }
  await UserManager.saveUsers();

  // Initialize notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'agrix_tracker',
    'Agrix Tracker Channel',
    description: 'Channel for Agrix GPS tracking notifications',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null) {
        final vehicleNo = response.payload!;
        runApp(MaterialApp(
          home: MachineStatusPage(
            isAdmin: false,
            loggedInUser: UserManager.findUser('default_user', 'pass'),
            language: 'English',
            initialVehicleNo: vehicleNo,
          ),
        ));
      }
    },
  );

  // Request permissions
  await requestPermissions();
  await checkDeviceAndPrompt(null); //handles android restriction

  // Initialize background service
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: "agrix_tracker",
      initialNotificationTitle: "Agrix GPS Tracker",
      initialNotificationContent: "Tracking vehicle data",
    ),
    iosConfiguration: IosConfiguration(),
  );
  await service.startService();
  await checkDeviceAndPrompt(null);
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    service.invoke(
      'setAsForeground',
      {
        'title': 'Agrix GPS Tracker',
        'content': 'Tracking vehicle data in the background',
      },
    );
  }
  print('Background service started at ${DateTime.now().toUtc().toIso8601String()}');

  // Initialize MongoDBService
  final mongoService = MongoDBService();
  bool isMongoConnected = false;
  try {
    await mongoService.connect();
    isMongoConnected = true;
    print('MongoDB connected in background');
  } catch (e, stackTrace) {
    print('MongoDB connection failed: $e\nStackTrace: $stackTrace');
  }

  // Load users to get vehicle numbers
  try {
    await UserManager.loadUsers();
  } catch (e, stackTrace) {
    print('Error loading users: $e\nStackTrace: $stackTrace');
  }

  // Monitor network changes
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
    print('Network status changed: $results at ${DateTime.now().toUtc().toIso8601String()}');
    if (results.any((result) => result != ConnectivityResult.none)) {
      try {
        if (!mongoService.isConnected) await mongoService.connect();
        await syncCachedData(mongoService);
        await mongoService.syncQueuedData();
        print('Synced all cached data on network change');
      } catch (e, stackTrace) {
        print('Error syncing data on network change: $e\nStackTrace: $stackTrace');
      }
    }
  });

  // Periodic task (every 1 minute, matching PieChartWidget)
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    try {
      if (!mongoService.isConnected) {
        try {
          await mongoService.connect();
          print('MongoDB reconnected in background');
        } catch (e, stackTrace) {
          print('MongoDB reconnection failed: $e\nStackTrace: $stackTrace');
        }
      }

      // Fetch vehicle numbers from UserManager
      final vehicleNumbers = UserManager.users.isNotEmpty
          ? UserManager.users.expand((user) => user.vehicles).map((v) => v.trim()).toList()
          : await mongoService.getAllVehicleNames();
      if (vehicleNumbers.isEmpty) {
        print('No vehicle numbers available in background');
        return;
      }

      final vehicleNoString = vehicleNumbers.join(',');
      final url =
          'http://13.127.144.213/webservice?token=getLiveData&user=Agrix&pass=123456&vehicle_no=$vehicleNoString&format=json';

      // Check network connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      print('Current network: $connectivityResult at ${DateTime.now().toUtc().toIso8601String()}');
      if (connectivityResult == ConnectivityResult.none) {
        print('No network, caching request for vehicles: $vehicleNoString');
        await cacheApiRequest(vehicleNoString);
        return;
      }

      final response = await http.get(Uri.parse(url));
      print('Background API Response: Status ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['root'] != null && jsonResponse['root']['VehicleData']?.isNotEmpty == true) {
          final vehicleDataList = jsonResponse['root']['VehicleData'] as List<dynamic>;
          for (var vehicleData in vehicleDataList) {
            final data = vehicleData as Map<String, dynamic>;
            final vehicleNo = data['Vehicle_No'] as String;
            if (!vehicleNumbers.contains(vehicleNo)) continue;
            data['fetchedAt'] = DateTime.now().toUtc().toIso8601String();

            // Save to vehicle-tracker database
            await mongoService.saveVehicleData(vehicleNo, data, fromApi: true);
            print('Saved vehicle data for $vehicleNo in background');
            if (service is AndroidServiceInstance) {
              service.invoke(
                'setAsForeground',
                {
                  'title': 'Agrix GPS Tracker',
                  'content': 'Tracking $vehicleNo',
                },
              );
            }
          }
        } else {
          print('No VehicleData in background response');
        }
      } else {
        print('Background API failed with status: ${response.statusCode}');
        await cacheApiRequest(vehicleNoString);
      }

      // Sync any queued data
      await syncCachedData(mongoService);
      await mongoService.syncQueuedData();
      print('Synced all cached data at ${DateTime.now().toUtc().toIso8601String()}');
    } catch (e, stackTrace) {
      print('Error in background task: $e\nStackTrace: $stackTrace');
    }
  });
}

Future<http.Response> getWithRetry(String url, {int retries = 3}) async {
  for (int i = 0; i < retries; i++) {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return response;
      print('Retry ${i + 1} failed with status: ${response.statusCode} for $url at ${DateTime.now().toUtc().toIso8601String()}');
    } catch (e, stackTrace) {
      print('Retry ${i + 1} failed: $e for $url\nStackTrace: $stackTrace');
      if (i == retries - 1) {
        await cacheApiRequest(url.split('vehicle_no=')[1].split('&')[0]);
        throw Exception('API request failed after $retries retries: $e');
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
  throw Exception('API request failed after $retries retries');
}

Future<void> cacheApiRequest(String vehicleNoString) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    List<String> cachedRequests = prefs.getStringList('api_cache') ?? [];
    cachedRequests.add(jsonEncode({
      'vehicleNoString': vehicleNoString,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
    }));
    await prefs.setStringList('api_cache', cachedRequests);
    print('Cached API request for vehicles: $vehicleNoString at ${DateTime.now().toUtc().toIso8601String()}');
  } catch (e, stackTrace) {
    print('Error caching API request: $e\nStackTrace: $stackTrace');
  }
}

Future<void> syncCachedData(MongoDBService mongoService) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    List<String> cachedRequests = prefs.getStringList('api_cache') ?? [];
    if (cachedRequests.isEmpty) {
      print('No cached API requests to sync at ${DateTime.now().toUtc().toIso8601String()}');
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('No network for syncing cached API data at ${DateTime.now().toUtc().toIso8601String()}');
      return;
    }
    if (connectivityResult == ConnectivityResult.none) {
      print('No network for syncing cached API data at ${DateTime.now().toUtc().toIso8601String()}');
      return;
    }

    if (!mongoService.isConnected) {
      try {
        await mongoService.connect();
      } catch (e) {
        print('Failed to connect for syncing API data: $e');
        return;
      }
    }
    List<String> remainingRequests = [];
    for (var request in cachedRequests) {
      final decoded = jsonDecode(request);
      final vehicleNoString = decoded['vehicleNoString'] as String;
      int attempts = decoded['attempts'] ?? 0;
      if (attempts >= 3) {
        print('Skipping cached request for $vehicleNoString: max attempts reached at ${DateTime.now().toUtc().toIso8601String()}');
        continue;
      }

      final url =
          'http://13.127.144.213/webservice?token=getLiveData&user=Agrix&pass=123456&vehicle_no=$vehicleNoString&format=json';

      try {
        final response = await getWithRetry(url);
        print('Sync API Response for $vehicleNoString: Status ${response.statusCode} at ${DateTime.now().toUtc().toIso8601String()}');
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          if (jsonResponse['root'] != null && jsonResponse['root']['VehicleData']?.isNotEmpty == true) {
            final vehicleDataList = jsonResponse['root']['VehicleData'] as List<dynamic>;
            for (var vehicleData in vehicleDataList) {
              final data = vehicleData as Map<String, dynamic>;
              final vehicleNo = data['Vehicle_No'] as String;
              data['fetchedAt'] = DateTime.now().toUtc().toIso8601String();
              await mongoService.saveVehicleData(vehicleNo, data, fromApi: true);
              print('Synced vehicle data for $vehicleNo from cache at ${DateTime.now().toUtc().toIso8601String()}');
            }
          }
        } else {
          print('Cached API request failed with status: ${response.statusCode} for $vehicleNoString');
          remainingRequests.add(jsonEncode({
            'vehicleNoString': vehicleNoString,
            'timestamp': decoded['timestamp'],
            'attempts': attempts + 1,
          }));
        }
      }catch (e, stackTrace) {
        print('Error syncing cached request for $vehicleNoString: $e\nStackTrace: $stackTrace');
        remainingRequests.add(jsonEncode({
          'vehicleNoString': vehicleNoString,
          'timestamp': decoded['timestamp'],
          'attempts': attempts + 1,
        }));
      }
    }await prefs.setStringList('api_cache', remainingRequests);
    if (remainingRequests.isEmpty) {
      print('Cleared cached API requests at ${DateTime.now().toUtc().toIso8601String()}');
    } else {
      print('Remaining cached API requests: ${remainingRequests.length} at ${DateTime.now().toUtc().toIso8601String()}');
    }
  } catch (e, stackTrace) {
    print('Error syncing cached API data: $e\nStackTrace: $stackTrace');
  }
}

// // Updated requestPermissions (ensure all necessary permissions)
// Future<void> requestPermissions() async {
//   await [
//     Permission.location,
//     Permission.notification,
//     Permission.storage,
//   ].request();
// }


class MyApp extends flutter.StatelessWidget {
  const MyApp({super.key});

  @override
  flutter.Widget build(flutter.BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await checkDeviceAndPrompt(context);
    });
    return flutter.MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AGRIX Dashboard',
      theme: flutter.ThemeData(
        primarySwatch: flutter.Colors.teal,
        primaryColor: const flutter.Color(0xFF00B899),
        brightness: flutter.Brightness.light,
        visualDensity: flutter.VisualDensity.adaptivePlatformDensity,
        cardTheme: const flutter.CardTheme(
          elevation: 4,
          margin: flutter.EdgeInsets.all(8),
          color: flutter.Colors.white,
        ),
        textTheme: const flutter.TextTheme(
          bodyMedium: flutter.TextStyle(color: flutter.Color(0xFF00B899)),
          headlineSmall: flutter.TextStyle(color: flutter.Colors.black),
          labelMedium: flutter.TextStyle(color: flutter.Colors.black),
        ),
        scaffoldBackgroundColor: flutter.Colors.transparent, // Still transparent, but not critical now
        appBarTheme: const flutter.AppBarTheme(
          backgroundColor: flutter.Color(0xFF00B899),
          foregroundColor: flutter.Colors.white,
          elevation: 4,
        ),
      ),
      home: flutter.FutureBuilder<flutter.Widget>(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == flutter.ConnectionState.waiting) {
            return const flutter.Center(child: flutter.CircularProgressIndicator());
          }
          return snapshot.data ?? const LoginPage();
        },
      ),
    );
  }

  Future<flutter.Widget> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await UserManager.loadUsers();
    final String? userJson = prefs.getString('loggedInUser');
    final bool isAdmin = prefs.getBool('isAdmin') ?? false;
    if (userJson != null) {
      final user = User.fromJson(jsonDecode(userJson));
      return HomePage(isAdmin: isAdmin, loggedInUser: user, initialLanguage: 'English');
    } else if (isAdmin) {
      return const HomePage(isAdmin: true, loggedInUser: null, initialLanguage: 'English');
    }
    return const LoginPage();
  }
}

// Added checkDeviceAndPrompt (assumed implementation)
Future<void> checkDeviceAndPrompt(BuildContext? context) async {
  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  final manufacturer = androidInfo.manufacturer.toLowerCase();
  final restrictiveManufacturers = ['xiaomi', 'huawei', 'oppo', 'vivo', 'samsung'];

  if (restrictiveManufacturers.contains(manufacturer)) {
    if (context != null) {
      // Show dialog to prompt user
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Enable Background Tracking'),
          content: const Text(
            'To ensure 24/7 tracking, please enable auto-start and disable battery optimization for Agrix Tracker in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  // Request battery optimization exemption
  if (await Permission.ignoreBatteryOptimizations.isDenied) {
    await Permission.ignoreBatteryOptimizations.request();
  }

  // Request exact alarm permission (Android 12+)
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }
}

// Placeholder for getDeviceManufacturer (replace with actual implementation)
Future<String> getDeviceManufacturer() async {
  // Use device_info_plus or similar package to get manufacturer
  return 'unknown';
}

// New BackgroundScaffold widget to apply the background globally
class BackgroundScaffold extends flutter.StatelessWidget {
  final flutter.Widget child;

  const BackgroundScaffold({super.key, required this.child});

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Stack(
      children: [
        flutter.Container(
          decoration: const flutter.BoxDecoration(
            image: flutter.DecorationImage(
              image: flutter.AssetImage('assets/bg-agrix.jpg'),
              fit: flutter.BoxFit.cover,
              opacity: 0.3,
            ),
          ),
        ),
        flutter.Scaffold(
          backgroundColor: flutter.Colors.transparent, // Transparent to show background
          body: child,
        ),
      ],
    );
  }
}

// User Model
class User {
  final String userId;
  final String? password;
  final List<String> vehicles;
  final String name;
  final String phone;
  final String? email;
  final String? partnerId;
  final List<String>? attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? cluster;

  User({
    required this.userId,
    this.password,
    required this.vehicles,
    required this.name,
    required this.phone,
    this.email,
    this.partnerId,
    this.attachments,
    this.createdAt,
    this.updatedAt,
    this.cluster,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] as String? ?? json['partnerId'] as String? ?? 'unknown_${json['_id']?.toHexString() ?? 'missing'}',
      password: json['password'] as String?,
      vehicles: (json['vehicles'] as List<dynamic>?)?.cast<String>() ?? [],
      name: json['name'] as String? ?? 'Unknown',
      phone: json['phone'] as String? ?? 'N/A',
      email: json['email'] as String?,
      partnerId: json['partnerId'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)?.cast<String>(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('Error parsing date: $value, error: $e');
        return null;
      }
    }
    if (value is Map && value['\$date'] is String) {
      try {
        return DateTime.parse(value['\$date']);
      } catch (e) {
        print('Error parsing \$date: $value, error: $e');
        return null;
      }
    }
    print('Unsupported date format: $value');
    return null;
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'password': password,
    'vehicles': vehicles,
    'name': name,
    'phone': phone,
    'email': email,
    'partnerId': partnerId,
    'attachments': attachments,
    'cluster': cluster,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  String get vehicleNumbers => vehicles.join(','); // Backward compatibility
}

class UserManager {
  static List<User> users = [];
  static MongoDBService mongoService = MongoDBService();

  static Future<void> loadUsers() async {
    try {
      users = await mongoService.getAllPartners();
      print('Loaded ${users.length} users from Dashboard.partners');
    } catch (e) {
      print('Error loading users from MongoDB: $e');
      users = [];
    }
  }

  static Future<void> saveUsers() async {
    // No-op: Users are stored in MongoDB, not SharedPreferences
  }

  static void addUser(User user) {
    users.removeWhere((u) => u.userId == user.userId);
    users.add(user);
    mongoService.savePartner(user);
  }

  static void updateUser(User updatedUser) {
    final index = users.indexWhere((u) => u.userId == updatedUser.userId);
    if (index != -1) {
      users[index] = updatedUser;
      mongoService.savePartner(updatedUser);
    }
  }

  static void deleteUser(String userId) {
    users.removeWhere((u) => u.userId == userId);
    mongoService.deletePartner(userId);
  }

  static User? findUser(String userId, String password) {
    try {
      return users.firstWhere(
            (user) => user.userId == userId && (user.password == password || user.password == null),
        orElse: () => User(
          userId: '',
          vehicles: [],
          name: 'Unknown',
          phone: '',
        ),
      );
    } catch (e) {
      print('Error finding user: $e');
      return null;
    }
  }

  static Future<User?> findUserByVehicleNo(String vehicleNo) async {
    try {
      final db = await Db.create('mongodb+srv://agrix:agrix1234@cluster0.1r955.mongodb.net/Dashboard?retryWrites=true&w=majority&appName=Cluster0');
      await db.open();
      final collection = db.collection('partners');
      final userDoc = await collection.findOne({'vehicles': vehicleNo});
      await db.close();
      return userDoc != null ? User.fromJson(userDoc) : null;
    } catch (e) {
      print('Error finding user by vehicleNo: $e');
      return null;
    }
  }
}

class TranslationService {
  static final Map<String, Map<String, String>> _translations = {
    'English': {
      'Login': 'Login',
      'Username': 'Username',
      'Password': 'Password',
      'Admin Login': 'Admin Login',
      'User Login': 'User Login',
      'Invalid credentials': 'Invalid credentials',
      'Dashboard': 'Dashboard',
      'Machine Tracking': 'Machine Tracking',
      'Machine Status': 'Machine Status',
      'Travel History': 'Travel History',
      'Travel Summary': 'Travel Summary',
      'Business': 'Business',
      'Announcement Details': 'Announcement Details',
      'AGRIX Menu': 'AGRIX Menu',
      'Alerts': 'Alerts',
      'No data available': 'No data available',
      'Enter Machine ID': 'Enter Machine ID',
      'Fetch Data': 'Fetch Data',
      'Schedule Date': 'Schedule Date',
      'Farmer ID': 'Farmer ID',
      'Plot ID': 'Plot ID',
      'Crop Type': 'Crop Type',
      'Cluster ID': 'Cluster ID',
      'Driver ID': 'Driver ID',
      'Start Time': 'Start Time',
      'Stop Time': 'Stop Time',
      'Vehicle Status': 'Vehicle Status',
      'Info': 'Info',
      'Map': 'Map',
      'Enter Vehicle Number': 'Enter Vehicle Number',
      'Add User': 'Add User',
      'Manage Users': 'Manage Users',
      'Name': 'Name',
      'Email': 'Email',
      'Phone': 'Phone',
      'Vehicle Numbers': 'Vehicle Numbers',
      'Save User': 'Save User',
      'Delete': 'Delete',
      'Edit': 'Edit',
      'Running': 'Running',
      'Inactive': 'Inactive',
      'Stop': 'Stop',
      'Idle': 'Idle',
      'No Data': 'No Data',
      'Search': 'Search',
      'Last Location': 'Last Location',
      'User': 'User',
      'User ID': 'User ID',
      'Logout': 'Logout',
      'Confirm Logout': 'Are you sure you want to logout?',
      'Yes': 'Yes',
      'No': 'No',
      'Refresh All': 'Refresh All',
      'Refresh This Machine': 'Refresh This Machine',
      'Select a machine': 'Select a machine',
      'No location data available': 'No location data available',
      'Next refresh in': 'Next refresh in',
      'Owner': 'Owner',
      'Location': 'Location',
      'Temperature': 'Temperature',
      'Speed': 'Speed',
      'Ignition': 'Ignition',
      'Battery': 'Battery',
      'Last Updated': 'Last Updated',
      'Vehicle Name': 'Vehicle Name',
      'Company': 'Company',
      'Vehicle No': 'Vehicle No',
      'Vehicle Type': 'Vehicle Type',
      'Status': 'Status',
      'GPS': 'GPS',
      'Latitude': 'Latitude',
      'Longitude': 'Longitude',
      'Odometer': 'Odometer',
      'Driver Name': 'Driver Name',
      'Branch': 'Branch',
      'POI': 'POI',
      'Immobilize State': 'Immobilize State',
      'SOS': 'SOS',
      'External Voltage': 'External Voltage',
      'Power': 'Power',
      'Door1': 'Door 1',
      'Door2': 'Door 2',
      'Door3': 'Door 3',
      'Door4': 'Door 4',
      'AC': 'AC',
      'IMEI': 'IMEI',
      'Angle': 'Angle',
      'Fuel': 'Fuel',
      'Show Map': 'Show Map',
    },
    'Hindi': {
      'Login': 'लॉगिन',
      'Username': 'उपयोगकर्ता नाम',
      'Password': 'पासवर्ड',
      'Admin Login': 'व्यवस्थापक लॉगिन',
      'User Login': 'उपयोगकर्ता लॉगिन',
      'Invalid credentials': 'अमान्य क्रेडेंशियल्स',
      'Dashboard': 'डैशबोर्ड',
      'Machine Tracking': 'मशीन ट्रैकिंग',
      'Machine Status': 'मशीन की स्थिति',
      'Travel History': 'यात्रा इतिहास',
      'Travel Summary': 'यात्रा सारांश',
      'Business': 'व्यापार',
      'Announcement Details': 'घोषणा विवरण',
      'AGRIX Menu': 'एग्रिक्स मेनू',
      'Alerts': 'चेतावनी',
      'No data available': 'कोई डेटा उपलब्ध नहीं है',
      'Enter Machine ID': 'मशीन आईडी दर्ज करें',
      'Fetch Data': 'डेटा प्राप्त करें',
      'Schedule Date': 'अनुसूची तिथि',
      'Farmer ID': 'किसान आईडी',
      'Plot ID': 'प्लॉट आईडी',
      'Crop Type': 'फसल का प्रकार',
      'Cluster ID': 'क्लस्टर आईडी',
      'Driver ID': 'ड्राइवर आईडी',
      'Start Time': 'प्रारंभ समय',
      'Stop Time': 'रोकने का समय',
      'Vehicle Status': 'वाहन स्थिति',
      'Info': 'जानकारी',
      'Map': 'नक्शा',
      'Enter Vehicle Number': 'वाहन संख्या दर्ज करें',
      'Add User': 'उपयोगकर्ता जोड़ें',
      'Manage Users': 'उपयोगकर्ता प्रबंधन',
      'Name': 'नाम',
      'Email': 'ईमेल',
      'Phone': 'फोन',
      'Vehicle Numbers': 'वाहन संख्याएं',
      'Save User': 'उपयोगकर्ता सहेजें',
      'Delete': 'हटाएं',
      'Edit': 'संपादन',
      'Running': 'चल रहा है',
      'Inactive': 'निष्क्रिय',
      'Stop': 'रोकें',
      'Idle': 'खड़ा हुआ',
      'No Data': 'कोई डेटा नहीं',
      'Search': 'खोज',
      'Last Location': 'अंतिम स्थान',
      'User': 'उपयोगकर्ता',
      'User ID': 'उपयोगकर्ता आईडी',
      'Logout': 'लॉगआउट',
      'Confirm Logout': 'क्या आप वाकई लॉगआउट करना चाहते हैं?',
      'Yes': 'हाँ',
      'No': 'नहीं',
      'Refresh All': 'सभी ताज़ा करें',
      'Refresh This Machine': 'इस मशीन को ताज़ा करें',
      'Select a machine': 'एक मशीन चुनें',
      'No location data available': 'कोई स्थान डेटा उपलब्ध नहीं',
      'Next refresh in': 'अगला ताज़ा करने में',
      'Owner': 'मालिक',
      'Location': 'स्थान',
      'Temperature': 'तापमान',
      'Speed': 'गति',
      'Ignition': 'इग्निशन',
      'Battery': 'बैटरी',
      'Last Updated': 'अंतिम अपडेट',
      'Vehicle Name': 'वाहन का नाम',
      'Company': 'कंपनी',
      'Vehicle No': 'वाहन संख्या',
      'Vehicle Type': 'वाहन का प्रकार',
      'Status': 'स्थिति',
      'GPS': 'जीपीएस',
      'Latitude': 'अक्षांश',
      'Longitude': 'देशांतर',
      'Odometer': 'ओडोमीटर',
      'Driver Name': 'ड्राइवर का नाम',
      'Branch': 'शाखा',
      'POI': 'रुचि का बिंदु',
      'Immobilize State': 'स्थिरीकरण स्थिति',
      'SOS': 'एसओएस',
      'External Voltage': 'बाहरी वोल्टेज',
      'Power': 'शक्ति',
      'Door1': 'दरवाजा 1',
      'Door2': 'दरवाजा 2',
      'Door3': 'दरवाजा 3',
      'Door4': 'दरवाजा 4',
      'AC': 'एसी',
      'IMEI': 'आईएमईआई',
      'Angle': 'कोण',
      'Fuel': 'ईंधन',
      'Show Map': 'नक्शा दिखाएं',
    },
  };

  static String translate(String key, String language) {
    return _translations[language]?[key] ?? key;
  }
}

class LoginPage extends flutter.StatefulWidget {
  const LoginPage({super.key});

  @override
  flutter.State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends flutter.State<LoginPage> {
  final _formKey = flutter.GlobalKey<flutter.FormState>();
  String _username = '';
  String _password = '';
  bool _isAdmin = false;
  String _selectedLanguage = 'English';

  final String _adminUsername = 'admin';
  final String _adminPassword = 'admin123';

  @override
  void initState() {
    super.initState();
    UserManager.loadUsers();
  }

  String translate(String key) => TranslationService.translate(key, _selectedLanguage);

  void _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final prefs = await SharedPreferences.getInstance();
      if (_isAdmin) {
        if (_username == _adminUsername && _password == _adminPassword) {
          await prefs.setBool('isAdmin', true);
          await prefs.remove('loggedInUser');
          flutter.Navigator.pushReplacement(
            context,
            flutter.MaterialPageRoute(
              builder: (context) => HomePage(
                isAdmin: true,
                loggedInUser: null,
                initialLanguage: _selectedLanguage,
              ),
            ),
          );
        } else {
          flutter.ScaffoldMessenger.of(context).showSnackBar(
            flutter.SnackBar(
              content: flutter.Text(translate('Invalid credentials')),
              backgroundColor: flutter.Colors.redAccent,
            ),
          );
        }
      } else {
        final user = UserManager.findUser(_username, _password);
        if (user != null) {
          await prefs.setString('loggedInUser', jsonEncode(user.toJson()));
          await prefs.setBool('isAdmin', false);
          flutter.Navigator.pushReplacement(
            context,
            flutter.MaterialPageRoute(
              builder: (context) => HomePage(
                isAdmin: false,
                loggedInUser: user,
                initialLanguage: _selectedLanguage,
              ),
            ),
          );
        } else {
          flutter.ScaffoldMessenger.of(context).showSnackBar(
            flutter.SnackBar(
              content: flutter.Text(translate('Invalid credentials')),
              backgroundColor: flutter.Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Scaffold(
      body: flutter.Container(
        decoration: const flutter.BoxDecoration(
          image: flutter.DecorationImage(
            image: flutter.AssetImage('assets/bg-agrix.jpg'),
            fit: flutter.BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: flutter.Scaffold(
          backgroundColor: flutter.Colors.transparent,
          appBar: flutter.AppBar(
            title: flutter.Text(translate('Login'), style: const flutter.TextStyle(color: flutter.Colors.white)),
            backgroundColor: const flutter.Color(0xFF00B899),
            elevation: 4,
            actions: [
              flutter.DropdownButton<String>(
                value: _selectedLanguage,
                items: <String>['English', 'Hindi']
                    .map((String value) => flutter.DropdownMenuItem<String>(
                  value: value,
                  child: flutter.Text(value, style: const flutter.TextStyle(color: flutter.Colors.white)),
                ))
                    .toList(),
                onChanged: (String? newValue) => setState(() => _selectedLanguage = newValue!),
                dropdownColor: const flutter.Color(0xFF00B899),
                icon: const flutter.Icon(flutter.Icons.language, color: flutter.Colors.white),
              ),
              const flutter.SizedBox(width: 10),
            ],
          ),
          body: flutter.SingleChildScrollView(
            child: flutter.Column(
              children: [
                flutter.Padding(
                  padding: const flutter.EdgeInsets.only(top: 60.0, bottom: 30.0),
                  child: flutter.Image.asset(
                    'assets/ezgif.com-gif-maker.gif',
                    height: 120,
                    width: 240,
                    fit: flutter.BoxFit.contain,
                  ),
                ),
                flutter.Padding(
                  padding: const flutter.EdgeInsets.all(24.0),
                  child: flutter.Form(
                    key: _formKey,
                    child: flutter.Card(
                      elevation: 8,
                      shape: flutter.RoundedRectangleBorder(borderRadius: flutter.BorderRadius.circular(16)),
                      color: flutter.Colors.white.withOpacity(0.9),
                      child: flutter.Padding(
                        padding: const flutter.EdgeInsets.all(20.0),
                        child: flutter.Column(
                          children: [
                            flutter.TextFormField(
                              decoration: flutter.InputDecoration(
                                labelText: translate('Username'),
                                border: flutter.OutlineInputBorder(borderRadius: flutter.BorderRadius.circular(12)),
                                prefixIcon: const flutter.Icon(flutter.Icons.person, color: flutter.Color(0xFF00B899)),
                                filled: true,
                                fillColor: flutter.Colors.grey[200],
                              ),
                              validator: (value) => value!.isEmpty ? translate('Username cannot be empty') : null,
                              onSaved: (value) => _username = value!,
                            ),
                            const flutter.SizedBox(height: 20),
                            flutter.TextFormField(
                              decoration: flutter.InputDecoration(
                                labelText: translate('Password'),
                                border: flutter.OutlineInputBorder(borderRadius: flutter.BorderRadius.circular(12)),
                                prefixIcon: const flutter.Icon(flutter.Icons.lock, color: flutter.Color(0xFF00B899)),
                                filled: true,
                                fillColor: flutter.Colors.grey[200],
                              ),
                              obscureText: true,
                              validator: (value) => value!.isEmpty ? translate('Password cannot be empty') : null,
                              onSaved: (value) => _password = value!,
                            ),
                            const flutter.SizedBox(height: 30),
                            flutter.ElevatedButton(
                              onPressed: _login,
                              style: flutter.ElevatedButton.styleFrom(
                                backgroundColor: const flutter.Color(0xFF00B899),
                                padding: const flutter.EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                shape: flutter.RoundedRectangleBorder(borderRadius: flutter.BorderRadius.circular(12)),
                                elevation: 5,
                              ),
                              child: flutter.Text(
                                _isAdmin ? translate('Admin Login') : translate('User Login'),
                                style: const flutter.TextStyle(fontSize: 16, color: flutter.Colors.white),
                              ),
                            ),
                            const flutter.SizedBox(height: 20),
                            flutter.SwitchListTile(
                              title: flutter.Text(
                                _isAdmin ? translate('Admin Login') : translate('User Login'),
                                style: const flutter.TextStyle(color: flutter.Colors.black87),
                              ),
                              value: _isAdmin,
                              activeColor: const flutter.Color(0xFF00B899),
                              onChanged: (bool value) => setState(() => _isAdmin = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends flutter.StatefulWidget {
  final bool isAdmin;
  final User? loggedInUser;
  final String initialLanguage;

  const HomePage({
    super.key,
    required this.isAdmin,
    required this.loggedInUser,
    required this.initialLanguage,
  });

  @override
  flutter.State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends flutter.State<HomePage> {
  final flutter.GlobalKey<flutter.ScaffoldState> _scaffoldKey = flutter.GlobalKey<flutter.ScaffoldState>();
  late String _selectedLanguage;
  void Function()? _refreshPieChart;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  String translate(String key) => TranslationService.translate(key, _selectedLanguage);

  void _setRefreshCallback(void Function() refresh) {
    _refreshPieChart = refresh;
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Scaffold(
      body: flutter.Container(
        decoration: const flutter.BoxDecoration(
          image: flutter.DecorationImage(
            image: flutter.AssetImage('assets/dashboard-bg.jpg'),
            fit: flutter.BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: flutter.Scaffold(
          key: _scaffoldKey,
          backgroundColor: flutter.Colors.transparent, // Transparent to show background
          appBar: flutter.AppBar(
            title: flutter.Text(translate('Dashboard')),
            leading: flutter.IconButton(
              icon: const flutter.Icon(flutter.Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            actions: [
              flutter.DropdownButton<String>(
                value: _selectedLanguage,
                items: <String>['English', 'Hindi'].map((String value) {
                  return flutter.DropdownMenuItem<String>(value: value, child: flutter.Text(value));
                }).toList(),
                onChanged: (String? newValue) => setState(() => _selectedLanguage = newValue!),
              ),
            ],
          ),
          drawer: Sidebar(
            isAdmin: widget.isAdmin,
            language: _selectedLanguage,
            onLogout: () => _refreshPieChart?.call(),
            onPieChartRefresh: _refreshPieChart,
          ),
          body: PieChartWidget(
            isAdmin: widget.isAdmin,
            loggedInUser: widget.loggedInUser,
            language: _selectedLanguage,
            onRefreshSet: _setRefreshCallback,
          ),
        ),
      ),
    );
  }
}

class PieChartWidget extends flutter.StatefulWidget {
  final bool isAdmin;
  final User? loggedInUser;
  final String language;
  final void Function(void Function()) onRefreshSet;

  const PieChartWidget({
    super.key,
    required this.isAdmin,
    required this.loggedInUser,
    required this.language,
    required this.onRefreshSet,
  });

  @override
  flutter.State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends flutter.State<PieChartWidget> with flutter.TickerProviderStateMixin {
  List<PieChartSectionData> sections = [];
  bool _isLoading = true;
  late Timer _timer;
  final MachineDataService _dataService = MachineDataService();
  final MongoDBService _mongoService = MongoDBService();

  late flutter.AnimationController _animationController;
  late flutter.Animation<double> _animation;
  late flutter.AnimationController _rotationController;
  late flutter.Animation<double> _rotationAnimation;
  List<double> _animatedValues = [0, 0, 0, 0, 0]; // Running, Stop, Inactive, Idle, No Data
  int? _touchedIndex;
  flutter.OverlayEntry? _tooltipOverlay;

  bool _isDarkMode = true;
  List<int> _hiddenIndices = [];

  List<String> get titles => [
    translate('Running'),
    translate('Stop'),
    translate('Inactive'),
    translate('Idle'),
    translate('No Data'),
  ];

  final List<List<flutter.Color>> _lightThemeSectionColors = [
    [flutter.Colors.green.shade300, flutter.Colors.green.shade500, flutter.Colors.green.shade700], // Running
    [flutter.Colors.red.shade300, flutter.Colors.red.shade500, flutter.Colors.red.shade700], // Stop
    [flutter.Colors.grey.shade300, flutter.Colors.grey.shade500, flutter.Colors.grey.shade700], // Inactive
    [flutter.Colors.yellow.shade300, flutter.Colors.yellow.shade500, flutter.Colors.yellow.shade700], // Idle
    [flutter.Colors.blue.shade300, flutter.Colors.blue.shade500, flutter.Colors.blue.shade700], // No Data
  ];
  final List<List<flutter.Color>> _darkThemeSectionColors = [
    [flutter.Colors.green.shade600, flutter.Colors.green.shade400, flutter.Colors.lime.shade300], // Running
    [flutter.Colors.red.shade800, flutter.Colors.red.shade600, flutter.Colors.pink.shade400], // Stop
    [flutter.Colors.grey.shade600, flutter.Colors.grey.shade400, flutter.Colors.grey.shade200], // Inactive
    [flutter.Colors.yellow.shade700, flutter.Colors.yellow.shade500, flutter.Colors.yellow.shade300], // Idle
    [flutter.Colors.blue.shade800, flutter.Colors.blue.shade600, flutter.Colors.blue.shade400], // No Data
  ];

  List<flutter.Color> _getSectionColors(int index) {
    final colors = _isDarkMode ? _darkThemeSectionColors : _lightThemeSectionColors;
    return colors[index % colors.length];
  }

  flutter.Color get _textColor => _isDarkMode ? flutter.Colors.white : flutter.Colors.black87;
  flutter.Color get _shadowColor => _isDarkMode ? flutter.Colors.black.withOpacity(0.5) : flutter.Colors.grey.withOpacity(0.4);
  flutter.Color get _containerBgColorStart => _isDarkMode ? flutter.Colors.grey[900]! : flutter.Colors.white;
  flutter.Color get _containerBgColorEnd => _isDarkMode ? flutter.Colors.black87 : flutter.Colors.grey[200]!;

  @override
  void initState() {
    super.initState();
    _animationController = flutter.AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = flutter.Tween<double>(begin: 0, end: 1).animate(
      flutter.CurvedAnimation(parent: _animationController, curve: flutter.Curves.easeInOutCubic),
    );
    _rotationController = flutter.AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _rotationAnimation = flutter.Tween<double>(begin: 0, end: 1).animate(
      flutter.CurvedAnimation(parent: _rotationController, curve: flutter.Curves.elasticOut),
    );
    widget.onRefreshSet(_fetchMachineData);
    _fetchMachineData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _rotationController.dispose();
    _timer.cancel();
    _removeTooltip();
    _mongoService.close();
    super.dispose();
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _fetchMachineData();
    });
  }

  String translate(String key) => TranslationService.translate(key, widget.language);

  Future<void> _fetchMachineData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    List<String> vehicleNumbers = widget.isAdmin
        ? UserManager.users.expand((user) => user.vehicles).map((v) => v.trim()).toSet().toList()
        : widget.loggedInUser?.vehicles.map((v) => v.trim()).toList() ?? [];

    int runningCount = 0;
    int stopCount = 0;
    int inactiveCount = 0;
    int idleCount = 0;
    int noDataCount = 0;
    final vehicleNoString = vehicleNumbers.join(',');
    final url =
        'http://13.127.144.213/webservice?token=getLiveData&user=Agrix&pass=123456&vehicle_no=$vehicleNoString&format=json';

    Map<String, Map<String, dynamic>> vehicleDataMap = {
      for (var vehicleNo in vehicleNumbers)
        vehicleNo: {
          'Vehicle_No': vehicleNo,
          'Vehicle_Name': vehicleNo,
          'Status': 'No Data',
          'Location': 'Unknown',
          'IGN': 'OFF',
          'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        }
    };

    try {
      print('Fetching API data for vehicles: $vehicleNoString');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['root'] != null && jsonResponse['root']['VehicleData']?.isNotEmpty == true) {
          final vehicleDataList = jsonResponse['root']['VehicleData'] as List<dynamic>;
          for (var vehicleData in vehicleDataList) {
            final data = vehicleData as Map<String, dynamic>;
            final vehicleNo = data['Vehicle_No'] as String;
            if (!vehicleNumbers.contains(vehicleNo)) continue;
            data['fetchedAt'] = DateTime.now().toUtc().toIso8601String();
            final status = data['Status']?.toString().toUpperCase() ?? 'NO DATA';
            final ign = data['IGN']?.toString().toUpperCase() ?? 'OFF';
            if (status == 'RUNNING' || status == 'MOVING') runningCount++;
            else if (status == 'STOP') stopCount++;
            else if (status == 'IDLE') idleCount++;
            else if (status == 'NO DATA') noDataCount++;
            else inactiveCount++;
            String currentState = status == 'RUNNING' || status == 'MOVING'
                ? 'Running'
                : status == 'STOP'
                ? 'Stop'
                : status == 'IDLE'
                ? 'Idle'
                : status == 'NO DATA'
                ? 'No Data'
                : 'Inactive';
            if (_dataService.previousStates[vehicleNo] != currentState) {
              await _dataService.showNotification(vehicleNo, currentState, ign);
            }
            _dataService.previousStates[vehicleNo] = currentState;
            vehicleDataMap[vehicleNo] = data;
            await _mongoService.saveVehicleData(vehicleNo, data, fromApi: true);
            print('Saved API data for $vehicleNo: $data');
          }
        }
      }
      for (var vehicleNo in vehicleNumbers) {
        if (vehicleDataMap[vehicleNo]?['Status'] == 'No Data') {
          final latestData = await _mongoService.getLatestVehicleData(vehicleNo);
          if (latestData != null) {
            vehicleDataMap[vehicleNo] = latestData;
            final status = latestData['Status']?.toString().toUpperCase() ?? 'NO DATA';
            if (status == 'RUNNING' || status == 'MOVING') runningCount++;
            else if (status == 'STOP') stopCount++;
            else if (status == 'IDLE') idleCount++;
            else if (status == 'NO DATA') noDataCount++;
            else inactiveCount++;
            vehicleDataMap[vehicleNo]!['Status'] = status;
            print('Fetched MongoDB data for $vehicleNo: $latestData');
          } else {
            noDataCount++;
          }
        }
      }
    } catch (e) {
      print('Error fetching API data: $e');
      for (var vehicleNo in vehicleNumbers) {
        if (vehicleDataMap[vehicleNo]?['Status'] == 'No Data') {
          final latestData = await _mongoService.getLatestVehicleData(vehicleNo);
          if (latestData != null) {
            vehicleDataMap[vehicleNo] = latestData;
            final status = latestData['Status']?.toString().toUpperCase() ?? 'NO DATA';
            if (status == 'RUNNING' || status == 'MOVING') runningCount++;
            else if (status == 'STOP') stopCount++;
            else if (status == 'IDLE') idleCount++;
            else if (status == 'NO DATA') noDataCount++;
            else inactiveCount++;
            vehicleDataMap[vehicleNo]!['Status'] = status;
            print('Fetched MongoDB fallback for $vehicleNo: $latestData');
          } else {
            noDataCount++;
          }
        }
      }
    }
    if (!mounted) return;
    _dataService.machines.clear();
    _dataService.machines.addAll(vehicleDataMap.values);
    setState(() {
      _animatedValues = [
        runningCount.toDouble(),
        stopCount.toDouble(),
        inactiveCount.toDouble(),
        idleCount.toDouble(),
        noDataCount.toDouble(),
      ];
      _isLoading = false;
      _dataService.lastFetchTime = DateTime.now();
      _animationController.forward(from: 0);
      _rotationController.forward(from: 0);
    });
    print('Pie chart counts: Running=$runningCount, Stop=$stopCount, Inactive=$inactiveCount, Idle=$idleCount, No Data=$noDataCount');
  }

  List<PieChartSectionData> _buildChartSections() {
    List<PieChartSectionData> builtSections = [];
    for (int i = 0; i < _animatedValues.length; i++) {
      if (_hiddenIndices.contains(i)) continue;
      final isTouched = _touchedIndex == i;
      final double radius = isTouched ? 105 : 90;
      final double fontSize = isTouched ? 20 : 18;
      final List<flutter.Color> sectionGradientColors = _getSectionColors(i);
      double opacity = 1.0;
      if (_touchedIndex != null && _touchedIndex != i) opacity = 0.5;
      builtSections.add(PieChartSectionData(
        color: sectionGradientColors.first.withOpacity(opacity),
        gradient: LinearGradient(
          colors: sectionGradientColors.map((c) => c.withOpacity(opacity)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        value: 1.0 * _animation.value,
        title: _animatedValues[i].toInt().toString(),
        radius: radius * _animation.value,
        titleStyle: flutter.TextStyle(
          fontSize: fontSize,
          fontWeight: flutter.FontWeight.w900,
          color: _textColor.withOpacity(opacity),
          shadows: [flutter.Shadow(color: _shadowColor.withOpacity(opacity * 0.7), blurRadius: 3)],
        ),
        titlePositionPercentageOffset: 0.55,
        borderSide: isTouched
            ? flutter.BorderSide(color: _textColor, width: 3)
            : flutter.BorderSide(color: _textColor.withOpacity(0.7), width: 1.5),
      ));
    }
    return builtSections;
  }

  void _showTooltip(int index, flutter.Offset globalPosition, flutter.BuildContext chartContext) {
    _removeTooltip();
    if (_hiddenIndices.contains(index)) return;
    final currentBuiltSections = _buildChartSections();
    final sectionData = currentBuiltSections.firstWhere(
          (s) => _getOriginalIndexFromChartSection(s, currentBuiltSections) == index,
      orElse: () => currentBuiltSections.isNotEmpty ? currentBuiltSections.first : PieChartSectionData(),
    );
    final title = sectionData.title?.split('\n')[0] ?? titles[index];
    final count = _animatedValues[index].toInt();
    final flutter.RenderBox overlay = flutter.Overlay.of(chartContext).context.findRenderObject() as flutter.RenderBox;
    final flutter.Offset localPosition = overlay.globalToLocal(globalPosition);
    _tooltipOverlay = flutter.OverlayEntry(
      builder: (context) => flutter.Positioned(
        left: localPosition.dx - 75,
        top: localPosition.dy - 80,
        child: flutter.Material(
          color: flutter.Colors.transparent,
          child: flutter.Stack(
            clipBehavior: flutter.Clip.none,
            children: [
              flutter.Container(
                padding: const flutter.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: flutter.BoxDecoration(
                  color: (_isDarkMode ? flutter.Colors.grey[800] : flutter.Colors.white)!.withOpacity(0.95),
                  borderRadius: flutter.BorderRadius.circular(12),
                  boxShadow: [
                    flutter.BoxShadow(
                      color: _shadowColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const flutter.Offset(0, 4),
                    ),
                  ],
                ),
                child: flutter.Text(
                  '${titles[index]}: $count',
                  style: flutter.TextStyle(color: _textColor, fontSize: 16, fontWeight: flutter.FontWeight.bold),
                ),
              ),
              flutter.Positioned(
                left: 65,
                bottom: -8,
                child: flutter.Transform.rotate(
                  angle: math.pi / 4,
                  child: flutter.Container(
                    width: 16,
                    height: 16,
                    decoration: flutter.BoxDecoration(
                      color: (_isDarkMode ? flutter.Colors.grey[800] : flutter.Colors.white)!.withOpacity(0.95),
                      boxShadow: [
                        flutter.BoxShadow(
                          color: _shadowColor.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const flutter.Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    flutter.Overlay.of(chartContext).insert(_tooltipOverlay!);
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  void _showMachineDetails(int touchedIndex) async {
    if (_hiddenIndices.contains(touchedIndex)) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const flutter.Center(
        child: flutter.CircularProgressIndicator(),
      ),
    );

    String status = touchedIndex == 0
        ? 'Running'
        : touchedIndex == 1
        ? 'Stop'
        : touchedIndex == 2
        ? 'Inactive'
        : touchedIndex == 3
        ? 'Idle'
        : 'No Data';
    final uniqueMachines = <String, Map<String, dynamic>>{};
    for (var machine in _dataService.machines) {
      final apiStatus = machine['Status']?.toString().toUpperCase() ?? 'NO DATA';
      bool matchesStatus = false;
      if (status == 'Running') {
        matchesStatus = apiStatus == 'RUNNING' || apiStatus == 'MOVING';
      } else if (status == 'Stop') {
        matchesStatus = apiStatus == 'STOP';
      } else if (status == 'Idle') {
        matchesStatus = apiStatus == 'IDLE';
      } else if (status == 'No Data') {
        matchesStatus = apiStatus == 'NO DATA';
      } else {
        matchesStatus = apiStatus != 'RUNNING' && apiStatus != 'MOVING' && apiStatus != 'STOP' && apiStatus != 'IDLE' && apiStatus != 'NO DATA';
      }
      if (matchesStatus) {
        final vehicleNo = machine['Vehicle_No'] as String? ?? 'N/A';
        uniqueMachines[vehicleNo] = machine;
      }
    }
    final filteredMachines = uniqueMachines.values.toList();

    Map<String, String> vehicleToOwner = {};
    for (var machine in filteredMachines) {
      final vehicleNo = machine['Vehicle_No'] as String? ?? 'N/A';
      final user = UserManager.users.firstWhere(
            (user) => user.vehicles.contains(vehicleNo),
        orElse: () => User(
          userId: '',
          vehicles: [],
          name: 'Unknown',
          phone: '',
        ),
      );
      vehicleToOwner[vehicleNo] = user.name;
      print('Vehicle $vehicleNo mapped to owner: ${vehicleToOwner[vehicleNo]} (userId: ${user.userId})');
    }

    flutter.Navigator.pop(context);

    flutter.Navigator.push(
      context,
      flutter.MaterialPageRoute(
        builder: (context) => VehicleListPage(
          status: status,
          machines: filteredMachines,
          vehicleToOwner: vehicleToOwner,
          isDarkMode: _isDarkMode,
          translate: translate,
          sectionColors: _getSectionColors(touchedIndex),
          textColor: _textColor,
        ),
      ),
    );
  }

  flutter.Widget _buildLegend() {
    return flutter.Padding(
      padding: const flutter.EdgeInsets.symmetric(vertical: 8.0),
      child: flutter.Wrap(
        alignment: flutter.WrapAlignment.center,
        spacing: 12.0,
        runSpacing: 8.0,
        children: List.generate(titles.length, (index) {
          final colors = _getSectionColors(index);
          return flutter.Row(
            mainAxisSize: flutter.MainAxisSize.min,
            children: [
              flutter.Container(
                width: 16,
                height: 16,
                decoration: flutter.BoxDecoration(
                  shape: flutter.BoxShape.circle,
                  gradient: flutter.LinearGradient(
                    colors: colors,
                    begin: flutter.Alignment.topLeft,
                    end: flutter.Alignment.bottomRight,
                  ),
                  boxShadow: [
                    flutter.BoxShadow(
                      color: _shadowColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const flutter.Offset(1, 1),
                    ),
                  ],
                ),
              ),
              const flutter.SizedBox(width: 6),
              flutter.Text(
                titles[index],
                style: flutter.TextStyle(
                  color: _textColor,
                  fontSize: 14,
                  fontWeight: flutter.FontWeight.w600,
                  shadows: [
                    flutter.Shadow(
                      color: _shadowColor.withOpacity(0.2),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  int _getOriginalIndexFromChartSection(PieChartSectionData touchedSectionData, List<PieChartSectionData> currentSections) {
    int visibleIndex = currentSections.indexOf(touchedSectionData);
    if (visibleIndex == -1) return -1;
    int originalIdx = -1;
    int currentVisibleCount = 0;
    for (int i = 0; i < _animatedValues.length; i++) {
      if (!_hiddenIndices.contains(i)) {
        if (currentVisibleCount == visibleIndex) {
          originalIdx = i;
          break;
        }
        currentVisibleCount++;
      }
    }
    return originalIdx;
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    if (_isLoading) return flutter.Center(child: flutter.CircularProgressIndicator(color: _getSectionColors(0).first));
    double totalValue = _animatedValues.fold(0.0, (sum, value) => sum + value);
    return flutter.Scaffold(
      backgroundColor: flutter.Colors.transparent,
      body: flutter.Container(
        padding: const flutter.EdgeInsets.all(20),
        decoration: flutter.BoxDecoration(
          borderRadius: flutter.BorderRadius.circular(20),
          gradient: flutter.RadialGradient(
            center: flutter.Alignment.center,
            radius: 1.0,
            colors: [_containerBgColorStart, _containerBgColorEnd],
            stops: [0.3, 1.0],
          ),
          boxShadow: [
            flutter.BoxShadow(
              color: _shadowColor.withOpacity(0.2),
              blurRadius: 15,
              offset: const flutter.Offset(0, 5),
            ),
          ],
        ),
        child: flutter.Column(
          children: [
            flutter.Row(
              mainAxisAlignment: flutter.MainAxisAlignment.spaceBetween,
              children: [
                flutter.Text(
                  translate('Dashboard'),
                  style: flutter.TextStyle(
                    fontSize: 28,
                    fontWeight: flutter.FontWeight.bold,
                    color: _textColor,
                    shadows: [
                      flutter.Shadow(
                        color: _shadowColor,
                        offset: const flutter.Offset(1, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
                flutter.IconButton(
                  icon: flutter.Icon(
                    _isDarkMode ? flutter.Icons.light_mode : flutter.Icons.dark_mode,
                    color: _textColor,
                  ),
                  onPressed: () => setState(() {
                    _isDarkMode = !_isDarkMode;
                    _animationController.forward(from: 0);
                  }),
                ),
              ],
            ),
            const flutter.SizedBox(height: 10),
            flutter.Expanded(
              child: flutter.Center(
                child: flutter.ConstrainedBox(
                  constraints: flutter.BoxConstraints(
                    maxHeight: flutter.MediaQuery.of(context).size.height * 0.4,
                    maxWidth: flutter.MediaQuery.of(context).size.width * 0.8,
                  ),
                  child: flutter.AnimatedBuilder(
                    animation: flutter.Listenable.merge([_animation, _rotationAnimation]),
                    builder: (context, child) {
                      final currentSections = _buildChartSections();
                      return flutter.Stack(
                        alignment: flutter.Alignment.center,
                        children: [
                          flutter.Transform.scale(
                            scale: _touchedIndex != null ? 1.05 : 1.0,
                            child: flutter.RotationTransition(
                              turns: _rotationAnimation,
                              child: PieChart(
                                PieChartData(
                                  sections: currentSections,
                                  centerSpaceRadius: 70,
                                  sectionsSpace: 2.5,
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
                                      if (event is FlTapUpEvent || event is FlLongPressEnd) _removeTooltip();
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection == null) {
                                        if (_touchedIndex != null) setState(() => _touchedIndex = null);
                                        return;
                                      }
                                      final touchedSection = pieTouchResponse.touchedSection!;
                                      final originalIndex = _getOriginalIndexFromChartSection(touchedSection.touchedSection!, currentSections);
                                      if (originalIndex != -1 && !_hiddenIndices.contains(originalIndex)) {
                                        setState(() {
                                          if (_touchedIndex == originalIndex) _showMachineDetails(originalIndex);
                                          else _touchedIndex = originalIndex;
                                        });
                                        if (event.localPosition != null) {
                                          final flutter.Offset touchPosition = event.localPosition!;
                                          final flutter.RenderBox renderBox = context.findRenderObject() as flutter.RenderBox;
                                          final flutter.Offset globalPosition = renderBox.localToGlobal(touchPosition);
                                          _showTooltip(originalIndex, globalPosition, context);
                                        }
                                      } else {
                                        if (_touchedIndex != null) setState(() => _touchedIndex = null);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          flutter.Column(
                            mainAxisSize: flutter.MainAxisSize.min,
                            children: [
                              flutter.Text(
                                totalValue.toInt().toString(),
                                style: flutter.TextStyle(
                                  fontSize: 36,
                                  fontWeight: flutter.FontWeight.w900,
                                  color: _textColor,
                                  shadows: [
                                    flutter.Shadow(
                                      color: _shadowColor,
                                      offset: const flutter.Offset(1, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              flutter.Text(
                                translate('Total Machines'),
                                style: flutter.TextStyle(
                                  fontSize: 16,
                                  color: _textColor.withOpacity(0.8),
                                  fontWeight: flutter.FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            _buildLegend(),
            const flutter.SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class VehicleListPage extends flutter.StatelessWidget {
  final String status;
  final List<Map<String, dynamic>> machines;
  final Map<String, String> vehicleToOwner;
  final bool isDarkMode;
  final String Function(String) translate;
  final List<flutter.Color> sectionColors;
  final flutter.Color textColor;

  const VehicleListPage({
    super.key,
    required this.status,
    required this.machines,
    required this.vehicleToOwner,
    required this.isDarkMode,
    required this.translate,
    required this.sectionColors,
    required this.textColor,
  });

  @override
  flutter.Widget build(flutter.BuildContext context) {
    final shadowColor = isDarkMode ? flutter.Colors.black.withOpacity(0.5) : flutter.Colors.grey.withOpacity(0.4);
    print('VehicleListPage machines: ${machines.length}');
    return flutter.Scaffold(
      backgroundColor: isDarkMode ? flutter.Colors.grey[900] : flutter.Colors.grey[100],
      appBar: flutter.AppBar(
        backgroundColor: isDarkMode ? flutter.Colors.grey[850] : flutter.Colors.white,
        elevation: 2,
        leading: flutter.IconButton(
          icon: flutter.Icon(flutter.Icons.arrow_back, color: textColor),
          onPressed: () => flutter.Navigator.pop(context),
        ),
        title: flutter.Row(
          children: [
            flutter.Icon(
              status == 'Running'
                  ? flutter.Icons.directions_run
                  : status == 'Stop'
                  ? flutter.Icons.stop_circle_outlined
                  : status == 'Inactive'
                  ? flutter.Icons.power_settings_new
                  : status == 'Idle'
                  ? flutter.Icons.hourglass_empty
                  : flutter.Icons.cloud_off,
              color: sectionColors.last,
              size: 28,
            ),
            const flutter.SizedBox(width: 10),
            flutter.Expanded(
              child: flutter.Text(
                '$status Machines (${machines.length})',
                style: flutter.TextStyle(
                  fontSize: 22,
                  fontWeight: flutter.FontWeight.bold,
                  color: textColor,
                ),
                overflow: flutter.TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: machines.isEmpty
          ? flutter.Center(
        child: flutter.Text(
          translate('No machines in this category.'),
          style: flutter.TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 18,
          ),
        ),
      )
          : flutter.ListView.builder(
        padding: const flutter.EdgeInsets.all(16),
        itemCount: machines.length,
        itemBuilder: (context, index) {
          final machine = machines[index];
          final vehicleNo = machine['Vehicle_No'] as String? ?? 'N/A';
          final owner = vehicleToOwner[vehicleNo] ?? 'Unknown';
          print('Machine $index: $machine');
          return flutter.GestureDetector(
            onTap: () {
              flutter.Navigator.push(
                context,
                flutter.MaterialPageRoute(
                  builder: (context) => VehicleMapPage(
                    machine: machine,
                    isDarkMode: isDarkMode,
                    translate: translate,
                    textColor: textColor,
                  ),
                ),
              );
            },
            child: flutter.Card(
              elevation: isDarkMode ? 3 : 2,
              margin: const flutter.EdgeInsets.symmetric(vertical: 8),
              color: isDarkMode ? flutter.Colors.grey[800] : flutter.Colors.grey[50],
              shape: flutter.RoundedRectangleBorder(borderRadius: flutter.BorderRadius.circular(12)),
              child: flutter.ListTile(
                contentPadding: const flutter.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leading: flutter.Icon(
                  flutter.Icons.directions_car,
                  color: sectionColors.last.withOpacity(0.8),
                  size: 28,
                ),
                title: flutter.Text(
                  machine['Vehicle_Name'] as String? ?? vehicleNo,
                  style: flutter.TextStyle(
                    fontWeight: flutter.FontWeight.bold,
                    color: textColor,
                    fontSize: 18,
                  ),
                ),
                subtitle: flutter.Column(
                  crossAxisAlignment: flutter.CrossAxisAlignment.start,
                  children: [
                    const flutter.SizedBox(height: 8),
                    flutter.Text(
                      '${translate('Vehicle No')}: $vehicleNo',
                      style: flutter.TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                    flutter.Text(
                      '${translate('Last Location')}: ${machine['Location'] ?? 'Unknown'}',
                      style: flutter.TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                    flutter.Text(
                      '${translate('Owner')}: $owner',
                      style: flutter.TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VehicleMapPage extends flutter.StatefulWidget {
  final Map<String, dynamic> machine;
  final bool isDarkMode;
  final String Function(String) translate;
  final flutter.Color textColor;

  const VehicleMapPage({
    super.key,
    required this.machine,
    required this.isDarkMode,
    required this.translate,
    required this.textColor,
  });

  @override
  flutter.State<VehicleMapPage> createState() => _VehicleMapPageState();
}

class _VehicleMapPageState extends flutter.State<VehicleMapPage> {
  late MapController _mapController;
  List<Map<String, dynamic>> _locationHistory = [];
  bool _isLoading = false;
  String? _errorMessage;
  final MongoDBService _mongoService = MongoDBService();
  bool _isPlaying = false;
  int _currentStep = 0;
  Timer? _animationTimer;
  LatLng? _currentVehiclePosition;
  bool _isFetching = false;
  bool _showHistory = false;
  String _selectedTimeRange = '30d';
  final List<Map<String, String>> _timeRangeOptions = [
    {'value': '24h', 'label': 'Past 24 Hours'},
    {'value': '7d', 'label': 'Past 7 Days'},
    {'value': '30d', 'label': 'Past 30 Days'},
    {'value': '90d', 'label': 'Past 90 Days'},
  ];
  double _playbackSpeed = 1.0;
  final List<double> _speedOptions = [1.0, 1.25, 1.5, 1.75, 2.0];
  Completer<void>? _fetchCompleter;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    print('VehicleMapPage machine: ${widget.machine}');
    _initializeMongoDB();
  }

  @override
  void dispose() {
    print('Disposing VehicleMapPageState');
    _fetchCompleter?.complete();
    _fetchCompleter = null;
    _animationTimer?.cancel();
    _isFetching = false;
    _mongoService.close();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeMongoDB() async {
    try {
      if (!_mongoService.isConnected || _mongoService._vehicleDb == null) {
        print('Initializing MongoDB connection...');
        await _mongoService.connect();
        print('MongoDB connected successfully');
      }
    } catch (e) {
      print('MongoDB init error: $e');
      if (mounted) {
        setState(() => _errorMessage = widget.translate('Failed to connect to database'));
      }
    }
  }

  LatLng? _getVehiclePosition() {
    final lat = widget.machine['Latitude'];
    final lon = widget.machine['Longitude'];
    double? latParsed = _parseCoordinate(lat);
    double? lonParsed = _parseCoordinate(lon);
    if (latParsed == null || lonParsed == null) {
      print('Invalid live coordinates: Latitude=$lat, Longitude=$lon');
      return null;
    }
    return LatLng(latParsed, lonParsed);
  }

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    print('Unrecognized coordinate format: $value (${value.runtimeType})');
    return null;
  }

  flutter.Widget _buildCustomMarker() {
    final vehicleType = (widget.machine['Vehicletype'] ?? '').toString().toLowerCase();
    String? markerImage;
    if (vehicleType.contains('jcb')) {
      markerImage = 'assets/jcb-unit-removebg-preview.png';
    } else if (vehicleType.contains('tractor')) {
      markerImage = 'assets/tractor-unit-removebg-preview.png';
    }
    print('Vehicle type: $vehicleType, Marker image: $markerImage');
    return markerImage != null
        ? flutter.Image.asset(
      markerImage,
      width: 40,
      height: 40,
      fit: flutter.BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        print('Error loading marker image $markerImage: $error');
        return const flutter.Icon(
          flutter.Icons.location_pin,
          color: flutter.Colors.red,
          size: 40,
        );
      },
    )
        : const flutter.Icon(
      flutter.Icons.location_pin,
      color: flutter.Colors.red,
      size: 40,
    );
  }

  Future<void> _fetchTravelHistory() async {
    final vehicleNoRaw = widget.machine['Vehicle_No'] as String? ?? 'N/A';
    final vehicleNo = vehicleNoRaw.trim().toUpperCase();
    if (vehicleNo == 'N/A' || vehicleNo.isEmpty) {
      print('Invalid vehicle number: $vehicleNoRaw');
      if (mounted) {
        setState(() {
          _errorMessage = widget.translate('Invalid vehicle number');
          _isLoading = false;
        });
      }
      return;
    }

    if (!mounted) {
      print('Widget not mounted, aborting fetch');
      return;
    }

    _fetchCompleter = Completer<void>();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isPlaying = false;
      _currentStep = 0;
      _currentVehiclePosition = null;
      _animationTimer?.cancel();
      _showHistory = true;
      _isFetching = true;
    });

    try {
      print('Fetching history for vehicle: $vehicleNo, Time range: $_selectedTimeRange');
      if (!_mongoService.isConnected || _mongoService._vehicleDb == null) {
        print('MongoDB not connected, attempting to reconnect...');
        int retries = 3;
        while (retries > 0 && mounted && !_fetchCompleter!.isCompleted) {
          try {
            await _mongoService.connect();
            if (_mongoService._vehicleDb != null) break;
            retries--;
            print('Retry $retries remaining...');
            await Future.delayed(const Duration(seconds: 2));
          } catch (e) {
            print('Retry error: $e');
          }
        }
        if (_mongoService._vehicleDb == null) {
          throw Exception('MongoDB reconnection failed after retries');
        }
      }

      final db = _mongoService._vehicleDb!;
      final collection = db.collection(vehicleNo);
      final now = DateTime.now().toUtc();
      DateTime pastDate;
      switch (_selectedTimeRange) {
        case '24h':
          pastDate = now.subtract(const Duration(hours: 24));
          break;
        case '7d':
          pastDate = now.subtract(const Duration(days: 7));
          break;
        case '90d':
          pastDate = now.subtract(const Duration(days: 90));
          break;
        case '30d':
        default:
          pastDate = now.subtract(const Duration(days: 30));
      }

      print('Query: fetchedAt > ${pastDate.toIso8601String()}');
      final results = await collection
          .find({'fetchedAt': {'\$gt': pastDate.toIso8601String()}})
          .toList();
      if (!_isFetching || !mounted || _fetchCompleter!.isCompleted) {
        print('Fetch canceled: _isFetching=$_isFetching, mounted=$mounted, completer=${_fetchCompleter!.isCompleted}');
        return;
      }
      results.sort((a, b) => (a['fetchedAt'] as String).compareTo(b['fetchedAt'] as String));
      print('Raw results count: ${results.length}');
      if (results.isNotEmpty) {
        print('Sample document: ${results.first}');
      }

      if (!mounted || _fetchCompleter!.isCompleted) {
        print('Widget not mounted or fetch canceled after fetch, aborting state update');
        return;
      }
      setState(() {
        _locationHistory = results.where((doc) {
          final lat = doc['Latitude'];
          final lon = doc['Longitude'];
          final latValid = _parseCoordinate(lat) != null;
          final lonValid = _parseCoordinate(lon) != null;
          if (!latValid || !lonValid) {
            print('Filtered out: lat=$lat, lon=$lon, doc=$doc');
          }
          return latValid && lonValid;
        }).toList();
        print('Valid location history records: ${_locationHistory.length}');
        _isLoading = false;
      });

      if (_locationHistory.isNotEmpty && mounted && !_fetchCompleter!.isCompleted) {
        _mapController.move(_getPolylinePoints().first, 13.0);
        if (_locationHistory.length == 1 && mounted) {
          setState(() {
            _errorMessage = widget.translate('Only one location available');
          });
        }
      } else if (mounted && !_fetchCompleter!.isCompleted) {
        print('No valid location history for $vehicleNo');
        setState(() {
          _errorMessage = widget.translate('No travel history available for this period');
        });
      }
    } catch (e, stackTrace) {
      print('Error fetching travel history for $vehicleNo: $e\n$stackTrace');
      if (mounted && !_fetchCompleter!.isCompleted) {
        setState(() {
          _errorMessage = widget.translate('Failed to load travel history');
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && !_fetchCompleter!.isCompleted) {
        setState(() => _isFetching = false);
      } else {
        print('Widget not mounted or fetch canceled, skipping final state update');
      }
      if (!_fetchCompleter!.isCompleted) {
        _fetchCompleter?.complete();
      }
    }
  }

  List<LatLng> _getPolylinePoints() {
    return _locationHistory
        .map((doc) => LatLng(
      _parseCoordinate(doc['Latitude'])!,
      _parseCoordinate(doc['Longitude'])!,
    ))
        .toList();
  }

  void _showPointDetails(LatLng point) {
    final doc = _locationHistory.firstWhere(
          (d) =>
      _parseCoordinate(d['Latitude']) == point.latitude &&
          _parseCoordinate(d['Longitude']) == point.longitude,
      orElse: () => {},
    );
    if (doc.isEmpty) return;
    flutter.showDialog(
      context: context,
      builder: (flutter.BuildContext context) => flutter.AlertDialog(
        title: flutter.Text(widget.translate('Location Details')),
        content: flutter.Column(
          mainAxisSize: flutter.MainAxisSize.min,
          crossAxisAlignment: flutter.CrossAxisAlignment.start,
          children: [
            flutter.Text('${widget.translate('Time')}: ${doc['fetchedAt']}'),
            flutter.Text('${widget.translate('Speed')}: ${doc['Speed'] ?? 'N/A'} km/h'),
            flutter.Text('${widget.translate('Latitude')}: ${doc['Latitude']}'),
            flutter.Text('${widget.translate('Longitude')}: ${doc['Longitude']}'),
          ],
        ),
        actions: [
          flutter.TextButton(
            onPressed: () => flutter.Navigator.pop(context),
            child: flutter.Text(widget.translate('Close')),
          ),
        ],
      ),
    );
  }

  void _toggleAnimation() {
    final points = _getPolylinePoints();
    if (points.isEmpty) {
      print('No points available for animation');
      return;
    }

    if (!mounted) {
      print('Widget not mounted, aborting animation toggle');
      return;
    }
    setState(() {
      if (_isPlaying) {
        _animationTimer?.cancel();
        _isPlaying = false;
        print('Animation paused');
      } else {
        _isPlaying = true;
        if (_currentStep >= points.length) _currentStep = 0;
        _currentVehiclePosition = points[_currentStep];
        if (mounted) {
          _mapController.move(_currentVehiclePosition!, _mapController.zoom);
        }
        final interval = Duration(milliseconds: (500 / _playbackSpeed).round());
        _animationTimer = Timer.periodic(interval, (timer) {
          if (!mounted) {
            timer.cancel();
            print('Animation timer canceled due to widget disposal');
            return;
          }
          setState(() {
            _currentStep++;
            if (_currentStep < points.length) {
              _currentVehiclePosition = points[_currentStep];
              _mapController.move(_currentVehiclePosition!, _mapController.zoom);
            } else {
              _currentStep = 0;
              _currentVehiclePosition = points[_currentStep];
              _mapController.move(_currentVehiclePosition!, _mapController.zoom);
            }
            print('Animation step: $_currentStep, Position: $_currentVehiclePosition');
          });
        });
        print('Animation started with speed: ${_playbackSpeed}x');
      }
    });
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    final vehicleNo = widget.machine['Vehicle_No'] as String? ?? 'N/A';
    return flutter.Scaffold(
      backgroundColor: widget.isDarkMode ? flutter.Colors.grey[900] : flutter.Colors.grey[100],
      appBar: flutter.AppBar(
        backgroundColor: widget.isDarkMode ? flutter.Colors.grey[850] : flutter.Colors.white,
        elevation: 2,
        leading: flutter.IconButton(
          icon: flutter.Icon(flutter.Icons.arrow_back, color: widget.textColor),
          onPressed: () => flutter.Navigator.pop(context),
        ),
        title: flutter.Text(
          '${widget.translate('Location')}: $vehicleNo',
          style: flutter.TextStyle(
            fontSize: 22,
            fontWeight: flutter.FontWeight.bold,
            color: widget.textColor,
          ),
          overflow: flutter.TextOverflow.ellipsis,
        ),
      ),
      body: flutter.Column(
        children: [
          if (_showHistory)
            flutter.Padding(
              padding: const flutter.EdgeInsets.all(16.0),
              child: flutter.Column(
                children: [
                  flutter.DropdownButtonFormField<String>(
                    decoration: flutter.InputDecoration(
                      labelText: widget.translate('Select Time Range'),
                      labelStyle: flutter.TextStyle(color: widget.textColor),
                      border: const flutter.OutlineInputBorder(),
                      filled: true,
                      fillColor: widget.isDarkMode ? flutter.Colors.grey[800] : flutter.Colors.white,
                    ),
                    style: flutter.TextStyle(color: widget.textColor),
                    dropdownColor: widget.isDarkMode ? flutter.Colors.grey[800] : flutter.Colors.white,
                    value: _selectedTimeRange,
                    items: _timeRangeOptions
                        .map((option) => flutter.DropdownMenuItem(
                      value: option['value'],
                      child: flutter.Text(
                        widget.translate(option['label']!),
                        style: flutter.TextStyle(color: widget.textColor),
                      ),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (!mounted || value == null) return;
                      setState(() {
                        _selectedTimeRange = value;
                        _fetchTravelHistory();
                      });
                      print('Time range changed to: $value');
                    },
                  ),
                  const flutter.SizedBox(height: 16),
                  flutter.DropdownButtonFormField<double>(
                    decoration: flutter.InputDecoration(
                      labelText: widget.translate('Playback Speed'),
                      labelStyle: flutter.TextStyle(color: widget.textColor),
                      border: const flutter.OutlineInputBorder(),
                      filled: true,
                      fillColor: widget.isDarkMode ? flutter.Colors.grey[800] : flutter.Colors.white,
                    ),
                    style: flutter.TextStyle(color: widget.textColor),
                    dropdownColor: widget.isDarkMode ? flutter.Colors.grey[800] : flutter.Colors.white,
                    value: _playbackSpeed,
                    items: _speedOptions
                        .map((speed) => flutter.DropdownMenuItem(
                      value: speed,
                      child: flutter.Text(
                        '${speed}x',
                        style: flutter.TextStyle(color: widget.textColor),
                      ),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (!mounted || value == null) return;
                      setState(() {
                        _playbackSpeed = value;
                        if (_isPlaying) {
                          _toggleAnimation();
                          _toggleAnimation();
                        }
                      });
                      print('Playback speed changed to: ${value}x');
                    },
                  ),
                ],
              ),
            ),
          flutter.Expanded(
            child: _isLoading
                ? flutter.Center(child: flutter.CircularProgressIndicator(color: widget.textColor))
                : _errorMessage != null
                ? flutter.Center(
              child: flutter.Text(
                _errorMessage!,
                style: flutter.TextStyle(color: widget.textColor, fontSize: 18),
                textAlign: flutter.TextAlign.center,
              ),
            )
                : _showHistory
                ? _locationHistory.isEmpty
                ? flutter.Center(
              child: flutter.Column(
                mainAxisAlignment: flutter.MainAxisAlignment.center,
                children: [
                  flutter.Icon(
                    flutter.Icons.map,
                    size: 60,
                    color: widget.textColor.withOpacity(0.6),
                  ),
                  const flutter.SizedBox(height: 16),
                  flutter.Text(
                    widget.translate('No travel history available'),
                    style: flutter.TextStyle(
                      color: widget.textColor,
                      fontSize: 20,
                      fontWeight: flutter.FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
                : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _getPolylinePoints().isNotEmpty
                    ? _getPolylinePoints()[0]
                    : LatLng(25.5136222, 85.9772356),
                zoom: 13.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  subdomains: const ['a', 'b', 'c'],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _getPolylinePoints(),
                      strokeWidth: 4.0,
                      color: const flutter.Color(0xFF00B899),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (_locationHistory.isNotEmpty)
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: _getPolylinePoints().first,
                        builder: (ctx) => flutter.GestureDetector(
                          onTap: () => _showPointDetails(_getPolylinePoints().first),
                          child: const flutter.Icon(
                            flutter.Icons.location_pin,
                            color: flutter.Colors.blue,
                            size: 40,
                          ),
                        ),
                      ),
                    if (_locationHistory.length > 1)
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: _getPolylinePoints().last,
                        builder: (ctx) => flutter.GestureDetector(
                          onTap: () => _showPointDetails(_getPolylinePoints().last),
                          child: const flutter.Icon(
                            flutter.Icons.location_pin,
                            color: flutter.Colors.blue,
                            size: 40,
                          ),
                        ),
                      ),
                    if (_isPlaying && _currentVehiclePosition != null)
                      Marker(
                        width: 40.0,
                        height: 40.0,
                        point: _currentVehiclePosition!,
                        builder: (ctx) => flutter.Container(
                          decoration: flutter.BoxDecoration(
                            shape: flutter.BoxShape.circle,
                            color: flutter.Colors.white,
                            boxShadow: [
                              flutter.BoxShadow(
                                color: flutter.Colors.black.withOpacity(0.5),
                                spreadRadius: 2,
                                blurRadius: 4,
                                offset: const flutter.Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const flutter.EdgeInsets.all(4.0),
                          child: const flutter.Icon(
                            flutter.Icons.agriculture,
                            color: flutter.Color(0xFFFFA500),
                            size: 28,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            )
                : _getVehiclePosition() != null
                ? FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _getVehiclePosition()!,
                zoom: 15.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40.0,
                      height: 40.0,
                      point: _getVehiclePosition()!,
                      builder: (ctx) => _buildCustomMarker(),
                    ),
                  ],
                ),
              ],
            )
                : flutter.Center(
              child: flutter.Column(
                mainAxisAlignment: flutter.MainAxisAlignment.center,
                children: [
                  flutter.Icon(
                    flutter.Icons.map,
                    size: 60,
                    color: widget.textColor.withOpacity(0.6),
                  ),
                  const flutter.SizedBox(height: 16),
                  flutter.Text(
                    widget.translate('No location data available'),
                    style: flutter.TextStyle(
                      color: widget.textColor,
                      fontSize: 20,
                      fontWeight: flutter.FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: flutter.Padding(
        padding: const flutter.EdgeInsets.all(8.0),
        child: flutter.Column(
          mainAxisSize: flutter.MainAxisSize.min,
          children: [
            flutter.Row(
              mainAxisAlignment: flutter.MainAxisAlignment.spaceBetween,
              children: [
                flutter.Row(
                  children: [
                    flutter.IconButton(
                      icon: flutter.Icon(
                        _isPlaying ? flutter.Icons.pause : flutter.Icons.play_arrow,
                        color: const flutter.Color(0xFF00B899),
                      ),
                      onPressed: _showHistory && _locationHistory.isNotEmpty ? _toggleAnimation : null,
                    ),
                    const flutter.SizedBox(width: 8),
                    flutter.ElevatedButton(
                      onPressed: _showHistory || _isLoading ? null : _fetchTravelHistory,
                      style: flutter.ElevatedButton.styleFrom(
                        backgroundColor: const flutter.Color(0xFF00B899),
                        foregroundColor: flutter.Colors.white,
                      ),
                      child: flutter.Text(widget.translate('Playback')),
                    ),
                  ],
                ),
                flutter.Text(
                  'Tiles © Esri',
                  style: flutter.TextStyle(fontSize: 10, color: widget.textColor.withOpacity(0.5)),
                  textAlign: flutter.TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Sidebar extends flutter.StatelessWidget {
  final bool isAdmin;
  final String language;
  final void Function() onLogout;
  final void Function()? onPieChartRefresh;

  const Sidebar({
    super.key,
    required this.isAdmin,
    required this.language,
    required this.onLogout,
    this.onPieChartRefresh,
  });

  String translate(String key) => TranslationService.translate(key, language);

  void _logout(flutter.BuildContext context) async {
    flutter.showDialog(
      context: context,
      builder: (context) => flutter.AlertDialog(
        title: flutter.Text(translate('Confirm Logout')),
        actions: [
          flutter.TextButton(
            onPressed: () => flutter.Navigator.pop(context),
            child: flutter.Text(translate('No')),
          ),
          flutter.TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('loggedInUser');
              await prefs.remove('isAdmin');
              flutter.Navigator.pushReplacement(context, flutter.MaterialPageRoute(builder: (context) => const LoginPage()));
              onLogout();
            },
            child: flutter.Text(translate('Yes')),
          ),
        ],
      ),
    );
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Drawer(
      child: flutter.ListView(
        padding: flutter.EdgeInsets.zero,
        children: [
          flutter.DrawerHeader(
            decoration: const flutter.BoxDecoration(
              color: flutter.Color(0xFF00B899), // Company color
            ),
            child: flutter.Center(
              child: flutter.Image.asset(
                'assets/ezgif.com-gif-maker.gif', // Placeholder for your GIF logo
                height: 80, // Adjust size as needed
                width: 150,
              ),
            ),
          ),
          flutter.ListTile(
            leading: const flutter.Icon(flutter.Icons.dashboard),
            title: flutter.Text(translate('Dashboard')),
            onTap: () => flutter.Navigator.pop(context),
          ),
          // flutter.ListTile(
          //   leading: const flutter.Icon(flutter.Icons.location_on),
          //   title: flutter.Text(translate('Machine Tracking')),
          //   onTap: () => flutter.Navigator.push(
          //     context,
          //     flutter.MaterialPageRoute(builder: (context) => LiveTrackingPage(language: language)),
          //   ),
          // ),
          flutter.ListTile(
            leading: const flutter.Icon(flutter.Icons.info),
            title: flutter.Text(translate('Machine Status')),
            onTap: () => flutter.Navigator.push(
              context,
              flutter.MaterialPageRoute(
                builder: (context) => MachineStatusPage(
                  isAdmin: isAdmin,
                  loggedInUser: isAdmin ? null : UserManager.findUser('user', 'pass'),
                  language: language,
                ),
              ),
            ),
          ),
          flutter.ListTile(
            leading: const flutter.Icon(flutter.Icons.local_gas_station),
            title: flutter.Text(translate('Travel History')),
            onTap: () => flutter.Navigator.push(
              context,
              flutter.MaterialPageRoute(
                builder: (context) => TravelHistoryPage(
                  language: language,
                  isAdmin: isAdmin,
                  loggedInUser: isAdmin ? null : UserManager.findUser('user', 'pass'),
                ),
              ),
            ),
          ),
          flutter.ListTile(
            leading: const flutter.Icon(flutter.Icons.local_gas_station),
            title: flutter.Text(translate('Travel Summary')),
            onTap: () => flutter.Navigator.push(
              context,
              flutter.MaterialPageRoute(
                builder: (context) => TravelSummaryPage(
                  language: language,
                  isAdmin: isAdmin,
                  loggedInUser: isAdmin ? null : UserManager.findUser('user', 'pass'),
                ),
              ),
            ),
          ),
          flutter.ListTile(
            leading: const flutter.Icon(flutter.Icons.business),
            title: flutter.Text(translate('Area')),
            onTap: () => flutter.Navigator.push(
              context,
              flutter.MaterialPageRoute(builder: (context) => BusinessPage(language: language)),
            ),
          ),
          // flutter.ListTile(
          //   leading: const flutter.Icon(flutter.Icons.announcement),
          //   title: flutter.Text(translate('Announcement Details')),
          //   onTap: () => flutter.Navigator.push(
          //     context,
          //     flutter.MaterialPageRoute(builder: (context) => AnnouncementPage(language: language)),
          //   ),
          // ),
          if (isAdmin)
            flutter.ListTile(
              leading: const flutter.Icon(flutter.Icons.person_add),
              title: flutter.Text(translate('Add User')),
              onTap: () => flutter.Navigator.push(
                context,
                flutter.MaterialPageRoute(builder: (context) => AddUserPage(language: language)),
              ),
            ),
          if (isAdmin)
            flutter.ListTile(
              leading: const flutter.Icon(flutter.Icons.people),
              title: flutter.Text(translate('Manage Users')),
              onTap: () => flutter.Navigator.push(
                context,
                flutter.MaterialPageRoute(builder: (context) => ManageUsersPage(language: language)),
              ),
            ),
          flutter.ListTile(
            leading: const flutter.Icon(flutter.Icons.exit_to_app),
            title: flutter.Text(translate('Logout')),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

class MachineStatusPage extends flutter.StatefulWidget {
  final bool isAdmin;
  final User? loggedInUser;
  final String language;
  final String? initialVehicleNo;

  const MachineStatusPage({
    super.key,
    required this.isAdmin,
    required this.loggedInUser,
    required this.language,
    this.initialVehicleNo,
  });

  @override
  flutter.State<MachineStatusPage> createState() => _MachineStatusPageState();
}

class _MachineStatusPageState extends flutter.State<MachineStatusPage> with flutter.SingleTickerProviderStateMixin {
  late flutter.TabController _tabController;
  List<Map<String, dynamic>> filteredMachines = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Map<String, dynamic>? selectedMachine;
  late Timer _timer;
  late Timer _countdownTimer;
  String _refreshCountdown = '';
  final MachineDataService _dataService = MachineDataService();

  String? _selectedUserName;
  String? _selectedVehicleNo;
  List<String> _userNameList = [];
  List<String> _machineList = [];

  @override
  void initState() {
    super.initState();
    _tabController = flutter.TabController(length: 2, vsync: this);
    _loadInitialData();
    _startAutoFetch();
    _startCountdown();

    if (widget.initialVehicleNo != null) _selectMachineByVehicleNo(widget.initialVehicleNo!);
  }

  void _loadInitialData() async {
    setState(() => _isLoading = true);
    if (widget.isAdmin) {
      _userNameList = UserManager.users.map((user) => user.name).toList();
      _userNameList.insert(0, 'All');
    } else {
      _userNameList = [widget.loggedInUser!.name];
    }
    _selectedUserName = _userNameList.first;

    await _loadMachinesForUser();
    if (_dataService.lastFetchTime == null) {
      _dataService.lastFetchTime = DateTime.now(); // Initialize timer on first load
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMachinesForUser() async {
    if (_selectedUserName == null) {
      _machineList = [];
      filteredMachines = [];
      return;
    }

    setState(() => _isLoading = true);
    await _fetchFromMongoDB(); // Fetch from MongoDB only

    if (_selectedUserName == 'All' && widget.isAdmin) {
      _machineList = UserManager.users
          .expand((user) => user.vehicleNumbers.split(',').map((v) => v.trim()))
          .toSet()
          .toList();
    } else {
      final selectedUserData = widget.isAdmin
          ? UserManager.users.firstWhere((user) => user.name == _selectedUserName)
          : widget.loggedInUser!;
      _machineList = selectedUserData.vehicleNumbers.split(',').map((v) => v.trim()).toList();
    }

    _selectedVehicleNo = _machineList.isNotEmpty ? _machineList[0] : null;

    setState(() {
      filteredMachines = _dataService.machines
          .where((machine) => _machineList.contains(machine['Vehicle_No']) && (machine['Vehicle_No'] ?? '').isNotEmpty)
          .toList();
      _isLoading = false;
    });
  }

  void _startAutoFetch() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_dataService.lastFetchTime != null) {
        final nextRefresh = _dataService.lastFetchTime!.add(const Duration(minutes: 1));
        final remaining = nextRefresh.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          _fetchAllMachines();
        }
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_dataService.lastFetchTime != null) {
        final nextRefresh = _dataService.lastFetchTime!.add(const Duration(minutes: 1));
        final remaining = nextRefresh.difference(DateTime.now()).inSeconds;
        setState(() {
          _refreshCountdown = '${translate('Next refresh in')} ${remaining > 0 ? remaining : 0} sec';
        });
      } else {
        setState(() {
          _refreshCountdown = '${translate('Next refresh in')} 60 sec';
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _countdownTimer.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String translate(String key) => TranslationService.translate(key, widget.language);

  Future<void> _fetchAllMachines() async {
    if (_selectedUserName == null) return;

    setState(() => _isLoading = true);
    List<String> vehicleNumbers = _machineList; // Use pre-filtered list from _loadMachinesForUser

    final vehicleNoString = vehicleNumbers.join(',');
    final url =
        'http://13.127.144.213/webservice?token=getLiveData&user=Agrix&pass=123456&vehicle_no=$vehicleNoString&format=json';

    try {
      final response = await http.get(Uri.parse(url));
      print('API Response for $vehicleNoString: ${response.body}'); // Debug log
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['root'] != null && jsonResponse['root']['VehicleData']?.isNotEmpty == true) {
          final vehicleDataList = jsonResponse['root']['VehicleData'] as List<dynamic>;
          final vehicleMap = <String, Map<String, dynamic>>{};
          for (var vehicleData in vehicleDataList) {
            final data = vehicleData as Map<String, dynamic>;
            final vehicleNo = data['Vehicle_No'] as String?;
            if (vehicleNo == null || !vehicleNumbers.contains(vehicleNo)) continue;
            data['fetchedAt'] = DateTime.now().toUtc().toIso8601String();
            vehicleMap[vehicleNo] = data;
            await MongoDBService().saveVehicleData(vehicleNo, data, fromApi: true);
          }
          final currentMap = {for (var m in _dataService.machines) m['Vehicle_No'] as String: m};
          currentMap.addAll(vehicleMap);
          _dataService.machines
            ..clear()
            ..addAll(currentMap.values);
        }
      }
    } catch (e) {
      print('Error fetching from API: $e');
    }

    setState(() {
      filteredMachines = _dataService.machines
          .where((machine) => _machineList.contains(machine['Vehicle_No']) && (machine['Vehicle_No'] ?? '').isNotEmpty)
          .toList();
      _isLoading = false;
      _dataService.lastFetchTime = DateTime.now();
    });
  }

  Future<void> _fetchFromMongoDB() async {
    if (_selectedUserName == null) return;

    List<String> vehicleNumbers;
    if (_selectedUserName == 'All' && widget.isAdmin) {
      vehicleNumbers = UserManager.users
          .expand((user) => user.vehicles.map((v) => v.trim()))
          .toSet()
          .toList();
    } else {
      final selectedUserData = widget.isAdmin
          ? UserManager.users.firstWhere((user) => user.name == _selectedUserName)
          : widget.loggedInUser!;
      vehicleNumbers = selectedUserData.vehicles.map((v) => v.trim()).toList();
    }

    final mongoService = MongoDBService();
    final vehicleMap = <String, Map<String, dynamic>>{};

    try {
      if (!mongoService.isConnected) await mongoService.connect();
      if (mongoService._vehicleDb == null) throw Exception('MongoDB vehicle connection failed');

      for (var vehicleNo in vehicleNumbers) {
        final collection = mongoService._vehicleDb!.collection(vehicleNo);
        final results = await collection
            .find({
          'fetchedAt': {
            '\$gt': DateTime.now().subtract(const Duration(hours: 24)).toIso8601String()
          }
        })
            .toList();
        if (results.isNotEmpty) {
          results.sort((a, b) => (b['fetchedAt'] as String).compareTo(a['fetchedAt'] as String));
          vehicleMap[vehicleNo] = results.first;
        } else {
          vehicleMap[vehicleNo] = {
            'Vehicle_No': vehicleNo,
            'Vehicle_Name': vehicleNo,
            'Status': 'Inactive',
            'Location': 'Unknown',
            'IGN': 'OFF',
            'fetchedAt': DateTime.now().toUtc().toIso8601String(),
          };
        }
      }
    } catch (e) {
      print('MongoDB fetch error: $e');
      for (var vehicleNo in vehicleNumbers) {
        vehicleMap[vehicleNo] = {
          'Vehicle_No': vehicleNo,
          'Vehicle_Name': vehicleNo,
          'Status': 'Inactive',
          'Location': 'Unknown',
          'IGN': 'OFF',
          'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        };
      }
    }

    _dataService.machines
      ..clear()
      ..addAll(vehicleMap.values);
  }

  void _filterMachines(String query) {
    setState(() {
      _searchQuery = query;
      filteredMachines = _dataService.machines
          .where((machine) =>
      _machineList.contains(machine['Vehicle_No']) &&
          (machine['Vehicle_No'] ?? '').toLowerCase().contains(query.toLowerCase()) &&
          (machine['Vehicle_No'] ?? '').isNotEmpty)
          .toList();
    });
  }

  void _selectMachineForMap(Map<String, dynamic> machine) {
    setState(() {
      selectedMachine = machine;
      _tabController.animateTo(1);
    });
  }

  void _selectMachineByVehicleNo(String vehicleNo) {
    final machine = _dataService.machines.firstWhere(
          (m) => m['Vehicle_No'] == vehicleNo,
      orElse: () => {},
    );
    if (machine.isNotEmpty) {
      setState(() {
        selectedMachine = machine;
        _tabController.animateTo(0);
      });
    }
  }

  LatLng? _getVehiclePosition() {
    if (selectedMachine == null) return null;
    double? lat = double.tryParse(selectedMachine!['Latitude'] ?? '');
    double? lng = double.tryParse(selectedMachine!['Longitude'] ?? '');
    return (lat != null && lng != null) ? LatLng(lat, lng) : null;
  }

  flutter.Widget _buildMachineDetails(Map<String, dynamic> machine) {
    return flutter.Padding(
      padding: const flutter.EdgeInsets.all(8.0),
      child: flutter.Column(
        crossAxisAlignment: flutter.CrossAxisAlignment.start,
        children: [
          MachineInfoTile(translate('Vehicle Name'), machine['Vehicle_Name'] ?? 'N/A'),
          MachineInfoTile(translate('Company'), machine['Company'] ?? 'N/A'),
          MachineInfoTile(translate('Temperature'), machine['Temperature'] ?? 'N/A'),
          MachineInfoTile(translate('Latitude'), machine['Latitude'] ?? 'N/A'),
          MachineInfoTile(translate('GPS'), machine['GPS'] ?? 'N/A'),
          MachineInfoTile(translate('Vehicle No'), machine['Vehicle_No'] ?? 'N/A'),
          MachineInfoTile(translate('Door1'), machine['Door1'] ?? 'N/A'),
          MachineInfoTile(translate('Door4'), machine['Door4'] ?? 'N/A'),
          MachineInfoTile(translate('Branch'), machine['Branch'] ?? 'N/A'),
          MachineInfoTile(translate('Vehicle Type'), machine['Vehicletype'] ?? 'N/A'),
          MachineInfoTile(translate('Door2'), machine['Door2'] ?? 'N/A'),
          MachineInfoTile(translate('Door3'), machine['Door3'] ?? 'N/A'),
          MachineInfoTile(translate('GPSActualTime'), machine['GPSActualTime'] ?? 'N/A'),
          MachineInfoTile(translate('Last Updated'), machine['Datetime'] ?? 'N/A'),
          MachineInfoTile(translate('Status'), machine['Status'] ?? 'N/A'),
          MachineInfoTile(translate('DeviceModel'), machine['DeviceModel'] ?? 'N/A'),
          MachineInfoTile(translate('Speed'), '${machine['Speed'] ?? 'N/A'} km/h'),
          MachineInfoTile(translate('AC'), machine['AC'] ?? 'N/A'),
          MachineInfoTile(translate('IMEI'), machine['Imeino'] ?? 'N/A'),
          MachineInfoTile(translate('Odometer'), machine['Odometer'] ?? 'N/A'),
          MachineInfoTile(translate('POI'), machine['POI'] ?? 'N/A'),
          MachineInfoTile(translate('Driver Name'),
              '${machine['Driver_First_Name'] ?? ''} ${machine['Driver_Middle_Name'] ?? ''} ${machine['Driver_Last_Name'] ?? ''}'.trim()),
          MachineInfoTile(translate('Longitude'), machine['Longitude'] ?? 'N/A'),
          MachineInfoTile(translate('Immobilize State'), machine['Immobilize_State'] ?? 'N/A'),
          MachineInfoTile(translate('Ignition'), machine['IGN'] ?? 'N/A'),
          MachineInfoTile(translate('Angle'), machine['Angle'] ?? 'N/A'),
          MachineInfoTile(translate('SOS'), machine['SOS'] ?? 'N/A'),
          MachineInfoTile(translate('Fuel'), machine['Fuel']?.toString() ?? 'N/A'),
          MachineInfoTile(translate('Battery'), '${machine['battery_percentage'] ?? 'N/A'}%'),
          MachineInfoTile(translate('External Voltage'), machine['ExternalVolt'] ?? 'N/A'),
          MachineInfoTile(translate('Power'), machine['Power'] ?? 'N/A'),
          MachineInfoTile(translate('Location'), machine['Location'] ?? 'N/A'),
          const flutter.SizedBox(height: 8),
          flutter.ElevatedButton(
            onPressed: () => _selectMachineForMap(machine),
            child: flutter.Text(translate('Show Map')),
          ),
        ],
      ),
    );
  }

  flutter.Widget _buildCustomMarker() {
    if (selectedMachine == null) {
      return const flutter.Icon(
        flutter.Icons.location_pin,
        color: flutter.Colors.red,
        size: 40,
      );
    }

    final vehicleType = (selectedMachine!['Vehicletype'] ?? '').toString().toLowerCase();
    String markerImage;

    if (vehicleType.contains('jcb')) {
      markerImage = 'assets/jcb-unit-removebg-preview.png';
    } else if (vehicleType.contains('tractor')) {
      markerImage = 'assets/tractor-unit-removebg-preview.png';
    } else {
      return const flutter.Icon(
        flutter.Icons.location_pin,
        color: flutter.Colors.red,
        size: 40,
      );
    }

    return flutter.Image.asset(
      markerImage,
      width: 40,
      height: 40,
      fit: flutter.BoxFit.contain,
    );
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Scaffold(
      backgroundColor: flutter.Colors.transparent,
      appBar: flutter.AppBar(
        title: flutter.Text(
          translate('Machine Status'),
          style: const flutter.TextStyle(
            fontSize: 24,
            fontWeight: flutter.FontWeight.bold,
            shadows: [flutter.Shadow(color: flutter.Colors.black54, blurRadius: 4, offset: flutter.Offset(1, 1))],
          ),
        ),
        backgroundColor: const flutter.Color(0xFF00B899),
        elevation: 6,
        shape: const flutter.RoundedRectangleBorder(
          borderRadius: flutter.BorderRadius.vertical(bottom: flutter.Radius.circular(16)),
        ),
        actions: [
          flutter.Padding(
            padding: const flutter.EdgeInsets.only(right: 16.0),
            child: flutter.Center(
              child: flutter.Text(
                _refreshCountdown,
                style: const flutter.TextStyle(fontSize: 14, color: flutter.Colors.white70),
              ),
            ),
          ),
        ],
        bottom: flutter.PreferredSize(
          preferredSize: const flutter.Size.fromHeight(48.0),
          child: flutter.TabBar(
            controller: _tabController,
            labelStyle: const flutter.TextStyle(fontSize: 16, fontWeight: flutter.FontWeight.bold),
            unselectedLabelStyle: const flutter.TextStyle(fontSize: 14),
            indicatorColor: flutter.Colors.white,
            tabs: [
              flutter.Tab(text: translate('Info')),
              flutter.Tab(text: translate('Map')),
            ],
          ),
        ),
      ),
      body: flutter.Container(
        decoration: const flutter.BoxDecoration(
          gradient: flutter.LinearGradient(
            begin: flutter.Alignment.topLeft,
            end: flutter.Alignment.bottomRight,
            colors: [flutter.Color(0xFF1A1A1A), flutter.Color(0xFF2D2D2D)],
          ),
        ),
        child: flutter.Column(
          children: [
            flutter.Padding(
              padding: const flutter.EdgeInsets.all(16.0),
              child: flutter.Column(
                children: [
                  DropdownSearch<String>(
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    items: _userNameList,
                    dropdownDecoratorProps: DropDownDecoratorProps( // Fixed: Changed to DropDownDecoratorProps
                      dropdownSearchDecoration: flutter.InputDecoration(
                        labelText: translate('Select User'),
                        labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                        border: flutter.OutlineInputBorder(
                          borderRadius: flutter.BorderRadius.circular(12),
                          borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                        ),
                        filled: true,
                        fillColor: flutter.Colors.black.withOpacity(0.8),
                        prefixIcon: const flutter.Icon(flutter.Icons.person, color: flutter.Color(0xFF00B899)),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedUserName = value;
                        _selectedVehicleNo = null;
                      });
                      _loadMachinesForUser();
                    },
                    selectedItem: _selectedUserName,
                  ),
                  const flutter.SizedBox(height: 16),
                  flutter.DropdownButtonFormField<String>(
                    decoration: flutter.InputDecoration(
                      labelText: translate('Select Machine'),
                      labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                      border: flutter.OutlineInputBorder(
                        borderRadius: flutter.BorderRadius.circular(12),
                        borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                      ),
                      filled: true,
                      fillColor: flutter.Colors.black.withOpacity(0.8),
                      prefixIcon: const flutter.Icon(flutter.Icons.directions_car, color: flutter.Color(0xFF00B899)),
                    ),
                    style: const flutter.TextStyle(color: flutter.Colors.white),
                    dropdownColor: const flutter.Color(0xFF00B899),
                    value: _selectedVehicleNo,
                    items: _machineList
                        .map((vehicle) => flutter.DropdownMenuItem(
                      value: vehicle,
                      child: flutter.Text(vehicle, style: const flutter.TextStyle(color: flutter.Colors.white)),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicleNo = value;
                        filteredMachines = _dataService.machines
                            .where((machine) => machine['Vehicle_No'] == value && (machine['Vehicle_No'] ?? '').isNotEmpty)
                            .toList();
                      });
                    },
                  ),
                  const flutter.SizedBox(height: 16),
                  flutter.TextField(
                    decoration: flutter.InputDecoration(
                      labelText: translate('Search'),
                      labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                      border: flutter.OutlineInputBorder(
                        borderRadius: flutter.BorderRadius.circular(12),
                        borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                      ),
                      prefixIcon: const flutter.Icon(flutter.Icons.search, color: flutter.Color(0xFF00B899)),
                      filled: true,
                      fillColor: flutter.Colors.black.withOpacity(0.8),
                    ),
                    style: const flutter.TextStyle(color: flutter.Colors.white),
                    onChanged: _filterMachines,
                  ),
                ],
              ),
            ),
            flutter.Expanded(
              child: flutter.TabBarView(
                controller: _tabController,
                children: [
                  _isLoading
                      ? const flutter.Center(
                    child: flutter.CircularProgressIndicator(
                      valueColor: flutter.AlwaysStoppedAnimation<flutter.Color>(flutter.Color(0xFF00B899)),
                    ),
                  )
                      : filteredMachines.isEmpty
                      ? flutter.Center(
                    child: flutter.Column(
                      mainAxisAlignment: flutter.MainAxisAlignment.center,
                      children: [
                        flutter.Icon(
                          flutter.Icons.directions_car,
                          size: 60,
                          color: flutter.Colors.white.withOpacity(0.6),
                        ),
                        const flutter.SizedBox(height: 16),
                        flutter.Text(
                          translate('No data available'),
                          style: const flutter.TextStyle(
                            color: flutter.Colors.white,
                            fontSize: 20,
                            fontWeight: flutter.FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                      : flutter.ListView.builder(
                    padding: const flutter.EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredMachines.length,
                    itemBuilder: (context, index) {
                      final machine = filteredMachines[index];
                      final vehicleNo = machine['Vehicle_No'];
                      final status = machine['Status']?.toString().toUpperCase() ?? 'UNKNOWN';
                      flutter.Color statusColor = status == 'MOVING' || status == 'RUNNING'
                          ? flutter.Colors.green
                          : (status == 'STOP' || status == 'IDLE')
                          ? flutter.Colors.orange
                          : flutter.Colors.red;

                      return flutter.AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const flutter.EdgeInsets.only(bottom: 8),
                        child: flutter.Card(
                          color: flutter.Colors.black.withOpacity(0.85),
                          elevation: 4,
                          shape: flutter.RoundedRectangleBorder(
                            borderRadius: flutter.BorderRadius.circular(12),
                            side: const flutter.BorderSide(color: flutter.Color(0xFF00B899), width: 0.5),
                          ),
                          child: flutter.ExpansionTile(
                            leading: flutter.Icon(flutter.Icons.directions_car, color: statusColor, size: 30),
                            title: flutter.Text(
                              '${machine['Vehicle_Name'] ?? vehicleNo} ($vehicleNo)',
                              style: const flutter.TextStyle(
                                color: flutter.Colors.white,
                                fontWeight: flutter.FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: flutter.Text(
                              '${translate('Status')}: $status',
                              style: const flutter.TextStyle(color: flutter.Colors.grey),
                            ),
                            children: [_buildMachineDetails(machine)],
                          ),
                        ),
                      );
                    },
                  ),
                  selectedMachine != null && _getVehiclePosition() != null
                      ? FlutterMap(
                    options: MapOptions(
                      center: _getVehiclePosition()!,
                      zoom: 15.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 40.0,
                            height: 40.0,
                            point: _getVehiclePosition()!,
                            builder: (ctx) => _buildCustomMarker(),
                          ),
                        ],
                      ),
                    ],
                  )
                      : flutter.Center(
                    child: flutter.Column(
                      mainAxisAlignment: flutter.MainAxisAlignment.center,
                      children: [
                        flutter.Icon(
                          flutter.Icons.map,
                          size: 60,
                          color: flutter.Colors.white.withOpacity(0.6),
                        ),
                        const flutter.SizedBox(height: 16),
                        flutter.Text(
                          selectedMachine == null
                              ? translate('Select a machine')
                              : translate('No location data available'),
                          style: const flutter.TextStyle(
                            color: flutter.Colors.white,
                            fontSize: 20,
                            fontWeight: flutter.FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            flutter.Padding(
              padding: const flutter.EdgeInsets.all(8.0),
              child: flutter.Text(
                'Tiles © Esri',
                style: flutter.TextStyle(fontSize: 10, color: flutter.Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MachineInfoTile extends flutter.StatelessWidget {
  final String title;
  final String value;

  const MachineInfoTile(this.title, this.value, {super.key});

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Padding(
      padding: const flutter.EdgeInsets.symmetric(vertical: 4.0),
      child: flutter.Row(
        mainAxisAlignment: flutter.MainAxisAlignment.spaceBetween,
        children: [
          flutter.Text(title, style: const flutter.TextStyle(fontWeight: flutter.FontWeight.bold)),
          flutter.Flexible(child: flutter.Text(value, textAlign: flutter.TextAlign.right)),
        ],
      ),
    );
  }
}



class AddUserPage extends flutter.StatefulWidget {
  final String language;

  const AddUserPage({flutter.Key? key, required this.language}) : super(key: key);

  @override
  _AddUserPageState createState() => _AddUserPageState();
}

class _AddUserPageState extends flutter.State<AddUserPage> {
  final _formKey = flutter.GlobalKey<flutter.FormState>();
  String? _role = 'Admin'; // Default to Admin
  String? _cluster; // Selected cluster for Cluster Manager
  String _userId = '';
  String _username = '';
  String _password = '';
  String _phone = '';
  String _email = '';
  String _vehicleInput = ''; // Comma-separated vehicle numbers for Partner
  List<String> _attachments = [];

  // List of clusters
  final List<String> _clusters = ['BH001', 'BH002', 'BH003', 'BH004', 'BH005', 'BH006', 'BH007'];

  String translate(String key) => TranslationService.translate(key, widget.language);

  void _addAttachment() {
    String attachment = '';
    flutter.showDialog(
      context: context,
      builder: (context) => flutter.AlertDialog(
        title: flutter.Text(translate('Add Attachment')),
        content: flutter.TextField(
          decoration: flutter.InputDecoration(labelText: translate('Enter attachment name')),
          onChanged: (value) => attachment = value,
        ),
        actions: [
          flutter.TextButton(
            onPressed: () => flutter.Navigator.pop(context),
            child: const flutter.Text('Cancel'),
          ),
          flutter.TextButton(
            onPressed: () {
              if (attachment.isNotEmpty) {
                setState(() {
                  _attachments.add(attachment);
                });
                flutter.Navigator.pop(context);
              }
            },
            child: const flutter.Text('Add'),
          ),
        ],
      ),
    );
  }

  void _saveUser() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newUser = User(
        userId: _userId,
        name: _username,
        password: _password,
        phone: _phone,
        email: _email.isEmpty ? null : _email,
        vehicles: _role == 'Partner' ? _vehicleInput.split(',').map((v) => v.trim()).toList() : [],
        attachments: _role == 'Partner' ? _attachments : null,
        cluster: _role == 'Cluster Manager' ? _cluster : null, // Save cluster for Cluster Manager
      );

      UserManager.addUser(newUser);

      final mongoService = MongoDBService();
      try {
        await mongoService.savePartner(newUser);
        flutter.ScaffoldMessenger.of(context).showSnackBar(
          flutter.SnackBar(
            content: flutter.Text(
              translate(_role == 'Cluster Manager' ? 'Cluster Manager added successfully' : 'Partner added successfully'),
              style: const flutter.TextStyle(color: flutter.Colors.white),
            ),
            backgroundColor: const flutter.Color(0xFF00B899),
          ),
        );
        flutter.Navigator.pop(context, true);
      } catch (e) {
        print('Error saving user to MongoDB: $e');
        flutter.ScaffoldMessenger.of(context).showSnackBar(
          flutter.SnackBar(
            content: flutter.Text(
              '${translate('Failed to save user to database')}: $e',
              style: const flutter.TextStyle(color: flutter.Colors.white),
            ),
            backgroundColor: flutter.Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Scaffold(
      backgroundColor: flutter.Colors.transparent,
      appBar: flutter.AppBar(
        title: flutter.Text(
          translate('Add User'),
          style: const flutter.TextStyle(
            color: flutter.Colors.white,
            fontSize: 24,
            fontWeight: flutter.FontWeight.bold,
            shadows: [
              flutter.Shadow(color: flutter.Colors.black54, blurRadius: 4, offset: flutter.Offset(1, 1)),
            ],
          ),
        ),
        backgroundColor: const flutter.Color(0xFF00B899),
        elevation: 6,
        shape: const flutter.RoundedRectangleBorder(
          borderRadius: flutter.BorderRadius.vertical(bottom: flutter.Radius.circular(16)),
        ),
      ),
      body: flutter.Container(
        decoration: const flutter.BoxDecoration(
          gradient: flutter.LinearGradient(
            begin: flutter.Alignment.topLeft,
            end: flutter.Alignment.bottomRight,
            colors: [flutter.Color(0xFF1A1A1A), flutter.Color(0xFF2D2D2D)],
          ),
        ),
        child: flutter.Padding(
          padding: const flutter.EdgeInsets.all(16.0),
          child: flutter.Form(
            key: _formKey,
            child: flutter.SingleChildScrollView(
              child: flutter.Card(
                color: flutter.Colors.black.withOpacity(0.85),
                elevation: 5,
                shape: flutter.RoundedRectangleBorder(
                  borderRadius: flutter.BorderRadius.circular(12),
                  side: const flutter.BorderSide(color: flutter.Color(0xFF00B899), width: 0.5),
                ),
                child: flutter.Padding(
                  padding: const flutter.EdgeInsets.all(16.0),
                  child: flutter.Column(
                    children: [
                      // Role selection
                      flutter.DropdownButtonFormField<String>(
                        value: _role,
                        decoration: flutter.InputDecoration(
                          labelText: translate('Select Role'),
                          labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                          border: flutter.OutlineInputBorder(
                            borderRadius: flutter.BorderRadius.circular(12),
                            borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                          ),
                          filled: true,
                          fillColor: flutter.Colors.black.withOpacity(0.8),
                        ),
                        style: const flutter.TextStyle(color: flutter.Colors.white),
                        dropdownColor: flutter.Colors.black87,
                        items: ['Admin', 'Partner', 'Cluster Manager']
                            .map((role) => flutter.DropdownMenuItem(
                          value: role,
                          child: flutter.Text(translate(role)),
                        ))
                            .toList(),
                        onChanged: (value) => setState(() {
                          _role = value;
                          _vehicleInput = ''; // Reset vehicles
                          _attachments = []; // Reset attachments
                          _cluster = null; // Reset cluster
                        }),
                        validator: (value) => value == null ? translate('Role is required') : null,
                      ),
                      const flutter.SizedBox(height: 16),
                      // Cluster selection for Cluster Manager
                      if (_role == 'Cluster Manager') ...[
                        flutter.DropdownButtonFormField<String>(
                          value: _cluster,
                          decoration: flutter.InputDecoration(
                            labelText: translate('Select Cluster'),
                            labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                            border: flutter.OutlineInputBorder(
                              borderRadius: flutter.BorderRadius.circular(12),
                              borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                            ),
                            filled: true,
                            fillColor: flutter.Colors.black.withOpacity(0.8),
                            prefixIcon: const flutter.Icon(flutter.Icons.map, color: flutter.Color(0xFF00B899)),
                          ),
                          style: const flutter.TextStyle(color: flutter.Colors.white),
                          dropdownColor: flutter.Colors.black87,
                          items: _clusters
                              .map((cluster) => flutter.DropdownMenuItem(
                            value: cluster,
                            child: flutter.Text(cluster),
                          ))
                              .toList(),
                          onChanged: (value) => setState(() {
                            _cluster = value;
                          }),
                          validator: (value) => value == null ? translate('Cluster is required') : null,
                          onSaved: (value) => _cluster = value,
                        ),
                        const flutter.SizedBox(height: 16),
                      ],
                      // Common fields
                      flutter.TextFormField(
                        decoration: flutter.InputDecoration(
                          labelText: translate('User ID'),
                          labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                          border: flutter.OutlineInputBorder(
                            borderRadius: flutter.BorderRadius.circular(12),
                            borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                          ),
                          filled: true,
                          fillColor: flutter.Colors.black.withOpacity(0.8),
                          prefixIcon: const flutter.Icon(flutter.Icons.account_circle, color: flutter.Color(0xFF00B899)),
                        ),
                        style: const flutter.TextStyle(color: flutter.Colors.white),
                        validator: (value) => value!.isEmpty ? translate('User ID cannot be empty') : null,
                        onSaved: (value) => _userId = value!,
                      ),
                      const flutter.SizedBox(height: 16),
                      flutter.TextFormField(
                        decoration: flutter.InputDecoration(
                          labelText: translate('Username'),
                          labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                          border: flutter.OutlineInputBorder(
                            borderRadius: flutter.BorderRadius.circular(12),
                            borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                          ),
                          filled: true,
                          fillColor: flutter.Colors.black.withOpacity(0.8),
                          prefixIcon: const flutter.Icon(flutter.Icons.person, color: flutter.Color(0xFF00B899)),
                        ),
                        style: const flutter.TextStyle(color: flutter.Colors.white),
                        validator: (value) => value!.isEmpty ? translate('Username cannot be empty') : null,
                        onSaved: (value) => _username = value!,
                      ),
                      const flutter.SizedBox(height: 16),
                      flutter.TextFormField(
                        decoration: flutter.InputDecoration(
                          labelText: translate('Password'),
                          labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                          border: flutter.OutlineInputBorder(
                            borderRadius: flutter.BorderRadius.circular(12),
                            borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                          ),
                          filled: true,
                          fillColor: flutter.Colors.black.withOpacity(0.8),
                          prefixIcon: const flutter.Icon(flutter.Icons.lock, color: flutter.Color(0xFF00B899)),
                        ),
                        style: const flutter.TextStyle(color: flutter.Colors.white),
                        obscureText: true,
                        validator: (value) => value!.isEmpty ? translate('Password cannot be empty') : null,
                        onSaved: (value) => _password = value!,
                      ),
                      const flutter.SizedBox(height: 16),
                      flutter.TextFormField(
                        decoration: flutter.InputDecoration(
                          labelText: translate('Phone'),
                          labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                          border: flutter.OutlineInputBorder(
                            borderRadius: flutter.BorderRadius.circular(12),
                            borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                          ),
                          filled: true,
                          fillColor: flutter.Colors.black.withOpacity(0.8),
                          prefixIcon: const flutter.Icon(flutter.Icons.phone, color: flutter.Color(0xFF00B899)),
                        ),
                        style: const flutter.TextStyle(color: flutter.Colors.white),
                        keyboardType: flutter.TextInputType.phone,
                        validator: (value) => value!.isEmpty ? translate('Phone cannot be empty') : null,
                        onSaved: (value) => _phone = value!,
                      ),
                      const flutter.SizedBox(height: 16),
                      flutter.TextFormField(
                        decoration: flutter.InputDecoration(
                          labelText: translate('Email'),
                          hintText: translate('Optional'),
                          labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                          hintStyle: const flutter.TextStyle(color: flutter.Colors.grey),
                          border: flutter.OutlineInputBorder(
                            borderRadius: flutter.BorderRadius.circular(12),
                            borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                          ),
                          filled: true,
                          fillColor: flutter.Colors.black.withOpacity(0.8),
                          prefixIcon: const flutter.Icon(flutter.Icons.email, color: flutter.Color(0xFF00B899)),
                        ),
                        style: const flutter.TextStyle(color: flutter.Colors.white),
                        keyboardType: flutter.TextInputType.emailAddress,
                        onSaved: (value) => _email = value ?? '',
                      ),
                      const flutter.SizedBox(height: 16),
                      // Partner-specific fields
                      if (_role == 'Partner') ...[
                        flutter.TextFormField(
                          decoration: flutter.InputDecoration(
                            labelText: translate('Vehicles'),
                            hintText: 'e.g., XYZ123, ABC456',
                            labelStyle: const flutter.TextStyle(color: flutter.Colors.white70),
                            hintStyle: const flutter.TextStyle(color: flutter.Colors.grey),
                            border: flutter.OutlineInputBorder(
                              borderRadius: flutter.BorderRadius.circular(12),
                              borderSide: const flutter.BorderSide(color: flutter.Color(0xFF00B899)),
                            ),
                            filled: true,
                            fillColor: flutter.Colors.black.withOpacity(0.8),
                            prefixIcon: const flutter.Icon(flutter.Icons.directions_car, color: flutter.Color(0xFF00B899)),
                          ),
                          style: const flutter.TextStyle(color: flutter.Colors.white),
                          validator: (value) => value!.isEmpty ? translate('At least one vehicle is required') : null,
                          onSaved: (value) => _vehicleInput = value!,
                        ),
                        const flutter.SizedBox(height: 16),
                        flutter.Text(
                          translate('Attachments'),
                          style: const flutter.TextStyle(color: flutter.Colors.white, fontSize: 16, fontWeight: flutter.FontWeight.bold),
                        ),
                        const flutter.SizedBox(height: 8),
                        ..._attachments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final attachment = entry.value;
                          return flutter.ListTile(
                            title: flutter.Text(
                              attachment,
                              style: const flutter.TextStyle(color: flutter.Colors.white),
                            ),
                            trailing: flutter.IconButton(
                              icon: const flutter.Icon(flutter.Icons.delete, color: flutter.Colors.redAccent),
                              onPressed: () => setState(() => _attachments.removeAt(index)),
                            ),
                          );
                        }),
                        flutter.TextButton.icon(
                          onPressed: _addAttachment,
                          icon: const flutter.Icon(flutter.Icons.add, color: flutter.Color(0xFF00B899)),
                          label: flutter.Text(
                            translate('Add Attachment'),
                            style: const flutter.TextStyle(color: flutter.Color(0xFF00B899)),
                          ),
                        ),
                        const flutter.SizedBox(height: 16),
                      ],
                      flutter.ElevatedButton(
                        onPressed: _saveUser,
                        style: flutter.ElevatedButton.styleFrom(
                          backgroundColor: const flutter.Color(0xFF00B899),
                          foregroundColor: flutter.Colors.white,
                          padding: const flutter.EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: flutter.RoundedRectangleBorder(borderRadius: flutter.BorderRadius.circular(12)),
                          elevation: 5,
                        ),
                        child: flutter.Text(
                          translate('Save User'),
                          style: const flutter.TextStyle(fontSize: 16, fontWeight: flutter.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EditUserPage extends flutter.StatefulWidget {
  final User user;
  final String language; // Added language parameter

  const EditUserPage({super.key, required this.user, required this.language});

  @override
  _EditUserPageState createState() => _EditUserPageState();
}

class _EditUserPageState extends flutter.State<EditUserPage> {
  late flutter.TextEditingController _nameController;
  late flutter.TextEditingController _userIdController;
  late flutter.TextEditingController _passwordController;
  late flutter.TextEditingController _vehicleNumbersController;
  late flutter.TextEditingController _emailController;
  late flutter.TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = flutter.TextEditingController(text: widget.user.name);
    _userIdController = flutter.TextEditingController(text: widget.user.userId);
    _passwordController = flutter.TextEditingController(text: widget.user.password);
    _vehicleNumbersController = flutter.TextEditingController(text: widget.user.vehicles.join(','));
    _emailController = flutter.TextEditingController(text: widget.user.email ?? '');
    _phoneController = flutter.TextEditingController(text: widget.user.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _userIdController.dispose();
    _passwordController.dispose();
    _vehicleNumbersController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String translate(String key) => TranslationService.translate(key, widget.language);

  void _saveChanges() async {
    final updatedUser = User(
      name: _nameController.text,
      userId: _userIdController.text,
      password: _passwordController.text,
      vehicles: _vehicleNumbersController.text.split(',').map((v) => v.trim()).toList(),
      email: _emailController.text.isEmpty ? null : _emailController.text,
      phone: _phoneController.text,
      partnerId: widget.user.partnerId,
      attachments: widget.user.attachments,
      createdAt: widget.user.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    UserManager.updateUser(updatedUser);
    final mongoService = MongoDBService();
    await mongoService.savePartner(updatedUser);

    flutter.Navigator.pop(context, true); // Return true to trigger setState in ManageUsersPage
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Scaffold(
      appBar: flutter.AppBar(
        title: flutter.Text(translate('Edit User')),
        backgroundColor: const flutter.Color(0xFF00B899),
      ),
      body: flutter.Padding(
        padding: const flutter.EdgeInsets.all(16.0),
        child: flutter.Column(
          children: [
            flutter.TextField(
              controller: _nameController,
              decoration: flutter.InputDecoration(labelText: translate('Name')),
            ),
            flutter.TextField(
              controller: _userIdController,
              decoration: flutter.InputDecoration(labelText: translate('User ID')),
            ),
            flutter.TextField(
              controller: _passwordController,
              decoration: flutter.InputDecoration(labelText: translate('Password')),
            ),
            flutter.TextField(
              controller: _vehicleNumbersController,
              decoration: flutter.InputDecoration(labelText: translate('Vehicles (comma-separated)')),
            ),
            flutter.TextField(
              controller: _emailController,
              decoration: flutter.InputDecoration(labelText: translate('Email')),
            ),
            flutter.TextField(
              controller: _phoneController,
              decoration: flutter.InputDecoration(labelText: translate('Phone')),
            ),
            const flutter.SizedBox(height: 20),
            flutter.ElevatedButton(
              onPressed: _saveChanges,
              style: flutter.ElevatedButton.styleFrom(
                backgroundColor: const flutter.Color(0xFF00B899),
              ),
              child: flutter.Text(translate('Save')),
            ),
          ],
        ),
      ),
    );
  }
}

class ManageUsersPage extends flutter.StatefulWidget {
  final String language;

  const ManageUsersPage({super.key, required this.language});

  @override
  flutter.State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends flutter.State<ManageUsersPage> {
  final flutter.TextEditingController _adminPasswordController = flutter.TextEditingController();
  final MongoDBService _mongoService = MongoDBService();

  String translate(String key) => TranslationService.translate(key, widget.language);

  Future<void> _deleteUser(String userId) async {
    await flutter.showDialog(
      context: context,
      builder: (context) => flutter.AlertDialog(
        backgroundColor: flutter.Colors.black.withOpacity(0.9),
        shape: flutter.RoundedRectangleBorder(borderRadius: flutter.BorderRadius.circular(16)),
        title: flutter.Text(
          translate('Enter Admin Password'),
          style: const flutter.TextStyle(color: flutter.Colors.white, fontWeight: flutter.FontWeight.bold, fontSize: 20),
        ),
        content: flutter.TextField(
          controller: _adminPasswordController,
          obscureText: true,
          style: const flutter.TextStyle(color: flutter.Colors.white),
          decoration: flutter.InputDecoration(
            labelText: translate('Password'),
            labelStyle: const flutter.TextStyle(color: flutter.Colors.grey),
            filled: true,
            fillColor: flutter.Colors.grey[900],
            border: flutter.OutlineInputBorder(
              borderRadius: flutter.BorderRadius.circular(8),
              borderSide: flutter.BorderSide.none,
            ),
            prefixIcon: const flutter.Icon(flutter.Icons.lock, color: flutter.Colors.grey),
          ),
        ),
        actions: [
          flutter.TextButton(
            onPressed: () => flutter.Navigator.pop(context),
            child: flutter.Text(translate('Cancel'), style: const flutter.TextStyle(color: flutter.Color(0xFF00B899))),
          ),
          flutter.ElevatedButton(
            onPressed: () async {
              if (_adminPasswordController.text == 'admin123') {
                flutter.Navigator.pop(context);
                bool? confirm = await flutter.showDialog<bool>(
                  context: context,
                  builder: (context) => flutter.AlertDialog(
                    backgroundColor: flutter.Colors.black.withOpacity(0.9),
                    shape: flutter.RoundedRectangleBorder(borderRadius: flutter.BorderRadius.circular(16)),
                    title: flutter.Text(
                      translate('Confirm Deletion'),
                      style: const flutter.TextStyle(color: flutter.Colors.white, fontWeight: flutter.FontWeight.bold, fontSize: 20),
                    ),
                    content: flutter.Text(
                      translate('Are you sure you want to delete this user?'),
                      style: const flutter.TextStyle(color: flutter.Colors.grey, fontSize: 16),
                    ),
                    actions: [
                      flutter.TextButton(
                        onPressed: () => flutter.Navigator.pop(context, false),
                        child: flutter.Text(translate('Cancel'), style: const flutter.TextStyle(color: flutter.Color(0xFF00B899))),
                      ),
                      flutter.ElevatedButton(
                        onPressed: () => flutter.Navigator.pop(context, true),
                        style: flutter.ElevatedButton.styleFrom(
                          backgroundColor: flutter.Colors.redAccent,
                          shape: flutter.RoundedRectangleBorder(borderRadius: flutter.BorderRadius.circular(8)),
                        ),
                        child: flutter.Text(translate('Delete'), style: const flutter.TextStyle(color: flutter.Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  UserManager.deleteUser(userId);
                  await _mongoService.deletePartner(userId);
                  setState(() {});
                  flutter.ScaffoldMessenger.of(context).showSnackBar(
                    flutter.SnackBar(
                      content: flutter.Text(translate('User deleted successfully'), style: const flutter.TextStyle(color: flutter.Colors.white)),
                      backgroundColor: const flutter.Color(0xFF00B899),
                      behavior: flutter.SnackBarBehavior.floating,
                      shape: flutter.RoundedRectangleBorder(borderRadius: flutter.BorderRadius.circular(8)),
                      duration: const Duration(seconds: 2),
                      action: flutter.SnackBarAction(
                        label: translate('Dismiss'),
                        textColor: flutter.Colors.white,
                        onPressed: () => flutter.ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                      ),
                    ),
                  );
                }
              } else {
                flutter.Navigator.pop(context);
                flutter.ScaffoldMessenger.of(context).showSnackBar(
                  flutter.SnackBar(
                    content: flutter.Text(translate('Invalid admin password'), style: const flutter.TextStyle(color: flutter.Colors.white)),
                    backgroundColor: flutter.Colors.redAccent,
                    behavior: flutter.SnackBarBehavior.floating,
                    shape: flutter.RoundedRectangleBorder(borderRadius: flutter.BorderRadius.circular(8)),
                    duration: const Duration(seconds: 2),
                    action: flutter.SnackBarAction(
                      label: translate('Dismiss'),
                      textColor: flutter.Colors.white,
                      onPressed: () => flutter.ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                    ),
                  ),
                );
              }
              _adminPasswordController.clear();
            },
            style: flutter.ElevatedButton.styleFrom(
              backgroundColor: const flutter.Color(0xFF00B899),
              shape: flutter.RoundedRectangleBorder(borderRadius: flutter.BorderRadius.circular(8)),
            ),
            child: flutter.Text(translate('Submit'), style: const flutter.TextStyle(color: flutter.Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editUser(User user) {
    flutter.Navigator.push(
      context,
      flutter.MaterialPageRoute(builder: (context) => EditUserPage(language: widget.language, user: user)),
    ).then((result) {
      if (result == true) setState(() {});
    });
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Scaffold(
      backgroundColor: flutter.Colors.transparent,
      appBar: flutter.AppBar(
        title: flutter.Text(
          translate('Manage Users'),
          style: const flutter.TextStyle(
            color: flutter.Colors.white,
            fontSize: 24,
            fontWeight: flutter.FontWeight.bold,
            shadows: [
              flutter.Shadow(color: flutter.Colors.black54, blurRadius: 4, offset: flutter.Offset(1, 1)),
            ],
          ),
        ),
        backgroundColor: const flutter.Color(0xFF00B899),
        elevation: 6,
        shape: const flutter.RoundedRectangleBorder(
          borderRadius: flutter.BorderRadius.vertical(bottom: flutter.Radius.circular(16)),
        ),
        actions: [
          flutter.IconButton(
            icon: const flutter.Icon(flutter.Icons.refresh, color: flutter.Colors.white),
            tooltip: translate('Refresh'),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: flutter.Container(
        decoration: const flutter.BoxDecoration(
          gradient: flutter.LinearGradient(
            begin: flutter.Alignment.topLeft,
            end: flutter.Alignment.bottomRight,
            colors: [flutter.Color(0xFF1A1A1A), flutter.Color(0xFF2D2D2D)],
          ),
        ),
        child: UserManager.users.isEmpty
            ? flutter.Center(
          child: flutter.Column(
            mainAxisAlignment: flutter.MainAxisAlignment.center,
            children: [
              flutter.Icon(
                flutter.Icons.people_outline,
                size: 80,
                color: flutter.Colors.white.withOpacity(0.6),
              ),
              const flutter.SizedBox(height: 16),
              flutter.Text(
                translate('No users found'),
                style: const flutter.TextStyle(
                  color: flutter.Colors.white,
                  fontSize: 22,
                  fontWeight: flutter.FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        )
            : flutter.ListView.builder(
          padding: const flutter.EdgeInsets.all(16),
          itemCount: UserManager.users.length,
          itemBuilder: (context, index) {
            final user = UserManager.users[index];
            return flutter.AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: flutter.Curves.easeInOut,
              margin: const flutter.EdgeInsets.only(bottom: 8),
              child: flutter.Card(
                color: flutter.Colors.black.withOpacity(0.85),
                elevation: 5,
                shape: flutter.RoundedRectangleBorder(
                  borderRadius: flutter.BorderRadius.circular(12),
                  side: const flutter.BorderSide(color: flutter.Color(0xFF00B899), width: 0.5),
                ),
                child: flutter.ListTile(
                  contentPadding: const flutter.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  title: flutter.Text(
                    user.name,
                    style: const flutter.TextStyle(
                      color: flutter.Color(0xFF00B899),
                      fontSize: 18,
                      fontWeight: flutter.FontWeight.bold,
                    ),
                  ),
                  subtitle: flutter.Column(
                    crossAxisAlignment: flutter.CrossAxisAlignment.start,
                    children: [
                      const flutter.SizedBox(height: 4),
                      flutter.Text(
                        'ID: ${user.userId}',
                        style: flutter.TextStyle(color: flutter.Colors.grey[300], fontSize: 14),
                      ),
                      flutter.Text(
                        'Vehicles: ${user.vehicleNumbers}',
                        style: flutter.TextStyle(color: flutter.Colors.grey[300], fontSize: 14),
                        maxLines: 2,
                        overflow: flutter.TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: flutter.Row(
                    mainAxisSize: flutter.MainAxisSize.min,
                    children: [
                      flutter.IconButton(
                        icon: const flutter.Icon(flutter.Icons.edit, color: flutter.Color(0xFF00B899)),
                        tooltip: translate('Edit User'),
                        onPressed: () => _editUser(user),
                      ),
                      flutter.IconButton(
                        icon: const flutter.Icon(flutter.Icons.delete, color: flutter.Colors.redAccent),
                        tooltip: translate('Delete User'),
                        onPressed: () => _deleteUser(user.userId),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LiveTrackingPage extends flutter.StatefulWidget {
  final String language;

  const LiveTrackingPage({super.key, required this.language});

  @override
  flutter.State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends flutter.State<LiveTrackingPage> {
  final flutter.TextEditingController _vehicleNumberController = flutter.TextEditingController();
  Map<String, dynamic>? _machineData;
  bool _isLoading = false;
  String _errorMessage = '';

  String translate(String key) => TranslationService.translate(key, widget.language);

  Future<void> fetchMachineData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _machineData = null;
    });

    final vehicleNumber = _vehicleNumberController.text;
    if (vehicleNumber.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter a vehicle number';
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse(
          'http://13.127.144.213/webservice?token=getLiveData&user=Agrix&pass=123456&vehicle_no=$vehicleNumber&format=json'));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['root'] != null && jsonResponse['root']['VehicleData']?.isNotEmpty == true) {
          setState(() {
            _machineData = jsonResponse['root']['VehicleData'][0];
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No matching machine found';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to fetch data: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Scaffold(
      appBar: flutter.AppBar(title: flutter.Text(translate('Machine Tracking'))),
      body: flutter.Padding(
        padding: const flutter.EdgeInsets.all(16.0),
        child: flutter.Column(
          crossAxisAlignment: flutter.CrossAxisAlignment.start,
          children: [
            flutter.TextField(
              controller: _vehicleNumberController,
              decoration: flutter.InputDecoration(
                labelText: translate('Enter Vehicle Number'),
                border: const flutter.OutlineInputBorder(),
              ),
            ),
            const flutter.SizedBox(height: 16),
            flutter.ElevatedButton(onPressed: fetchMachineData, child: flutter.Text(translate('Fetch Data'))),
            const flutter.SizedBox(height: 16),
            if (_isLoading)
              const flutter.Center(child: flutter.CircularProgressIndicator())
            else if (_errorMessage.isNotEmpty)
              flutter.Text(_errorMessage, style: const flutter.TextStyle(color: flutter.Colors.red))
            else if (_machineData != null)
                flutter.Expanded(
                  child: flutter.SingleChildScrollView(
                    child: flutter.Column(
                      crossAxisAlignment: flutter.CrossAxisAlignment.start,
                      children: [
                        MachineInfoTile(translate('Vehicle Name'), _machineData!['Vehicle_Name'] ?? 'N/A'),
                        MachineInfoTile(translate('Company'), _machineData!['Company'] ?? 'N/A'),
                        MachineInfoTile(translate('Vehicle No'), _machineData!['Vehicle_No'] ?? 'N/A'),
                        MachineInfoTile(translate('Vehicle Type'), _machineData!['Vehicletype'] ?? 'N/A'),
                        MachineInfoTile(translate('Status'), _machineData!['Status'] ?? 'N/A'),
                        MachineInfoTile(translate('GPS'), _machineData!['GPS'] ?? 'N/A'),
                        MachineInfoTile(translate('Latitude'), _machineData!['Latitude'] ?? 'N/A'),
                        MachineInfoTile(translate('Longitude'), _machineData!['Longitude'] ?? 'N/A'),
                        MachineInfoTile(translate('Speed'), '${_machineData!['Speed'] ?? 'N/A'} km/h'),
                        MachineInfoTile(translate('Ignition'), _machineData!['IGN'] ?? 'N/A'),
                        MachineInfoTile(translate('Battery'), '${_machineData!['battery_percentage'] ?? 'N/A'}%'),
                        MachineInfoTile(translate('Last Updated'), _machineData!['Datetime'] ?? 'N/A'),
                        MachineInfoTile(translate('Location'), _machineData!['Location'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class TravelHistoryPage extends flutter.StatefulWidget {
  final String language;
  final bool isAdmin;
  final User? loggedInUser;

  const TravelHistoryPage({
    super.key,
    required this.language,
    required this.isAdmin,
    required this.loggedInUser,
  });

  @override
  flutter.State<TravelHistoryPage> createState() => _TravelHistoryPageState();
}

class _TravelHistoryPageState extends flutter.State<TravelHistoryPage> {
  String? _selectedUser;
  String? _selectedVehicle;
  List<Map<String, dynamic>> _locationHistory = [];
  bool _isLoading = false;
  String? _errorMessage;
  final MongoDBService _mongoService = MongoDBService();
  late MapController _mapController;

  bool _isPlaying = false;
  int _currentStep = 0;
  Timer? _animationTimer;
  LatLng? _currentVehiclePosition;

  List<String> _userList = [];
  List<String> _machineList = [];

  // Playback speed
  double _playbackSpeed = 1.0;
  final List<double> _speedOptions = [1.0, 1.25, 1.5, 1.75, 2.0];

  // Time range filter
  String _selectedTimeRange = '30d'; // Default to 30 days
  final List<Map<String, String>> _timeRangeOptions = [
    {'value': '24h', 'label': 'Past 24 Hours'},
    {'value': '7d', 'label': 'Past 7 Days'},
    {'value': '30d', 'label': 'Past 30 Days'},
    {'value': '90d', 'label': 'Past 90 Days'},
  ];

  String translate(String key) => TranslationService.translate(key, widget.language);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeData();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _mongoService.close();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      if (!_mongoService.isConnected || _mongoService._vehicleDb == null) {
        print('MongoDB not connected, attempting to connect...');
        await _mongoService.connect();
      }
      if (_mongoService._vehicleDb == null) {
        throw Exception('Failed to establish MongoDB connection');
      }
      print('MongoDB initialized');
      await _loadUsersAndMachines();
    } catch (e) {
      print('MongoDB init error: $e');
      setState(() => _errorMessage = 'Failed to connect: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsersAndMachines() async {
    setState(() => _isLoading = true);
    _userList = widget.isAdmin
        ? UserManager.users.map((user) => user.userId).toList()
        : widget.loggedInUser != null ? [widget.loggedInUser!.userId] : [];

    _selectedUser = _userList.isNotEmpty ? _userList.first : null;
    await _loadMachinesForUser();
    setState(() => _isLoading = false);
  }

  Future<void> _loadMachinesForUser() async {
    if (_selectedUser == null) {
      _machineList = [];
      _selectedVehicle = null;
      _locationHistory = [];
      return;
    }

    final selectedUserData = widget.isAdmin
        ? UserManager.users.firstWhere((user) => user.userId == _selectedUser)
        : widget.loggedInUser;

    setState(() {
      _machineList = selectedUserData != null
          ? selectedUserData.vehicleNumbers.split(',').map((v) => v.trim()).toList()
          : [];
      _selectedVehicle = _machineList.isNotEmpty ? _machineList.first : null;
      if (_selectedVehicle != null) {
        _fetchTravelHistory();
      }
    });
  }

  Future<void> _fetchTravelHistory() async {
    if (_selectedVehicle == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isPlaying = false;
      _currentStep = 0;
      _currentVehiclePosition = null;
      _animationTimer?.cancel();
    });

    try {
      if (!_mongoService.isConnected || _mongoService._vehicleDb == null) {
        print('MongoDB not connected in TravelHistoryPage, attempting to reconnect...');
        await _mongoService.connect();
        if (_mongoService._vehicleDb == null) {
          throw Exception('MongoDB reconnection failed');
        }
      }

      print('Fetching travel history for $_selectedVehicle');
      final db = _mongoService._vehicleDb!;
      final collection = db.collection(_selectedVehicle!);

      final now = DateTime.now().toUtc();
      DateTime pastDate;
      switch (_selectedTimeRange) {
        case '24h':
          pastDate = now.subtract(const Duration(hours: 24));
          break;
        case '7d':
          pastDate = now.subtract(const Duration(days: 7));
          break;
        case '90d':
          pastDate = now.subtract(const Duration(days: 90));
          break;
        case '30d':
        default:
          pastDate = now.subtract(const Duration(days: 30));
      }

      final results = await collection
          .find({'fetchedAt': {'\$gt': pastDate.toIso8601String()}})
          .toList()
        ..sort((a, b) => (a['fetchedAt'] as String).compareTo(b['fetchedAt'] as String));

      print('Raw results for $_selectedVehicle: $results');
      print('Fetched ${results.length} records for $_selectedVehicle');

      setState(() {
        _locationHistory = results
            .where((doc) {
          final lat = doc['Latitude'];
          final lon = doc['Longitude'];
          final latValid = lat != null && double.tryParse(lat.toString()) != null;
          final lonValid = lon != null && double.tryParse(lon.toString()) != null;
          if (!latValid || !lonValid) {
            print('Invalid coordinates filtered out: $doc');
          }
          return latValid && lonValid;
        })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching travel history for $_selectedVehicle: $e');
      setState(() {
        _errorMessage = 'Failed to load travel history: $e';
        _isLoading = false;
      });
    }
  }

  List<LatLng> _getPolylinePoints() {
    return _locationHistory
        .map((doc) => LatLng(
      double.parse(doc['Latitude'].toString()),
      double.parse(doc['Longitude'].toString()),
    ))
        .toList();
  }

  void _showPointDetails(LatLng point) {
    final doc = _locationHistory.firstWhere(
          (d) =>
      double.parse(d['Latitude'].toString()) == point.latitude &&
          double.parse(d['Longitude'].toString()) == point.longitude,
      orElse: () => {},
    );
    if (doc.isEmpty) return;
    flutter.showDialog(
      context: context,
      builder: (flutter.BuildContext context) => flutter.AlertDialog(
        title: const flutter.Text('Location Details'),
        content: flutter.Column(
          mainAxisSize: flutter.MainAxisSize.min,
          crossAxisAlignment: flutter.CrossAxisAlignment.start,
          children: [
            flutter.Text('Time: ${doc['fetchedAt']}'),
            flutter.Text('Speed: ${doc['Speed'] ?? 'N/A'} km/h'),
            flutter.Text('Latitude: ${doc['Latitude']}'),
            flutter.Text('Longitude: ${doc['Longitude']}'),
          ],
        ),
        actions: [
          flutter.TextButton(
            onPressed: () => flutter.Navigator.pop(context),
            child: const flutter.Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleAnimation() {
    final points = _getPolylinePoints();
    if (points.isEmpty) return;

    setState(() {
      if (_isPlaying) {
        _animationTimer?.cancel();
        _isPlaying = false;
      } else {
        _isPlaying = true;
        if (_currentStep >= points.length) _currentStep = 0;
        _currentVehiclePosition = points[_currentStep];
        _mapController.move(_currentVehiclePosition!, _mapController.zoom);
        final interval = Duration(milliseconds: (500 / _playbackSpeed).round());
        _animationTimer = Timer.periodic(interval, (timer) {
          setState(() {
            _currentStep++;
            if (_currentStep < points.length) {
              _currentVehiclePosition = points[_currentStep];
              _mapController.move(_currentVehiclePosition!, _mapController.zoom);
            } else {
              _currentStep = 0;
              _currentVehiclePosition = points[_currentStep];
              _mapController.move(_currentVehiclePosition!, _mapController.zoom);
            }
          });
        });
      }
    });
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Scaffold(
      backgroundColor: flutter.Colors.transparent,
      appBar: flutter.AppBar(
        title: flutter.Text(translate('Travel History')),
        backgroundColor: const flutter.Color(0xFF00B899),
      ),
      body: flutter.Column(
        children: [
          flutter.Padding(
            padding: const flutter.EdgeInsets.all(16.0),
            child: flutter.Column(
              children: [
                // User Dropdown
                flutter.DropdownButtonFormField<String>(
                  decoration: flutter.InputDecoration(
                    labelText: translate('Select User'),
                    labelStyle: const flutter.TextStyle(color: flutter.Colors.white),
                    border: const flutter.OutlineInputBorder(),
                    filled: true,
                    fillColor: flutter.Colors.black.withOpacity(0.7),
                  ),
                  style: const flutter.TextStyle(color: flutter.Colors.white),
                  dropdownColor: const flutter.Color(0xFF00B899),
                  value: _selectedUser,
                  items: _userList
                      .map((user) => flutter.DropdownMenuItem(
                    value: user,
                    child: flutter.Text(user, style: const flutter.TextStyle(color: flutter.Colors.white)),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUser = value;
                      _selectedVehicle = null;
                    });
                    _loadMachinesForUser();
                  },
                ),
                const flutter.SizedBox(height: 16),
                // Machine Dropdown
                flutter.DropdownButtonFormField<String>(
                  decoration: flutter.InputDecoration(
                    labelText: translate('Select Machine'),
                    labelStyle: const flutter.TextStyle(color: flutter.Colors.white),
                    border: const flutter.OutlineInputBorder(),
                    filled: true,
                    fillColor: flutter.Colors.black.withOpacity(0.7),
                  ),
                  style: const flutter.TextStyle(color: flutter.Colors.white),
                  dropdownColor: const flutter.Color(0xFF00B899),
                  value: _selectedVehicle,
                  items: _machineList
                      .map((vehicle) => flutter.DropdownMenuItem(
                    value: vehicle,
                    child: flutter.Text(vehicle, style: const flutter.TextStyle(color: flutter.Colors.white)),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedVehicle = value;
                      _fetchTravelHistory();
                    });
                  },
                ),
                const flutter.SizedBox(height: 16),
                // Time Range Dropdown
                flutter.DropdownButtonFormField<String>(
                  decoration: flutter.InputDecoration(
                    labelText: translate('Select Time Range'),
                    labelStyle: const flutter.TextStyle(color: flutter.Colors.white),
                    border: const flutter.OutlineInputBorder(),
                    filled: true,
                    fillColor: flutter.Colors.black.withOpacity(0.7),
                  ),
                  style: const flutter.TextStyle(color: flutter.Colors.white),
                  dropdownColor: const flutter.Color(0xFF00B899),
                  value: _selectedTimeRange,
                  items: _timeRangeOptions
                      .map((option) => flutter.DropdownMenuItem(
                    value: option['value'],
                    child: flutter.Text(
                      translate(option['label']!),
                      style: const flutter.TextStyle(color: flutter.Colors.white),
                    ),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTimeRange = value ?? '30d';
                      _fetchTravelHistory();
                    });
                  },
                ),
                const flutter.SizedBox(height: 16),
                // Playback Speed Dropdown
                flutter.DropdownButtonFormField<double>(
                  decoration: flutter.InputDecoration(
                    labelText: translate('Playback Speed'),
                    labelStyle: const flutter.TextStyle(color: flutter.Colors.white),
                    border: const flutter.OutlineInputBorder(),
                    filled: true,
                    fillColor: flutter.Colors.black.withOpacity(0.7),
                  ),
                  style: const flutter.TextStyle(color: flutter.Colors.white),
                  dropdownColor: const flutter.Color(0xFF00B899),
                  value: _playbackSpeed,
                  items: _speedOptions
                      .map((speed) => flutter.DropdownMenuItem(
                    value: speed,
                    child: flutter.Text('${speed}x', style: const flutter.TextStyle(color: flutter.Colors.white)),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _playbackSpeed = value ?? 1.0;
                      if (_isPlaying) {
                        _toggleAnimation(); // Stop current animation
                        _toggleAnimation(); // Restart with new speed
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          flutter.Expanded(
            child: _isLoading
                ? const flutter.Center(child: flutter.CircularProgressIndicator())
                : _errorMessage != null
                ? flutter.Center(
              child: flutter.Text(
                _errorMessage!,
                style: const flutter.TextStyle(color: flutter.Colors.white),
              ),
            )
                : _locationHistory.isEmpty
                ? flutter.Center(
              child: flutter.Text(
                translate('No data available'),
                style: const flutter.TextStyle(color: flutter.Colors.white),
              ),
            )
                : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _getPolylinePoints().isNotEmpty
                    ? _getPolylinePoints()[0]
                    : LatLng(25.5136222, 85.9772356),
                zoom: 13.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  subdomains: const ['a', 'b', 'c'],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _getPolylinePoints(),
                      strokeWidth: 4.0,
                      color: const flutter.Color(0xFF00B899),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (_locationHistory.isNotEmpty)
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: _getPolylinePoints().first,
                        builder: (ctx) => flutter.GestureDetector(
                          onTap: () => _showPointDetails(_getPolylinePoints().first),
                          child: const flutter.Icon(
                            flutter.Icons.location_pin,
                            color: flutter.Colors.blue,
                            size: 40,
                          ),
                        ),
                      ),
                    if (_locationHistory.length > 1)
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: _getPolylinePoints().last,
                        builder: (ctx) => flutter.GestureDetector(
                          onTap: () => _showPointDetails(_getPolylinePoints().last),
                          child: const flutter.Icon(
                            flutter.Icons.location_pin,
                            color: flutter.Colors.blue,
                            size: 40,
                          ),
                        ),
                      ),
                    if (_isPlaying && _currentVehiclePosition != null)
                      Marker(
                        width: 40.0,
                        height: 40.0,
                        point: _currentVehiclePosition!,
                        builder: (ctx) => flutter.Container(
                          decoration: flutter.BoxDecoration(
                            shape: flutter.BoxShape.circle,
                            color: flutter.Colors.white,
                            boxShadow: [
                              flutter.BoxShadow(
                                color: flutter.Colors.black.withOpacity(0.5),
                                spreadRadius: 2,
                                blurRadius: 4,
                                offset: const flutter.Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const flutter.EdgeInsets.all(4.0),
                          child: const flutter.Icon(
                            flutter.Icons.agriculture,
                            color: flutter.Color(0xFFFFA500),
                            size: 28,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          flutter.Padding(
            padding: const flutter.EdgeInsets.all(8.0),
            child: flutter.Row(
              mainAxisAlignment: flutter.MainAxisAlignment.spaceBetween,
              children: [
                flutter.IconButton(
                  icon: flutter.Icon(
                    _isPlaying ? flutter.Icons.pause : flutter.Icons.play_arrow,
                    color: const flutter.Color(0xFF00B899),
                  ),
                  onPressed: _locationHistory.isNotEmpty ? _toggleAnimation : null,
                ),
                flutter.Text(
                  'Tiles © Esri',
                  style: flutter.TextStyle(fontSize: 10, color: flutter.Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// TravelSummaryPage (updated to use Status field)
class TravelSummaryPage extends flutter.StatefulWidget {
  final String language;
  final bool isAdmin;
  final User? loggedInUser;

  const TravelSummaryPage({
    super.key,
    required this.language,
    required this.isAdmin,
    required this.loggedInUser,
  });

  @override
  flutter.State<TravelSummaryPage> createState() => _TravelSummaryPageState();
}

class _TravelSummaryPageState extends flutter.State<TravelSummaryPage> {
  String? _selectedUser;
  String? _selectedVehicle;
  List<String> _userList = [];
  List<String> _machineList = [];
  bool _isLoading = false;
  String? _errorMessage;
  final MongoDBService _mongoService = MongoDBService();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  List<Map<String, dynamic>> _summaryData = [];

  String translate(String key) => TranslationService.translate(key, widget.language);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _mongoService.close();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      if (!_mongoService.isConnected || _mongoService._vehicleDb == null) {
        await _mongoService.connect();
      }
      if (_mongoService._vehicleDb == null) {
        throw Exception(translate('Failed to establish MongoDB connection'));
      }
      await _loadUsersAndMachines();
    } catch (e) {
      setState(() => _errorMessage = '${translate('Failed to connect')}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _loadUsersAndMachines() async {
    setState(() => _isLoading = true);
    _userList = widget.isAdmin
        ? UserManager.users.map((user) => user.userId).toList()
        : widget.loggedInUser != null ? [widget.loggedInUser!.userId] : [];
    _selectedUser = _userList.isNotEmpty ? _userList.first : null;
    await _loadMachinesForUser();
    setState(() => _isLoading = false);
  }

  Future<void> _loadMachinesForUser() async {
    if (_selectedUser == null) {
      setState(() {
        _machineList = [];
        _selectedVehicle = null;
        _summaryData = [];
      });
      return;
    }

    final selectedUserData = widget.isAdmin
        ? UserManager.users.firstWhere((user) => user.userId == _selectedUser, orElse: () => widget.loggedInUser!)
        : widget.loggedInUser;

    setState(() {
      _machineList = selectedUserData != null
          ? selectedUserData.vehicles.map((v) => v.trim()).toList()
          : [];
      _selectedVehicle = _machineList.isNotEmpty ? _machineList.first : null;
      if (_selectedVehicle != null) {
        _fetchSummaryData();
      }
    });
  }

  Future<void> _fetchSummaryData() async {
    if (_selectedVehicle == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _summaryData = [];
    });

    try {
      if (!_mongoService.isConnected) {
        await _mongoService.connect();
      }
      final db = _mongoService._vehicleDb!;
      final collection = db.collection(_selectedVehicle!); // Verify this matches MongoDB collection

      final start = DateTime(_startDate.year, _startDate.month, _startDate.day).toUtc();
      final end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999).toUtc();

      print('Querying collection: ${_selectedVehicle}');
      print('Date range: ${start.toIso8601String()} to ${end.toIso8601String()}');

      final results = await collection
          .find({
        'fetchedAt': {
          '\$gte': start.toIso8601String(),
          '\$lte': end.toIso8601String(),
        }
      })
          .toList();

      print('Fetched ${results.length} documents for ${_selectedVehicle}');

      if (results.isNotEmpty) {
        results.sort((a, b) => (a['fetchedAt'] as String).compareTo(b['fetchedAt'] as String));
        print('First document: ${results.first}');
        print('Last document: ${results.last}');
      }

      final summary = _processVehicleData(results);
      setState(() {
        _summaryData = summary;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        _errorMessage = '${translate('Failed to load summary')}: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _processVehicleData(
      List<Map<String, dynamic>> data) {
    print('Processing ${data.length} documents');

    if (data.isEmpty) {
      print('No documents to process');
      return [];
    }

    final Map<String, Map<String, int>> dailySummary = {};

    for (var i = 0; i < data.length; i++) {
      final doc = data[i];
      if (doc['fetchedAt'] == null || doc['fetchedAt'] is! String) {
        print('Skipping document with invalid fetchedAt: $doc');
        continue;
      }
      DateTime? timestamp;
      try {
        timestamp = DateTime.parse(doc['fetchedAt']).toUtc();
      } catch (e) {
        print(
            'Skipping document with unparseable fetchedAt: ${doc['fetchedAt']}');
        continue;
      }
      final date = _dateFormat.format(timestamp);
      final status =
      (doc['Status']?.toString().toLowerCase() ?? 'inactive').trim();
      final validStatus = ['running', 'stop', 'inactive'].contains(status)
          ? status
          : 'inactive';

      dailySummary.putIfAbsent(
          date,
              () => {
            'running': 0,
            'stop': 0,
            'inactive': 0,
          });

      // Calculate duration from this timestamp to next or end of day
      int delta = 0;
      if (i < data.length - 1) {
        final nextDoc = data[i + 1];
        if (nextDoc['fetchedAt'] == null || nextDoc['fetchedAt'] is! String) {
          print('Skipping next document with invalid fetchedAt: $nextDoc');
          continue;
        }
        DateTime? nextTimestamp;
        try {
          nextTimestamp = DateTime.parse(nextDoc['fetchedAt']).toUtc();
        } catch (e) {
          print(
              'Skipping next document with unparseable fetchedAt: ${nextDoc['fetchedAt']}');
          continue;
        }
        if (_dateFormat.format(nextTimestamp) == date) {
          delta = nextTimestamp.difference(timestamp).inSeconds;
        } else {
          final endOfDay = DateTime(
              timestamp.year, timestamp.month, timestamp.day, 23, 59, 59)
              .toUtc();
          delta = endOfDay.difference(timestamp).inSeconds;
        }
      } else {
        final endOfDay =
        DateTime(timestamp.year, timestamp.month, timestamp.day, 23, 59, 59)
            .toUtc();
        delta = endOfDay.difference(timestamp).inSeconds;
      }

      if (delta > 0) {
        dailySummary[date]![validStatus] =
            (dailySummary[date]![validStatus] ?? 0) + delta;
        print('Added $delta seconds to $validStatus on $date');
      }
    }

    final summaryList = <Map<String, dynamic>>[];
    var currentDate =
    DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);

    while (!currentDate.isAfter(endDate)) {
      final Map<String, Map<String, int>> dailySummary = {};

      // Sort data to ensure chronological order
      data.sort((a, b) {
        final aTime = DateTime.tryParse(a['fetchedAt'] ?? '')?.toUtc();
        final bTime = DateTime.tryParse(b['fetchedAt'] ?? '')?.toUtc();
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });

      for (int i = 0; i < data.length - 1; i++) {
        final current = data[i];
        final next = data[i + 1];

        final currentFetchedAt =
        DateTime.tryParse(current['fetchedAt'] ?? '')?.toUtc();
        final nextFetchedAt =
        DateTime.tryParse(next['fetchedAt'] ?? '')?.toUtc();

        if (currentFetchedAt == null || nextFetchedAt == null) continue;

        final currentDateStr = _dateFormat.format(currentFetchedAt);
        if (currentFetchedAt.isBefore(_startDate) ||
            currentFetchedAt.isAfter(_endDate)) continue;

        final status =
        (current['Status']?.toString().toLowerCase() ?? 'inactive').trim();
        final validStatus = ['running', 'stop', 'inactive'].contains(status)
            ? status
            : 'inactive';

        dailySummary.putIfAbsent(
            currentDateStr,
                () => {
              'running': 0,
              'stop': 0,
              'inactive': 0,
            });

        final sameDay = _dateFormat.format(nextFetchedAt) == currentDateStr;
        final duration = sameDay
            ? nextFetchedAt.difference(currentFetchedAt).inSeconds
            : DateTime(currentFetchedAt.year, currentFetchedAt.month,
            currentFetchedAt.day, 23, 59, 59)
            .difference(currentFetchedAt)
            .inSeconds;

        dailySummary[currentDateStr]![validStatus] =
            (dailySummary[currentDateStr]![validStatus] ?? 0) + duration;

        print('Added $duration seconds to $validStatus on $currentDateStr');
      }

      /*  final dateStr = _dateFormat.format(currentDate);
      final daySummary = dailySummary[dateStr] ?? {'running': 0, 'stop': 0, 'inactive': 0};

      final running = daySummary['running'] ?? 0;
      final stop = daySummary['stop'] ?? 0;
      final inactive = daySummary['inactive'] ?? 0;

      summaryList.add({
        'date': dateStr,
        'running': running,
        'stop': stop,
        'inactive': inactive,
      });

      print('Summary for $dateStr: running=$running, stop=$stop, inactive=$inactive');

      currentDate = currentDate.add(const Duration(days: 1));
    */
    }

    return summaryList;
  }

  String _formatDuration(int? seconds) {
    final secs = seconds ?? 0;
    final hours = secs ~/ 3600;
    final minutes = (secs % 3600) ~/ 60;
    final remainingSecs = secs % 60;
    return '${hours}h ${minutes}m ${remainingSecs}s';
  }

  Future<void> _selectDateRange() async {
    final picked = await flutter.showDateRangePicker(
      context: context,
      initialDateRange: flutter.DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return flutter.Theme(
          data: flutter.ThemeData.dark().copyWith(
            colorScheme: const flutter.ColorScheme.dark(
              primary: flutter.Color(0xFF00B899),
              onPrimary: flutter.Colors.white,
              surface: flutter.Colors.black,
              onSurface: flutter.Colors.white,
            ),
            dialogBackgroundColor: flutter.Colors.black,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        if (_selectedVehicle != null) {
          _fetchSummaryData();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            translate('Travel Summary'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                    color: Colors.black54, blurRadius: 4, offset: Offset(1, 1)),
              ],
            ),
          ),
          backgroundColor: const Color(0xFF00B899),
          elevation: 6,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownSearch<String>(
                      popupProps: PopupProps.menu(showSearchBox: true),
                      items: _userList,
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: translate('Select User'),
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Color(0xFF00B899)),
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.8),
                          prefixIcon: const Icon(Icons.person,
                              color: Color(0xFF00B899)),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedUser = value;
                          _selectedVehicle = null;
                          _summaryData = [];
                        });
                        _loadMachinesForUser();
                      },
                      selectedItem: _selectedUser,
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<String>(
                      popupProps: PopupProps.menu(showSearchBox: true),
                      items: _machineList,
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: translate('Select Vehicle'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Color(0xFF00B899)),
                          ),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.8),
                          prefixIcon: const Icon(Icons.directions_car,
                              color: Color(0xFF00B899)),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedVehicle = value;
                          if (value != null) {
                            _fetchSummaryData();
                          }
                        });
                      },
                      selectedItem: _selectedVehicle,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _selectDateRange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B899),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: Text(
                        '${_dateFormat.format(_startDate)} - ${_dateFormat.format(_endDate)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const flutter.Center(
                  child: CircularProgressIndicator(
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF00B899)),
                  ),
                )
                    : _errorMessage != null
                    ? flutter.Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                )
                    : _summaryData.isEmpty
                    ? flutter.Center(
                    child: Text(translate('No data available')))
                    : ListView(
                  children: _summaryData.map((entry) {
                    return Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadowColor: Colors.grey.withOpacity(0.4),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: ListTile(
                        contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        title: Text(
                          '📅 Date: ${entry['date']}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                                'Running: ${_formatDuration(entry['running'])}'),
                            Text(
                                'Stop: ${_formatDuration(entry['stop'])}'),
                            Text(
                                'Inactive: ${_formatDuration(entry['inactive'])}'),
                          ],
                        ),

                        /*
                      child: ListTile(
                        title: Text('Date: ${entry['date']}'),
                        subtitle: Text(
                          'Running: ${_formatDuration(entry['running'])}\n'
                              'Stop: ${_formatDuration(entry['stop'])}\n'
                              'Inactive: ${_formatDuration(entry['inactive'])}',
                        ),*/
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Request background location permission
Future<void> requestBackgroundLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print('Location permission denied');
      return;
    }
  }
  if (permission == LocationPermission.deniedForever) {
    print('Location permission denied forever');
    await Geolocator.openAppSettings();
    return;
  }
  if (!await Geolocator.isLocationServiceEnabled()) {
    print('Location service disabled');
    await Geolocator.openLocationSettings();
    return;
  }
  // Android 10+ background location
  if (await Geolocator.checkPermission() != LocationPermission.always) {
    print('Requesting background location permission');
    permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.always) {
      print('Background location permission not granted. Opening settings.');
      await Geolocator.openAppSettings();
    }
  }
  print('Location permissions granted: ${await Geolocator.checkPermission()}');
}

class BusinessPage extends flutter.StatelessWidget {
  final String language;

  const BusinessPage({super.key, required this.language});

  String translate(String key) => TranslationService.translate(key, language);

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Scaffold(
      appBar: flutter.AppBar(title: flutter.Text(translate('Business'))),
      body: const flutter.Center(child: flutter.Text('Area Page - Under Construction')),
    );
  }
}

class AnnouncementPage extends flutter.StatelessWidget {
  final String language;

  const AnnouncementPage({super.key, required this.language});

  String translate(String key) => TranslationService.translate(key, language);

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.Scaffold(
      appBar: flutter.AppBar(title: flutter.Text(translate('Announcement Details'))),
      body: const flutter.Center(child: flutter.Text('Announcements Page - Under Construction')),
    );
  }
}