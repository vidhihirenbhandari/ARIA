import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/aria_color_scheme.dart';
import '../../../../shared/models/aria_travel.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../data/travel_repository.dart';
import '../widgets/travel_suggestion_card.dart';

class TravelScreen extends ConsumerStatefulWidget {
  const TravelScreen({super.key});

  @override
  ConsumerState<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends ConsumerState<TravelScreen> {
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
    final bookingsAsync = ref.watch(upcomingTravelProvider);

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
            // Upcoming trip hero — driven by first booking from API
            bookingsAsync.when(
              data: (bookings) {
                final flight = bookings.where((b) => b.type == 'flight').firstOrNull;
                if (flight != null) {
                  return _buildUpcomingTripFromBooking(flight);
                }
                return _buildNoUpcomingTrip();
              },
              loading: () => _buildTripShimmer(),
              error: (_, __) => _buildNoUpcomingTrip(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text('ARIA Suggests', style: AppTextStyles.headlineSmall),
            ),
            ..._suggestions.asMap().entries.map((e) => TravelSuggestionCard(
                  title: e.value['title'] as String,
                  subtitle: e.value['subtitle'] as String,
                  icon: e.value['icon'] as IconData,
                  accentColor: e.value['color'] as Color,
                  onApprove: () => setState(() => _suggestions.removeAt(e.key)),
                  onDismiss: () => setState(() => _suggestions.removeAt(e.key)),
                )),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text('Your Bookings', style: AppTextStyles.headlineSmall),
            ),
            // Bookings list from API
            bookingsAsync.when(
              data: (bookings) {
                if (bookings.isEmpty) {
                  return _buildNoBookings();
                }
                return Column(
                  children: bookings.map((b) => _buildBookingCard(b)).toList(),
                );
              },
              loading: () => Column(
                children: List.generate(2, (_) => _buildBookingShimmer()),
              ),
              error: (_, __) => _buildNoBookings(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTripShimmer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  Widget _buildBookingShimmer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildNoUpcomingTrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text(
          'No upcoming flights',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildNoBookings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'No confirmed bookings found.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildUpcomingTripFromBooking(TravelBooking booking) {
    final themeIndex = ref.watch(themeIndexProvider);
    final scheme = AriaColorScheme.presets[themeIndex.clamp(0, AriaColorScheme.presets.length - 1)];

    final airline = booking.details['airline'] as String? ?? '';
    final flightNumber = booking.details['flightNumber'] as String? ?? '';
    final from = booking.details['from'] as String? ?? '---';
    final to = booking.details['to'] as String? ?? '---';
    final bookingRef = booking.details['bookingRef'] as String? ?? '';
    final dep = booking.departureTime;
    final arr = booking.arrivalTime;
    final depTime = '${dep.hour.toString().padLeft(2, '0')}:${dep.minute.toString().padLeft(2, '0')}';
    final arrTime = arr != null
        ? '${arr.hour.toString().padLeft(2, '0')}:${arr.minute.toString().padLeft(2, '0')}'
        : '';
    final duration = arr != null ? arr.difference(dep) : null;
    final durationLabel = duration != null
        ? '${duration.inHours}h ${(duration.inMinutes % 60).toString().padLeft(2, '0')}m'
        : '';

    const white = Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.accent, scheme.accentSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Trip',
                      style: AppTextStyles.headlineSmall.copyWith(color: white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tomorrow · $airline $flightNumber',
                      style: AppTextStyles.caption.copyWith(color: white.withOpacity(0.65)),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Confirmed',
                        style: AppTextStyles.caption.copyWith(
                          color: white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Dashed divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(
                40,
                (i) => Expanded(
                  child: Container(
                    height: 1,
                    color: i.isEven ? white.withOpacity(0.25) : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
          // Flight route
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Departure
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      from,
                      style: AppTextStyles.displaySmall.copyWith(
                        color: white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      depTime,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // Route line
                Expanded(
                  child: Column(
                    children: [
                      if (durationLabel.isNotEmpty)
                        Text(
                          durationLabel,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(color: white.withOpacity(0.65)),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Container(height: 1, color: white.withOpacity(0.3)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Transform.rotate(
                              angle: 0,
                              child: Icon(Icons.flight_rounded, color: white, size: 18),
                            ),
                          ),
                          Expanded(
                            child: Container(height: 1, color: white.withOpacity(0.3)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrival
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      to,
                      style: AppTextStyles.displaySmall.copyWith(
                        color: white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      arrTime,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Bottom info row
          if (bookingRef.isNotEmpty || airline.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                children: [
                  if (airline.isNotEmpty)
                    _infoChip(Icons.airlines_rounded, airline),
                  if (airline.isNotEmpty && bookingRef.isNotEmpty)
                    const SizedBox(width: 8),
                  if (bookingRef.isNotEmpty)
                    _infoChip(Icons.confirmation_number_outlined, 'Ref: $bookingRef'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
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
                      ? (booking.details['hotel'] as String? ?? 'Hotel')
                      : '${booking.details['airline'] ?? ''} ${booking.details['flightNumber'] ?? ''}',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  isHotel
                      ? '${booking.details['checkIn'] ?? ''} → ${booking.details['checkOut'] ?? ''}'
                      : '${booking.details['from'] ?? ''} → ${booking.details['to'] ?? ''}',
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
