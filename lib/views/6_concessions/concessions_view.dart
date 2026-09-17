import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../data/models/concession_model.dart';
import '../../data/models/purchase_session.dart';
import '../../core/widgets/order_summary_bottom_sheet.dart';
import '../../core/widgets/purchase_exit_dialog.dart';
import '../7_payment/payment_view.dart';

class ConcessionsView extends StatefulWidget {
  const ConcessionsView({super.key});

  @override
  State<ConcessionsView> createState() => _ConcessionsViewState();
}

class _ConcessionsViewState extends State<ConcessionsView> {
  final PurchaseSession _session = PurchaseSession();
  final TextEditingController _searchController = TextEditingController();

  late List<ConcessionItem> _allItems;
  String _selectedCategory = 'Combos Populares'; // Prioridad #1
  String _searchQuery = '';

  final List<String> _categories = [
    'Combos Populares',
    'Todos',
    'Canchita',
    'Bebidas',
    'Dulces & Snacks',
  ];

  @override
  void initState() {
    super.initState();
    TelemetryTracker().startStep('Concessions');
    _allItems = MockData.getConcessionItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ConcessionItem> get _filteredItems {
    return _allItems.where((item) {
      if (!item.isAvailable) return false;

      // Filtro de categoría
      final matchesCategory = _selectedCategory == 'Todos' ||
          item.category == _selectedCategory;

      // Filtro de búsqueda en vivo
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _onContinue() {
    TelemetryTracker().completeStep('Concessions');

    // Mostrar el Resumen de Compra Completo con el desglose exacto de cada entrada, butaca y snack
    OrderSummaryBottomSheet.show(
      context,
      continueButtonText: 'CONTINUAR AL PAGO',
      onContinueAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaymentView()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketTypes = MockData.getTicketTypes();

    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final ticketsTotal = _session.calculateTotalAmount(ticketTypes);
        final snacksTotal = _session.calculateConcessionsTotal(_allItems);
        final grandTotal = ticketsTotal + snacksTotal;
        final snacksCount = _session.totalConcessionItemsCount;

        return Scaffold(
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Snacks & Confitería',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Combos y bebidas para tu función',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            actions: [
              // Temporizador visible de la sesión
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
                onPressed: () async {
                  final shouldExit = await PurchaseExitDialog.show(context);
                  if (shouldExit && context.mounted) {
                    _session.resetSession();
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Buscador rápido de confitería (Resuelve observación de usabilidad)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar canchita, bebidas, combos...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Banner In-Flow Club Cinemark (Resuelve observación de acceso a membresía sin retroceder)
              _buildClubBanner(),

              // Filtro horizontal de categorías con chips
              Container(
                height: 48,
                color: Colors.white,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;

                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.grey[100],
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.grey[300]!,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = cat);
                      },
                    );
                  },
                ),
              ),

              const Divider(height: 1, thickness: 0.6),

              // Catálogo de productos filtrados
              Expanded(
                child: _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.fastfood_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No se encontraron productos con "$_searchQuery"',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        itemCount: _filteredItems.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildConcessionCard(_filteredItems[index]);
                        },
                      ),
              ),

              // Barra inferior fija con desglose y CTA claro
              _buildBottomBar(snacksCount, snacksTotal, grandTotal),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClubBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _session.isClubMember
              ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)]
              : [const Color(0xFF1F2937), const Color(0xFF374151)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _session.isClubMember
                      ? '¡Beneficio Club Cinemark Activo!'
                      : '¿Aún no eres socio Cinemark Club?',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _session.isClubMember
                      ? 'Precios con descuento especial aplicados en tus combos.'
                      : 'Activa gratis en 1 toque y ahorra hasta 20% en combos.',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _session.isClubMember,
            activeThumbColor: Colors.amber,
            onChanged: (val) {
              _session.setClubMember(val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    val
                      ? '¡Beneficios de socio Cinemark Club activados!'
                      : 'Membresía desactivada.',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConcessionCard(ConcessionItem item) {
    final qty = _session.concessionQuantities[item.id] ?? 0;
    final isClub = _session.isClubMember;
    final price = item.getDiscountedPrice(isClub);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qty > 0 ? AppColors.primary : Colors.grey[200]!,
          width: qty > 0 ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji / Icono visual de gran tamaño
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.iconEmoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(width: 12),

          // Título, descripción y badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.isPopular)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MÁS PEDIDO',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    if (item.savings != null && !isClub)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Ahorra S/ ${item.savings!.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Precio y selector de cantidad
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'S/ ${price.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isClub ? Colors.blue[800] : AppColors.primary,
                          ),
                        ),
                        if (isClub)
                          Text(
                            'Precio Club Cinemark',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[800],
                            ),
                          ),
                      ],
                    ),

                    // Contador interactivo [+] / [-]
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            onPressed: qty > 0
                                ? () => _session.updateConcessionQuantity(item.id, -1)
                                : null,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                              child: Text(
                                '$qty',
                                key: ValueKey<int>(qty),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: qty > 0 ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            onPressed: () => _session.updateConcessionQuantity(item.id, 1),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int snacksCount, double snacksTotal, double grandTotal) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => OrderSummaryBottomSheet.show(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  snacksCount > 0
                                      ? '$snacksCount ${snacksCount == 1 ? 'snack' : 'snacks'}'
                                      : 'Sin confitería',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.info_outline,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '• Ver detalle',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total: S/ ${grandTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Botón secundario rápido para omitir si no desea comida
                if (snacksCount == 0)
                  TextButton(
                    onPressed: _onContinue,
                    child: Text(
                      'Omitir Confitería',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                onPressed: _onContinue,
                child: Text(
                  snacksCount > 0
                      ? 'CONTINUAR AL PAGO (S/ ${grandTotal.toStringAsFixed(2)})'
                      : 'CONTINUAR SIN CONFITERÍA',
                  style: GoogleFonts.inter(
                    fontSize: 13,
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
