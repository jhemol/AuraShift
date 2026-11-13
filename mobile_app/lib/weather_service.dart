import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherSnapshot {
  const WeatherSnapshot({required this.temperature, required this.precipitation, required this.description});

  final double temperature;
  final double precipitation;
  final String description;
}

class WeatherService {
  Future<WeatherSnapshot> forecastFor(String city) async {
    final locationUri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': city,
      'count': '1',
      'language': 'en',
      'format': 'json',
    });
    final locationResponse = await http.get(locationUri).timeout(const Duration(seconds: 8));
    if (locationResponse.statusCode != 200) {
      throw const FormatException('Could not look up that location.');
    }
    final locationBody = jsonDecode(locationResponse.body);
    if (locationBody is! Map<String, dynamic>) throw const FormatException('The location response was incomplete.');
    final locations = locationBody['results'];
    if (locations is! List || locations.isEmpty || locations.first is! Map<String, dynamic>) {
      throw const FormatException('No matching city was found.');
    }
    final location = locations.first as Map<String, dynamic>;
    final latitude = location['latitude'], longitude = location['longitude'];
    if (latitude is! num || longitude is! num) throw const FormatException('The location response was incomplete.');
    final forecastUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current': 'temperature_2m,precipitation,weather_code',
      'temperature_unit': 'celsius',
      'timezone': 'auto',
    });
    final forecastResponse = await http.get(forecastUri).timeout(const Duration(seconds: 8));
    if (forecastResponse.statusCode != 200) throw const FormatException('Weather is temporarily unavailable.');
    final forecastBody = jsonDecode(forecastResponse.body);
    if (forecastBody is! Map<String, dynamic> || forecastBody['current'] is! Map<String, dynamic>) {
      throw const FormatException('The weather response was incomplete.');
    }
    final current = forecastBody['current'] as Map<String, dynamic>;
    if (current['temperature_2m'] is! num || current['precipitation'] is! num || current['weather_code'] is! num) {
      throw const FormatException('The weather response was incomplete.');
    }
    return WeatherSnapshot(
      temperature: (current['temperature_2m'] as num).toDouble(),
      precipitation: (current['precipitation'] as num).toDouble(),
      description: _description((current['weather_code'] as num).toInt()),
    );
  }

  String _description(int code) => switch (code) {
        0 => 'Clear skies',
        1 || 2 => 'Mostly clear',
        3 => 'Cloudy',
        45 || 48 => 'Foggy',
        51 || 53 || 55 || 56 || 57 => 'Drizzle',
        61 || 63 || 65 || 66 || 67 => 'Rain',
        71 || 73 || 75 || 77 => 'Snow',
        80 || 81 || 82 => 'Rain showers',
        85 || 86 => 'Snow showers',
        95 || 96 || 99 => 'Thunderstorms',
        _ => 'Weather updated',
      };
}
