import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class Mapstreet extends StatefulWidget {
  const Mapstreet({super.key});

  @override
  State<Mapstreet> createState() => _MapstreetState();
}

class _MapstreetState extends State<Mapstreet> {
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSuggestions = false;
  final MapController _mapController = MapController();
  final TextEditingController _locationController = TextEditingController();
  bool isLoading = true;
  LatLng? _currentLocation;
  LatLng? _destination;
  Timer? _debounceTimer;
  String? _lastQuery;
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _locationController.dispose();
    super.dispose();
  }

  final Duration _debounceDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      bool permissionGranted = await _checkTheRequestPermission();
      if (!permissionGranted) {
        errorMessage(
          "Akses lokasi ditolak. Aktifkan izin lokasi di pengaturan.",
        );
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Ambil posisi awal via Geolocator
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (position.longitude != null) {
        if (!mounted) return;
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          isLoading = false;
        });
      }

      // Dengarkan perubahan lokasi
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        });
      });
    } catch (e) {
      errorMessage("Gagal mendapatkan lokasi: $e");
    }
  }

  Future<void> fetchCordinatesPoint(String location) async {
    final trimmed = location.trim();
    if (trimmed.length < 3) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _showSuggestions = false;
      });
      return;
    }
    _lastQuery = trimmed;
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'json',
      'addressdetails': '1',
      'limit': '5',
    });
    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'test_map_app/1.0 (contact: abimanyupw369@gmail.com)',
          'Accept': 'application/json',
        },
      );
      if (_lastQuery != trimmed) return; // abaikan respons lama
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(data);
            _showSuggestions = true;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _searchResults = [];
            _showSuggestions = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak ada hasil yang ditemukan')),
          );
        }
      } else {
        if (!mounted) return;
        setState(() {
          _searchResults = [];
          _showSuggestions = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengambil data lokasi')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _showSuggestions = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kesalahan jaringan: $e')));
    }
  }

  Future<bool> _checkTheRequestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      errorMessage('Layanan lokasi tidak aktif');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        errorMessage('Izin lokasi ditolak');
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      errorMessage('Izin lokasi ditolak permanen. Aktifkan di Pengaturan.');
      return false;
    }
    return true;
  }

  Future<void> _userCurrentLocation() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    } else {
      // Handle the case where the current location is not available
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lokasi saat ini tidak tersedia')));
    }
  }

  void errorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('Peta Contoh'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          isLoading
              ? Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? LatLng(0, 0),
                    initialZoom: 18,
                    minZoom: -20,
                    maxZoom: 100,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.example.test_map', // ganti dengan package name aplikasi Anda
                    ),
                    CurrentLocationLayer(
                      style: LocationMarkerStyle(
                        marker: Container(
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(
                              0.4,
                            ), // transparan
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.deepPurple,
                              width: 1,
                            ),
                          ),
                          width: 60,
                          height: 60,
                          child: Center(
                            child: Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        markerSize: const Size(100, 100),
                        markerDirection: MarkerDirection.heading,
                      ),
                    ),
                    if (_destination != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _destination!,
                            width: 80,
                            height: 80,
                            child: Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'Masukkan lokasi',
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_locationController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _locationController.clear();
                                _searchResults = [];
                                _showSuggestions = false;
                              });
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () {
                            final location = _locationController.text;
                            if (location.isNotEmpty) {
                              fetchCordinatesPoint(location);
                            }
                          },
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    print('[DEBUG] onChanged: $value');
                    if (_debounceTimer?.isActive ?? false) {
                      _debounceTimer!.cancel();
                    }
                    if (value.isNotEmpty) {
                      _debounceTimer = Timer(_debounceDuration, () {
                        print('[DEBUG] Debounce timer triggered for: $value');
                        fetchCordinatesPoint(value);
                      });
                      setState(
                        () {},
                      ); // agar tombol clear muncul/hilang sesuai input
                    } else {
                      setState(() {
                        _searchResults = [];
                        _showSuggestions = false;
                      });
                    }
                  },
                ),
                if (_showSuggestions && _searchResults.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    margin: EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        final displayName = result['display_name'] ?? '';
                        final lat = result['lat'];
                        final lon = result['lon'];
                        return ListTile(
                          title: Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Lat: $lat, Lon: $lon'),
                          onTap: () {
                            setState(() {
                              _destination = LatLng(
                                double.parse(lat),
                                double.parse(lon),
                              );
                              _currentLocation = _destination;
                              _showSuggestions = false;
                              _locationController.text = displayName;
                            });
                            _mapController.move(_destination!, 15);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        elevation: 0,
        onPressed: _userCurrentLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }
}
