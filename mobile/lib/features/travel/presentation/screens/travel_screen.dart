import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/aria_travel.dart';
import '../widgets/travel_suggestion_card.dart';

class TravelScreen extends ConsumerStatefulWidget {
  const TravelScreen({super.key});

  @override
  ConsumerState<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends ConsumerState<TravelScreen> {
  final List<TravelBooking> _bookings = [
    TravelBooking(
      id: '1',
      userId: 'u1',
      type: 'flight',
      departureTime: DateTime.now().add(const Duration(days: 1, hours: 7)),
      status: 'confirmed',
      details: {
        'airline': 'IndiGo',
        'flightNumber': '6E-203',
        'from': 'DEL',
        'to': 'BOM',
        'seat': '14A',
        'bookingRef': 'IND7X3',
      },
    ),
    TravelBooking(
      id: '2',
      userId: 'u1',
      type: 'hotel',
      departureTime: DateTime.now().add(const Duration(days: 1)),
      status: 'confirmed',
      details: {
        'hotel': 'Taj Hotel Mumbai',
        'checkIn': 'Jan 17',
        'checkOut': 'Jan 19',
        'roomType': 'Superior Room',
        'bookingRef': 'TAJ2847',
      },
    ),
  ];

  final List<Map<String, dynamic>> _suggestions = [
    {
      'title': 'Set Wake-Up Alarm',
      'subtitle': 'Flight at 7:00 AM — suggest 4:30 AM alarm',
      'icon': Icons.alarm_outlined,
      'color': AppColors.warning,
    },
    {
      'title': 'Book Airport Cab',
      'subtitle': 'Terminal 2 — allow 90 min for check-in',
      'icon': Icons.local_taxi_outlined,
      'color': AppColors.accent,
    },
    {
      'title': 'Check Weather',
      'subtitle': 'Mumbai: 28°C, partly cloudy tomorrow',
      'icon': Icons.wb_sunny_outlined,
      'color': AppColors.warning,
    },
    {
      'title': 'Start Packing Checklist',
      'subtitle': '2-night trip — generate checklist?',
      'icon': Icons.luggage_outlined,
      'color': AppColors.secondary,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Travel', style: AppTextStyles.headlineLarge),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUpcomingTrip(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text('ARIA Suggests', style: AppTextStyles.headlineSmall),
            ),
            ..._suggestions.asMap().entries.map((e) => TravelSuggestionCard(
                  title: e.value['title'],
                  subtitle: e.value['subtitle'],
                  icon: e.value['icon'],
                  accentColor: e.value['color'],
                  onApprove: () => setState(() => _suggestions.removeAt(e.key)),
                  onDismiss: () => setState(() => _suggestions.removeAt(e.key)),
                )),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text('Your Bookings', style: AppTextStyles.headlineSmall),
            ),
            ..._bookings.map((b) => _buildBookingCard(b)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingTrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2040), Color(0xFF0D1220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upcoming Trip', style: AppTextStyles.headlineSmall),
                  Text(
                    'Tomorrow · IndiGo 6E-203',
                    style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAirport('DEL', 'Delhi', '7:00 AM'),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Expanded(
                          child: Container(
                            height: 1,
                            color: i == 4
                                ? Colors.transparent
                                : AppColors.accent.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.flight, color: AppColors.accent, size: 16),
                    const SizedBox(height: 4),
                    Text('2h 15m', style: AppTextStyles.caption),
                  ],
                ),
              ),
              _buildAirport('BOM', 'Mumbai', '9:15 AM'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAirport(String code, String city, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(code, style: AppTextStyles.displaySmall.copyWith(color: AppColors.accent)),
        Text(city, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(time, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildBookingCard(TravelBooking booking) {
    final isHotel = booking.type == 'hotel';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isHotel ? AppColors.secondary : AppColors.accent).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isHotel ? Icons.hotel_outlined : Icons.flight_outlined,
              color: isHotel ? AppColors.secondary : AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHotel
                      ? booking.details['hotel'] as String
                      : '${booking.details['airline']} ${booking.details['flightNumber']}',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  isHotel
                      ? '${booking.details['checkIn']} → ${booking.details['checkOut']}'
                      : '${booking.details['from']} → ${booking.details['to']}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Confirmed',
              style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
