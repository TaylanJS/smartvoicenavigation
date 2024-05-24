import 'dart:async';
import 'dart:convert';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main(List<String> args) {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FlutterTts flutterTts = FlutterTts();

  String nowAdress = '';
  Position? _currentPosition;
  GoogleMapController? _mapController;
  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
    });
  }

  String travelMode = "";
  static const LatLng origin = LatLng(41.0201066, 29.1890479);
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    //getPolyPoints();
  }

  List sonKonumlar = [];
  LatLng firstAdress = LatLng(origin.latitude, origin.longitude);
  void _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = position;
      firstAdress = LatLng(position.latitude, position.longitude);
      if (kDebugMode) {
        print(position);
      }
      _markers.add(
        Marker(
          markerId: const MarkerId("currentPosition"),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: "Current Position"),
        ),
      );
    });
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    }
  }

  List<LatLng> polylineCoordinates = [];
  void getPolyPoints(double a, double b) async {
    if (_currentPosition != null) {
      // ignore: unrelated_type_equality_checks
      _markers.removeWhere((marker) => marker.markerId.value == "nextPosition");
      if (kDebugMode) {
        print('İf Geldi');
      }
      PolylinePoints polylinePoints = PolylinePoints();

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        'Google Apisi GElecek',
        PointLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        PointLatLng(a, b),
      );
      if (result.points.isNotEmpty) {
        polylineCoordinates.clear();
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
        _markers.add(
          Marker(
            markerId: const MarkerId("nextPosition"),
            position: LatLng(a, b),
            infoWindow: const InfoWindow(title: "Next Position"),
          ),
        );
        setState(() {});
      }
    } else {
      if (kDebugMode) {
        print('Hata Oluştu');
      }
    }
  }

