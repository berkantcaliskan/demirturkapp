import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../widgets/website_blurred_background.dart';
import 'iban_and_statement_sheets.dart';

class CustomerNotesScreen extends StatefulWidget {
  final AppState appState;

  const CustomerNotesScreen({
    super.key,
    required this.appState,
  });

  @override
  State<CustomerNotesScreen> createState() => _CustomerNotesScreenState();
}

class _CustomerNotesScreenState extends State<CustomerNotesScreen> {
  NoteStatus? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final allNotes = widget.appState.customerNotes;
    final filteredNotes = _selectedFilter == null
        ? allNotes
        : allNotes.where((n) => n.status == _selectedFilter).toList();
    final isDark = AppGlass.isDark(context);

    return Column(
      children: [
        // iOS Frosted Glass Filter Bar
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF090D14).withValues(alpha: 0.36)
                    : Colors.white.withValues(alpha: 0.12),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.24),
                    width: 0.6,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Tümü (${allNotes.length})',
                      isSelected: _selectedFilter == null,
                      isDark: isDark,
                      onTap: () => setState(() => _selectedFilter = null),
                    ),
                    const SizedBox(width: 8),
                    ...NoteStatus.values.map((status) {
                      final count =
                          allNotes.where((n) => n.status == status).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          label: '${status.label} ($count)',
                          isSelected: _selectedFilter == status,
                          color: status.color,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedFilter = status),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),

        // List of Promissory Notes
        Expanded(
          child: filteredNotes.isEmpty
              ? Center(
                  child: GlassCard(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.doc_text_search,
                          size: 46,
                          color: AppGlass.textMuted(context),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Bu filtreye uygun senet bulunamadı.',
                          style: TextStyle(
                            color: AppGlass.textSecondary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];
                    return _buildNoteCard(context, note);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    Color? color,
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? const Color(0xFF0F172A);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.7,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0xFF0F172A).withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0xFF0F172A).withValues(alpha: 0.10)),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            letterSpacing: -0.2,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? Colors.white.withValues(alpha: 0.82)
                    : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, PromissoryNote note) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 22,
      tone: note.status == NoteStatus.overdue
          ? GlassCardTone.urgentRed
          : GlassCardTone.standard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppGlass.subtleSurface(context),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: AppGlass.dividerColor(context),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  '${note.installmentIndex} / ${note.totalInstallments}. SENET',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppGlass.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.senetNo,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppGlass.textPrimary(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: note.status.bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: note.status.color.withValues(alpha: 0.50),
                    width: 0.7,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      note.status.icon,
                      size: 13.5,
                      color: note.status.color,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      note.status.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: note.status.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note.description,
            style: TextStyle(
              fontSize: 13,
              color: AppGlass.textSecondary(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppGlass.dividerColor(context)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vade Tarihi',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppGlass.textMuted(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(note.dueDate),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppGlass.textPrimary(context),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Senet Tutarı',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppGlass.textMuted(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatCurrency(note.amount),
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppGlass.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (note.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF453A).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF453A).withValues(alpha: 0.45),
                  width: 0.7,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_circle_fill,
                    size: 16,
                    color: Color(0xFFE11D48),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Red Açıklaması: ${note.rejectionReason}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppGlass.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (note.status == NoteStatus.verifying &&
              note.receiptFileName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9F0A).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                  width: 0.7,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.doc_text_fill,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yüklenen Dekont: ${note.receiptFileName} (${note.paymentMethod ?? ""})',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppGlass.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          if (note.status == NoteStatus.paid)
            Row(
              children: [
                const Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  size: 16,
                  color: Color(0xFF30D158),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ödeme: ${note.paidDate != null ? formatShortDate(note.paidDate!) : "-"} • ${note.paymentMethod ?? "Tahsil Edildi"}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF30D158),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: IosGlassButton(
                    isSecondaryGlass: true,
                    icon: CupertinoIcons.building_2_fill,
                    label: 'IBAN ile Öde',
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(
                          text:
                              '${note.senetNo} - ${widget.appState.currentCustomer.name}',
                        ),
                      );
                      showIbanSheet(context, widget.appState);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: IosGlassButton(
                    isDestructive: note.status == NoteStatus.overdue,
                    icon: CupertinoIcons.arrow_up_doc_fill,
                    label: note.status == NoteStatus.verifying
                        ? 'Dekont Güncelle'
                        : 'Dekont Yükle',
                    onTap: () => showUploadReceiptSheet(
                      context,
                      widget.appState,
                      preselectedNote: note,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
