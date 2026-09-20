import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../data/models/movie_model.dart';
import '../../data/models/purchase_session.dart';
import '../../data/models/seat_model.dart';
import '../../data/models/showtime_model.dart';
import '../../core/widgets/order_summary_bottom_sheet.dart';
import '../../core/widgets/purchase_exit_dialog.dart';
import '../6_concessions/concessions_view.dart';

class SeatsView extends StatefulWidget {
  final Movie movie;
  final Showtime showtime;

  const SeatsView({
    super.key,
    required this.movie,
    required this.showtime,
  });

  @override
  State<SeatsView> createState() => _SeatsViewState();
}

class _SeatsViewState extends State<SeatsView> {
  final PurchaseSession _session = PurchaseSession();
  final TransformationController _transformController =
      TransformationController();

  late List<Seat> _seats;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    TelemetryTracker().startStep('Seats');
    _seats = MockData.generateSeats(widget.showtime.id);

    // Ajustar zoom inicial centrado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _zoomReset();
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _currentScale = (_currentScale + 0.35).clamp(0.8, 3.5);
      _applyScale(_currentScale);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentScale = (_currentScale - 0.35).clamp(0.8, 3.5);
      _applyScale(_currentScale);
    });
  }

  void _zoomReset() {
    setState(() {
      _currentScale = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  void _applyScale(double scale) {
    _transformController.value = Matrix4.diagonal3Values(scale, scale, 1.0);
  }

  void _onSeatTapped(Seat seat) {
    if (seat.status == SeatStatus.occupied) {
      TelemetryTracker().recordError(
        'Seats',
        'Asiento Ocupado',
        'El usuario intentó seleccionar el asiento ocupado ${seat.id}',
      );
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El asiento ${seat.id} ya se encuentra reservado.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final maxSeats = _session.totalTicketCount > 0 ? _session.totalTicketCount : 1;
    final isCurrentlySelected = _session.selectedSeats.contains(seat.id);

    if (!isCurrentlySelected && _session.selectedSeats.length >= maxSeats) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ya seleccionaste tus $maxSeats asientos. Toca uno seleccionado para cambiarlo.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _session.toggleSeat(seat.id, maxAllowed: maxSeats);
  }

  void _onContinue() {
    TelemetryTracker().completeStep('Seats');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ConcessionsView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketTypes = MockData.getTicketTypes();

    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final totalTickets = _session.totalTicketCount > 0 ? _session.totalTicketCount : 1;
        final selectedCount = _session.selectedSeats.length;
        final isComplete = selectedCount == totalTickets;
        final totalAmount = _session.calculateTotalAmount(ticketTypes);

        Future<void> handleExit() async {
          final shouldExit = await PurchaseExitDialog.show(context);
          if (shouldExit && context.mounted) {
            _session.resetSession();
            TelemetryTracker().finishSession(isCompleted: false, maxStepReached: 'Seats');
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await handleExit();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
                onPressed: handleExit,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Elige tus Asientos',
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.movie.title} • ${widget.showtime.roomName} (${widget.showtime.format})',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                // Temporizador visible (Heurística #1 de Nielsen)
                Container(
                  margin: const EdgeInsets.only(right: 4, top: 12, bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _session.isTimerCritical
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _session.isTimerCritical
                          ? AppColors.error
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: _session.isTimerCritical
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _session.formattedTimeRemaining,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _session.isTimerCritical
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                  tooltip: 'Cancelar compra y salir',
                  onPressed: handleExit,
                ),
              ],
            ),
            body: Column(
              children: [
                // Barra de Instrucción y Estado de Selección
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Butacas: $selectedCount de $totalTickets seleccionadas',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isComplete ? AppColors.success : AppColors.textPrimary,
                        ),
                      ),
                      if (isComplete)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '¡Completo!',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Leyenda de Asientos (Heurística #6: Reconocimiento antes que recuerdo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegendItem(
                        color: Colors.grey[200]!,
                        borderColor: Colors.grey[400]!,
                        label: 'Disponible',
                      ),
                      _buildLegendItem(
                        color: AppColors.primary,
                        borderColor: AppColors.primary,
                        label: 'Tu selección',
                      ),
                      _buildLegendItem(
                        color: Colors.grey[400]!,
                        borderColor: Colors.grey[500]!,
                        label: 'Ocupado',
                      ),
                      _buildLegendItem(
                        color: AppColors.formatXd.withValues(alpha: 0.15),
                        borderColor: AppColors.formatXd,
                        icon: Icons.accessible_rounded,
                        label: 'Preferencial',
                      ),
                    ],
                  ),
                ),

                // Área Interactiva de Sala con Pantalla y Zoom Controls
                Expanded(
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.8,
                        maxScale: 3.5,
                        constrained: true,
                        clipBehavior: Clip.none,
                        boundaryMargin: const EdgeInsets.symmetric(
                          horizontal: 140,
                          vertical: 140,
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Representación visual de la Pantalla del cine
                                  _buildScreenWidget(),
                                  const SizedBox(height: 30),

                                  // Matriz de Asientos
                                  _buildSeatMatrix(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Controles flotantes de Zoom rápido (Resuelve problema explícito de usabilidad)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add, size: 20),
                                tooltip: 'Acercar zoom',
                                onPressed: _zoomIn,
                              ),
                              const Divider(height: 1, indent: 6, endIndent: 6),
                              IconButton(
                                icon: const Icon(Icons.remove, size: 20),
                                tooltip: 'Alejar zoom',
                                onPressed: _zoomOut,
                              ),
                              const Divider(height: 1, indent: 6, endIndent: 6),
                              IconButton(
                                icon: const Icon(Icons.fullscreen_rounded, size: 20),
                                tooltip: 'Ajustar sala completa',
                                onPressed: _zoomReset,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Barra inferior fija con resumen y CTA claro
                _buildBottomBar(isComplete, totalAmount),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScreenWidget() {
    return Column(
      children: [
        CustomPaint(
          size: const Size(280, 20),
          painter: _ScreenCurvePainter(),
        ),
        const SizedBox(height: 6),
        Text(
          'PANTALLA',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildSeatMatrix() {
    final rows = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    return Column(
      children: rows.map((rowLetter) {
        final rowSeats = _seats.where((s) => s.row == rowLetter).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Letra de fila izquierda
              SizedBox(
                width: 20,
                child: Text(
                  rowLetter,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),

              // Butacas de la fila
              ...rowSeats.map((seat) {
                // Pasillo en columna 4 y 8
                final isAisle = seat.number == 4 || seat.number == 8;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSeatTile(seat),
                    if (isAisle) const SizedBox(width: 16),
                  ],
                );
              }),

              const SizedBox(width: 8),
              // Letra de fila derecha
              SizedBox(
                width: 20,
                child: Text(
                  rowLetter,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeatTile(Seat seat) {
    final isSelected = _session.selectedSeats.contains(seat.id);

    Color bgColor;
    Color borderColor;
    Color textColor = AppColors.textPrimary;
    Widget? innerWidget;

    if (isSelected) {
      bgColor = AppColors.primary;
      borderColor = AppColors.primary;
      textColor = Colors.white;
      innerWidget = FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            seat.id,
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
      );
    } else if (seat.status == SeatStatus.occupied) {
      bgColor = Colors.grey[300]!;
      borderColor = Colors.grey[400]!;
      textColor = Colors.grey[500]!;
      innerWidget = FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            seat.id,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: textColor,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.grey[600],
            ),
          ),
        ),
      );
    } else if (seat.status == SeatStatus.wheelchair) {
      bgColor = AppColors.formatXd.withValues(alpha: 0.15);
      borderColor = AppColors.formatXd;
      textColor = AppColors.formatXd;
      innerWidget = FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            seat.id,
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      );
    } else {
      bgColor = Colors.white;
      borderColor = Colors.grey.shade300;
      textColor = AppColors.textPrimary;
      innerWidget = FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            seat.id,
            style: GoogleFonts.inter(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _onSeatTapped(seat),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: innerWidget,
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required Color borderColor,
    required String label,
    IconData? icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor, width: 1),
          ),
          alignment: Alignment.center,
          child: icon != null ? Icon(icon, size: 10, color: borderColor) : null,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isComplete, double totalAmount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => OrderSummaryBottomSheet.show(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Asientos Elegidos:',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.info_outline,
                                size: 12,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _session.selectedSeats.isEmpty
                                ? 'Ninguno aún'
                                : _session.selectedSeats.join(', '),
                            style: GoogleFonts.outfit(
                               fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Ver detalle tarifas',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'S/ ${totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[500],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: isComplete ? 2 : 0,
                ),
                onPressed: isComplete ? _onContinue : null,
                child: Text(
                  isComplete
                      ? 'CONTINUAR A CONFITERÍA'
                      : 'SELECCIONA TUS BUTACAS',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width / 2, 0, size.width, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