//! Api Alır ve Konum verir + otobğs tarifi yapıyoruz
  Future<Object> getDirections(LatLng start, LatLng end) async {
    // Google API anahtarınız.
    const String apiKey = "Google Api";
    final String apiUrl =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$apiKey&mode=transit&transit_mode=bus&language=tr';

    final response = await http.get(Uri.parse(apiUrl));
    Map<String, dynamic> data = json.decode(response.body);
    List<dynamic> routes = data['routes'];
    if (kDebugMode) {
      print(data['routes']);
    }
    if (routes.isNotEmpty) {
      List<String> instructions = [];

      // Yürüyüş adımlarını kontrol et
      List<String> walkingDirections = await getWalkingDirections(data);

      instructions.addAll(walkingDirections);

      String busInfo = await getBusInfo(data);
      instructions.add(busInfo);

      return instructions;
    } else {
      return "";
    }
  }

  Future<List<String>> getWalkingDirections(Map<String, dynamic> data) async {
    List<String> walkingInstructions = [];
    List<dynamic> routes = data['routes'];
    List<dynamic> legs = routes[0]['legs'];
    List<dynamic> steps = legs[0]['steps'];

    for (var step in steps) {
      if (step['travel_mode'] == 'WALKING') {
        int distance = step['distance']['value'];
        if (distance < 1000) {
          String instruction = formatWalkingInstruction(step);
          walkingInstructions.add(instruction);
        }
      }
    }
    return walkingInstructions;
  }

  String formatWalkingInstruction(dynamic step) {
    String instruction = step['html_instructions'];
    int distance = step['distance']['value'];
    String direction = stripHtml(instruction);

    // Adres bilgilerini ve gereksiz detayları çıkar, sadece yön bilgisi ve mesafe bırak
    direction = removeUnnecessaryDetails(direction);

    return "$distance metre boyunca $direction";
  }

  String stripHtml(String htmlText) {
    return htmlText.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  String removeUnnecessaryDetails(String text) {
    // Adres bilgilerini ve diğer gereksiz detayları temizle
    text = text.replaceAll('/Kocaeli', '');
    text = text.replaceAll('/İstanbul', '');
    text = text.replaceAll('Türkiye', '');
    text = text.replaceAll('No', '');
    text =
        text.replaceAll(RegExp(r'\d+/\w+'), ''); // "6/a" gibi numaraları çıkar
    text = text.replaceAll(
        RegExp(r'\d{5}'), ''); // "34782" gibi posta kodlarını çıkar
    text =
        text.replaceAll(RegExp(r'[\d-]+'), ''); // "6" gibi tek numaraları çıkar
    text =
        text.replaceAll(RegExp(r'\s+'), ' ').trim(); // Fazla boşlukları temizle

    return text;
  }

  Future<String> getBusInfo(Map<String, dynamic> data) async {
    List<dynamic> routes = data['routes'];
    List<dynamic> legs = routes[0]['legs'];
    List<dynamic> steps = legs[0]['steps'];

    String busInfo = 'Otobüs bilgisi bulunamadı.';

    for (var step in steps) {
      if (step['travel_mode'] == 'TRANSIT' && step['transit_details'] != null) {
        dynamic transitDetails = step['transit_details'];
        if (kDebugMode) {
          print(transitDetails);
        }
        String busName = transitDetails['line']['short_name'];
        String departureStop = transitDetails['departure_stop']['name'];
        String arrivalStop = transitDetails['arrival_stop']['name'];

        busInfo =
            "$busName numaralı otobüse binin, $departureStop durağından kalkacak ve $arrivalStop durağında ineceksiniz.";
        break;
      }
    }
    return busInfo;
  }

  Future<Map<String, dynamic>> fetchDirections(
      LatLng origin, LatLng destination, String mode) async {
    const apiKey = 'Google Api';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${firstAdress.latitude},${firstAdress.longitude}&destination=${destination.latitude},${destination.longitude}&mode=$mode&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load directions');
    }
  }

  Future<void> getTextToAdress(String adress) async {
    if (kDebugMode) {
      print('Gelen Adres: $adress');
    }
    if (adress.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress(adress);
        if (locations.isNotEmpty) {
          Location location = locations.first;
          if (kDebugMode) {
            print('Konum: ${location.latitude}, ${location.longitude}');
          }
          LatLng nextAdress = LatLng(location.latitude, location.longitude);
          var walkingDirections =
              await fetchDirections(firstAdress, nextAdress, 'walking');
          var transitDirections =
              await fetchDirections(firstAdress, nextAdress, 'transit');

          // Süreleri karşılaştır
          int walkingDuration = walkingDirections['routes'].isNotEmpty
              ? walkingDirections['routes'][0]['legs'][0]['duration']['value']
              : -2;

          int transitDuration = transitDirections['routes'].isNotEmpty
              ? transitDirections['routes'][0]['legs'][0]['duration']['value']
              : -1;

          String travelMode = 'walking';
          if (transitDuration < walkingDuration) {
            travelMode = 'transit';
          }
          var directions = await getDirections(firstAdress, nextAdress);
          if (!sonKonumlar.contains(adress)) {
            sonKonumlar.add(adress);
          }
          getPolyPoints(location.latitude, location.longitude);

          await flutterTts.setLanguage("tr-TR");
          await flutterTts.setPitch(0.85);
          await flutterTts.speak(directions.toString());

          await flutterTts.awaitSpeakCompletion(true);
          Future.delayed(const Duration(seconds: 5), () async {
            if (travelMode == 'transit') {
              await flutterTts.setPitch(0.85);
              await flutterTts.speak(
                  "Taşıt İle Daha Hızlı Gidiliyor Taşıt bilgisi açılıyor");
              await flutterTts.awaitSpeakCompletion(true);
              String googleMapsUrl =
                  "https://www.google.com/maps/dir/?api=1&destination=${nextAdress.latitude},${nextAdress.longitude}&travelmode=transit";

              // ignore: deprecated_member_use
              await launch(googleMapsUrl);
            } else {
              await flutterTts.setPitch(0.85);
              await flutterTts.speak(
                  "Yürüyerek  Daha Hızlı Gidiliyor yürüme bilgisi açılıyor");
              await flutterTts.awaitSpeakCompletion(true);
              String googleMapsUrl =
                  "https://www.google.com/maps/dir/?api=1&destination=${nextAdress.latitude},${nextAdress.longitude}&travelmode=walking&dir_action=navigate";

              // ignore: deprecated_member_use
              await launch(googleMapsUrl);
            }
          });
        }
      } on NoResultFoundException {
        await flutterTts.speak("Lütfen tekrardan sesleniniz.");
        if (kDebugMode) {
          print(
              "NoResultFoundException: Adres veya koordinatlar için sonuç bulunamadı.");
        }
      }
    } else {
      await flutterTts.speak("Lütfen tekrardan sesleniniz.");
      if (kDebugMode) {
        print("Adres Boş Geldi.");
      }
    }
  }

  final Set<Marker> _markers = {
    // Marker(
    //   markerId: MarkerId('source'),
    //   position: destination,
    // )
  };

  int selectedIndex = 1;
  bool dinleme = false;
  static String spokenText = '';

  final stt.SpeechToText speech = stt.SpeechToText();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        floatingActionButton: selectedIndex == 1
            ? Padding(
                padding: const EdgeInsets.only(top: 30),
                child: AvatarGlow(
                    animate: speech.isListening,
                    curve: Curves.linear,
                    glowColor: const Color.fromARGB(255, 93, 0, 255),
                    child: FloatingActionButton(
                      backgroundColor: const Color.fromARGB(255, 93, 0, 255),
                      onPressed: () async {
                        getVoice();
                      },
                      child: const Icon(
                        Icons.voice_chat,
                        color: Colors.white,
                      ),
                    )),
              )
            : null,
        body: selectedIndex == 1
            ? Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: const Offset(
                                  0, 3), // changes position of shadow
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: GoogleMap(
                            polylines: {
                              Polyline(
                                width: 4,
                                color: const Color.fromARGB(255, 93, 0, 255),
                                polylineId: const PolylineId('route'),
                                points: polylineCoordinates,
                              ),
                            },
                            initialCameraPosition: CameraPosition(
                              target: _currentPosition != null
                                  ? LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                    )
                                  : const LatLng(0, 0),
                              zoom: 15,
                            ),
                            onMapCreated: _onMapCreated,
                            markers: _markers,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  spokenText.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  spreadRadius: 5,
                                  blurRadius: 7,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  spokenText,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(),
                  const SizedBox(height: 20),
                ],
              )
            : sonKonumlar.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'En Son Gitmek İstedikleriniz',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemBuilder: (context, index) {
                              return Card(
                                color: const Color.fromARGB(255, 93, 0, 255),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.white,
                                    child: Text((index + 1).toString()),
                                  ),
                                  title: Text(
                                    sonKonumlar[index].toString(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  trailing: IconButton(
                                      onPressed: () async {
                                        List<Location> locations =
                                            await locationFromAddress(
                                                sonKonumlar[index].toString());
                                        LatLng nextAdress = LatLng(
                                            locations.first.latitude,
                                            locations.first.longitude);

                                        await flutterTts.speak(
                                            "${sonKonumlar[index]} Rota Bilgisi Açılıyor");
                                        String googleMapsUrl =
                                            "https://www.google.com/maps/dir/?api=1&destination=${nextAdress.latitude},${nextAdress.longitude}&travelmode=walking&dir_action=navigate";

                                        Future.delayed(
                                            const Duration(seconds: 5),
                                            () async {
                                          // ignore: deprecated_member_use
                                          await launch(googleMapsUrl);
                                        });
                                      },
                                      icon: const CircleAvatar(
                                        backgroundColor: Colors.white,
                                        child: Icon(
                                          Icons.navigation_outlined,
                                          color:
                                              Color.fromARGB(255, 93, 0, 255),
                                        ),
                                      )),
                                ),
                              );
                            },
                            itemCount: sonKonumlar.length,
                          ),
                        ),
                      ],
                    ),
                  )
                : const Center(
                    child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Geçmişte Adres Yok ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 25),
                      ),
                      Icon(Icons.history)
                    ],
                  )),
        backgroundColor: Colors.white,
        bottomNavigationBar: CurvedNavigationBar(
            index: 1,
            onTap: (value) {
              selectedIndex = value;
              setState(() {});
            },
            height: 60,
            color: const Color.fromARGB(255, 93, 0, 255),
            backgroundColor: Colors.white,
            animationDuration: const Duration(milliseconds: 300),
            // ignore: prefer_const_literals_to_create_immutables
            items: [
              const Icon(
                Icons.home,
                color: Colors.white,
                size: 30,
              ),
              const Icon(
                Icons.navigation,
                color: Colors.white,
                size: 30,
              ),
            ]),
      ),
    );
  }

  void getVoice() async {
    if (!speech.isListening) {
      bool available = await speech.initialize(onStatus: (status) async {
        if (kDebugMode) {
          print('Status: $status');
        }
      }, onError: (errorNotification) {
        if (kDebugMode) {
          print('Error: $errorNotification');
        }
      });
      if (available) {
        speech.listen(
          onResult: (result) {
            spokenText = result.recognizedWords;
          },
        );
      }
    } else {
      speech.stop();
    }
    Future.delayed(const Duration(seconds: 6), () {
      getTextToAdress(spokenText);
    });
    setState(() {});
  }
}
