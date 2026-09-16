import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../data/models/cinema_model.dart';
import '../../data/models/movie_model.dart';
import '../../data/models/purchase_session.dart';
import '../../data/models/showtime_model.dart';
import '../2_home/widgets/cinema_selector_sheet.dart';
import '../4_tickets/tickets_view.dart';
import 'widgets/movie_synopsis_sheet.dart';
import 'widgets/showtime_chip.dart';
import 'widgets/trailer_modal.dart';

class ShowtimesView extends StatefulWidget {
  final Movie movie;

  const ShowtimesView({super.key, required this.movie});

  @override
  State<ShowtimesView> createState() => _ShowtimesViewState();
}

class _ShowtimesViewState extends State<ShowtimesView> {
  final PurchaseSession _session = PurchaseSession();
  late Cinema _currentCinema;
  late DateTime _selectedDate;
  final List<DateTime> _dates = [];

  @override
  void initState() {
    super.initState();
    TelemetryTracker().startStep('Showtimes');

    _currentCinema = _session.selectedCinema ??
        MockData.cinemas.firstWhere(
          (c) => c.id == AppConstants.defaultCinemaId,
          orElse: () => MockData.cinemas.first,
        );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (int i = 0; i < 4; i++) {
      _dates.add(today.add(Duration(days: i)));
    }
    _selectedDate = _dates.first;
    _session.selectDate(_selectedDate);

    // Iniciar temporizador de compra al entrar a horarios (Heurística #1: Visibilidad del estado)
    if (!_session.isTimerRunning) {
      _session.startTimer();
    }
  }

  void _openCinemaSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CinemaSelectorSheet(
        currentCinema: _currentCinema,
        onCinemaSelected: (newCinema) {
          setState(() {
            _currentCinema = newCinema;
          });
          _session.setCinema(newCinema);
        },
      ),
    );
  }

  void _onShowtimeSelected(Showtime showtime) {
    TelemetryTracker().completeStep('Showtimes');
    _session.selectShowtime(showtime);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TicketsView(movie: widget.movie, showtime: showtime),
      ),
    );
  }

  String _formatDateDay(DateTime dt, int index) {
    const months = [
      'Ene.', 'Feb.', 'Mar.', 'Abr.', 'May.', 'Jun.',
      'Jul.', 'Ago.', 'Sept.', 'Oct.', 'Nov.', 'Dic.'
    ];
    const days = ['Lun.', 'Mar.', 'Mié.', 'Jue.', 'Vie.', 'Sáb.', 'Dom.'];
    final monthStr = months[dt.month - 1];
    if (index == 0) return '$monthStr ${dt.day}\nHoy';
    final dayStr = days[dt.weekday - 1];
    return '$monthStr ${dt.day}\n$dayStr';
  }

  @override
  Widget build(BuildContext context) {
    final showtimesForDay = widget.movie.getShowtimesForDateAndCinema(
      _selectedDate,
      _currentCinema.id,
    );

    // Agrupar horarios por formato
    final formatGroups = <String, List<Showtime>>{};
    for (final st in showtimesForDay) {
      final key = '${st.format} • ${st.language}';
      formatGroups.putIfAbsent(key, () => []).add(st);
    }

    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        if (_session.isSessionExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTimeoutDialog();
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // Hero Banner con tráiler y sinopsis
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Imagen Backdrop
                    Image.network(
                      widget.movie.backdropUrl,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 250,
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.movie, size: 60, color: Colors.white24),
                      ),
                    ),
                    // Gradiente de desvanecimiento
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.5),
                              Colors.transparent,
                              AppColors.background.withValues(alpha: 0.9),
                              AppColors.background,
                            ],
                            stops: const [0.0, 0.4, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // AppBar Superior con Contador visible
                    Positioned(
                      top: 40,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 20,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          // Temporizador visible activo (Heurística Nielsen #1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _session.isTimerCritical
                                  ? AppColors.timerUrgent
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: _session.isTimerCritical
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _session.formattedTimeRemaining,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _session.isTimerCritical
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Información y Botones sobre la imagen
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.movie.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Botón "Ver tráiler"
                              InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => TrailerModal(movie: widget.movie),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF333333),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Ver trailer',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.play_arrow, size: 14, color: Colors.white),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Badges y enlace de sinopsis
                          Row(
                            children: [
                              Flexible(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        widget.movie.duration,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFE082),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        widget.movie.ratingDescription,
                                        style: const TextStyle(
                                          color: Color(0xFF5D4037),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC8E6C9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        widget.movie.genre.split('/').first.trim(),
                                        style: const TextStyle(
                                          color: Color(0xFF1B5E20),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => MovieSynopsisSheet(movie: widget.movie),
                                  );
                                },
                                child: const Text(
                                  'Ver sinopsis',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Selector de 4 Días
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_dates.length, (index) {
                      final date = _dates[index];
                      final isSelected = date.day == _selectedDate.day;

                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                            right: index < _dates.length - 1 ? 8 : 0,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedDate = date;
                              });
                              _session.selectDate(date);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                _formatDateDay(date, index),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Barra de selección de Cine
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _currentCinema.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _openCinemaSelector,
                        child: const Text(
                          'Cambiar cine',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Lista de Horarios por Formato
              if (formatGroups.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 48, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          const Text(
                            'No hay horarios disponibles',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No se encontraron funciones para esta fecha en ${_currentCinema.name}. Elige otro día o consulta otra sede.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _openCinemaSelector,
                            style: ElevatedButton.styleFrom(minimumSize: const Size(180, 42)),
                            child: const Text('Ver Otras Sedes'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final formatKey = formatGroups.keys.elementAt(index);
                        final showtimes = formatGroups[formatKey]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        formatKey,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chair_outlined, size: 14, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text(
                                        'Disponibilidad en vivo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: showtimes.map((st) {
                                  return ShowtimeChip(
                                    showtime: st,
                                    onSelected: _onShowtimeSelected,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: formatGroups.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, color: AppColors.primary, size: 50),
            const SizedBox(height: 14),
            const Text(
              'Tiempo límite expirado',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Por seguridad y para liberar los asientos reservados a otros usuarios, la sesión de compra ha finalizado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _session.startTimer();
              },
              child: const Text('REINICIAR TIEMPO'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('VOLVER AL INICIO'),
            ),
          ],
        ),
      ),
    );
  }
}
