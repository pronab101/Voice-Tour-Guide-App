import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'camera_screen.dart';
import 'google_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  MyApp({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Tour Guide',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: MainScreen(cameras: cameras),
    );
  }
}

class MainScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  MainScreen({required this.cameras});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeLayout(cameras: widget.cameras),
      CameraScreen(cameras: widget.cameras),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Tour Guide', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt), label: 'Camera'),
        ],
      ),
    );
  }
}

class HomeLayout extends StatefulWidget {
  final List<CameraDescription> cameras;

  HomeLayout({required this.cameras});

  @override
  _HomeLayoutState createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  List<Map<String, dynamic>> landmarks = [];
  bool isLoading = false;
  String selectedCategory = "Historical"; // Default category
  String errorMessage = ""; // Store error message

  final List<String> categories = [
    "Historical",
    "Cultural",
    "Natural",
    "Religious",
    "Modern",
  ];

  @override
  void initState() {
    super.initState();
    fetchLandmarks();
  }

  Future<void> fetchLandmarks() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    final String hfApiKey = "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";
    final String modelName = "mistralai/Mistral-7B-Instruct-v0.3";

    try {
      final response = await http
          .post(
            Uri.parse("https://api-inference.huggingface.co/models/$modelName"),
            headers: {
              "Authorization": "Bearer $hfApiKey",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "inputs":
                  "List 4 famous $selectedCategory landmarks in London with their name, description, latitude, and longitude in JSON format.",
            }),
          )
          .timeout(Duration(seconds: 20));

      print("API Response: ${response.body}");

      if (response.statusCode == 200) {
        List<Map<String, dynamic>> fetchedLandmarks =
            parseLandmarkResponse(response.body);

        // Fetch images for each landmark
        for (var i = 0; i < fetchedLandmarks.length; i++) {
          String imageUrl =
              await fetchWikimediaImage(fetchedLandmarks[i]["name"]);
          fetchedLandmarks[i]["image"] = imageUrl;
        }

        setState(() {
          landmarks = fetchedLandmarks;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "API Error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Network error: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  Future<String> fetchWikimediaImage(String landmarkName) async {
    final url =
        "https://en.wikipedia.org/w/api.php?action=query&format=json&prop=pageimages&pithumbsize=500&titles=$landmarkName";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final pages = jsonData["query"]["pages"];

        if (pages != null) {
          for (var key in pages.keys) {
            final page = pages[key];
            if (page.containsKey("thumbnail")) {
              return page["thumbnail"]["source"];
            }
          }
        }
      }
    } catch (e) {
      print("⚠️ Error fetching Wikimedia image: $e");
    }

    // Use a Wikimedia fallback image
    return "https://upload.wikimedia.org/wikipedia/commons/1/14/No_Image_Available.jpg";
  }



  List<Map<String, dynamic>> parseLandmarkResponse(String responseText) {
    List<Map<String, dynamic>> parsedLandmarks = [];

    try {
      final jsonResponse = jsonDecode(responseText);

      if (jsonResponse is List && jsonResponse.isNotEmpty && jsonResponse[0].containsKey("generated_text")) {
        String generatedText = jsonResponse[0]["generated_text"];

        int jsonStartIndex = generatedText.indexOf("[");
        int jsonEndIndex = generatedText.lastIndexOf("]") + 1;

        if (jsonStartIndex != -1 && jsonEndIndex != -1) {
          String jsonString = generatedText.substring(jsonStartIndex, jsonEndIndex);

          final landmarks = jsonDecode(jsonString);

          if (landmarks is List) {
            for (var item in landmarks) {
              // Ensure latitude and longitude exist, otherwise print an error
              if (!item.containsKey("latitude") || !item.containsKey("longitude")) {
                print("Error: Missing latitude/longitude for ${item["name"]}");
                continue; // Skip this landmark if location data is missing
              }

              parsedLandmarks.add({
                "name": item["name"] ?? "Unknown Landmark",
                "details": item["description"] ?? "No details available.",
                "latitude": (item["latitude"] is String)
                    ? double.tryParse(item["latitude"]) ?? (throw FormatException("Invalid latitude format"))
                    : (item["latitude"] is double)
                    ? item["latitude"]
                    : (throw FormatException("Invalid latitude type")),

                "longitude": (item["longitude"] is String)
                    ? double.tryParse(item["longitude"]) ?? (throw FormatException("Invalid longitude format"))
                    : (item["longitude"] is double)
                    ? item["longitude"]
                    : (throw FormatException("Invalid longitude type")),

              "image": item["image_url"] ?? "https://upload.wikimedia.org/wikipedia/commons/1/14/No_Image_Available.jpg",
              });
            }
          }
        }
      }
    } catch (e) {
      print("Error parsing response: $e");
    }

    return parsedLandmarks;
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String>(
            value: selectedCategory,
            items: categories.map((String category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (String? newCategory) {
              if (newCategory != null) {
                setState(() {
                  selectedCategory = newCategory;
                  fetchLandmarks();
                });
              }
            },
          ),
        ),
        Expanded(
          child: isLoading
              ? Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
                  ? Center(
                      child: Text(errorMessage,
                          style: TextStyle(color: Colors.red)))
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                        ),
                        itemCount: landmarks.length,
                        itemBuilder: (context, index) {
                          final landmark = landmarks[index];
                          return GestureDetector(
                            onTap: () {
                              final double latitude = landmark['latitude']!;
                              final double longitude = landmark['longitude']!;
                              final LatLng location = LatLng(latitude, longitude);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GoogleMapScreen(
                                    landmarkName: landmark['name']!,
                                    landmarkDetails: landmark['details']!,
                                    location: location,
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(12)),
                                      child: CachedNetworkImage(
                                        imageUrl: landmark['image']!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Center(
                                            child: CircularProgressIndicator()),
                                        errorWidget: (context, url, error) =>
                                            Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      landmark['name']!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
