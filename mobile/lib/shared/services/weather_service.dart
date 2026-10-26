import 'package:dio/dio.dart';

class WeatherData {
  final double temperature;
  final int weatherCode;
  final double precipitation;
  final String condition;
  final String city;

  const WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.precipitation,
    required this.condition,
    required this.city,
  });

  bool get isRainy => ['rain', 'drizzle', 'thunderstorm', 'showers'].contains(condition);
  bool get isCold => temperature < 18;
  bool get isHot => temperature > 33;
  bool get isFoggy => condition == 'fog';

  String get packingHint {
    if (isRainy) return 'Rain expected ($temperature°C) — grab your umbrella and waterproof shoes';
    if (isCold) return 'Cold today (${temperature.toStringAsFixed(0)}°C) — bring a jacket or warm layer';
    if (isHot) return 'Hot and sunny (${temperature.toStringAsFixed(0)}°C) — carry your water bottle';
    if (isFoggy) return 'Foggy morning (${temperature.toStringAsFixed(0)}°C) — drive carefully';
    return 'Pleasant weather today (${temperature.toStringAsFixed(0)}°C) — ${condition == 'clear' ? 'great day to head out!' : 'light layers work well'}';
  }

  String get packingEmoji {
    if (isRainy) return '☂️';
    if (isCold) return '🧥';
    if (isHot) return '💧';
    if (isFoggy) return '🌫️';
    return '🌤️';
  }
}

class WeatherService {
  static const _lat = 19.0760; // Mumbai default
  static const _lon = 72.8777;
  static const _city = 'Mumbai';

  final Dio _dio;

  WeatherService() : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));

  Future<WeatherData> fetchCurrent() async {
    final resp = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': _lat,
        'longitude': _lon,
        'current': 'temperature_2m,weathercode,precipitation',
        'timezone': 'Asia/Kolkata',
      },
    );
    final current = resp.data['current'] as Map<String, dynamic>;
    final temp = (current['temperature_2m'] as num).toDouble();
    final code = (current['weathercode'] as num).toInt();
    final precip = (current['precipitation'] as num).toDouble();
    return WeatherData(
      temperature: temp,
      weatherCode: code,
      precipitation: precip,
      condition: _codeToCondition(code),
      city: _city,
    );
  }

  static String _codeToCondition(int code) {
    if (code == 0 || code == 1) return 'clear';
    if (code == 2 || code == 3) return 'cloudy';
    if (code == 45 || code == 48) return 'fog';
    if (code >= 51 && code <= 57) return 'drizzle';
    if (code >= 61 && code <= 67) return 'rain';
    if (code >= 71 && code <= 77) return 'snow';
    if (code >= 80 && code <= 82) return 'showers';
    if (code == 95 || code == 96 || code == 99) return 'thunderstorm';
    return 'cloudy';
  }
}
