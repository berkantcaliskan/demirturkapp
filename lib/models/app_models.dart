import 'package:flutter/cupertino.dart';

enum UserRole { customer, admin }

enum NoteStatus {
  paid,
  pending,
  overdue,
  verifying,
}

extension NoteStatusExtension on NoteStatus {
  String get label {
    switch (this) {
      case NoteStatus.paid:
        return 'Ödendi';
      case NoteStatus.pending:
        return 'Bekliyor';
      case NoteStatus.overdue:
        return 'Gecikmiş';
      case NoteStatus.verifying:
        return 'İnceleniyor';
    }
  }

  Color get color {
    switch (this) {
      case NoteStatus.paid:
        return const Color(0xFF30D158); // iOS System Green
      case NoteStatus.pending:
        return const Color(0xFF64D2FF); // iOS System Cyan/Blue
      case NoteStatus.overdue:
        return const Color(0xFFFF453A); // iOS System Red
      case NoteStatus.verifying:
        return const Color(0xFFFFD60A); // iOS System Yellow/Amber
    }
  }

  Color get bgColor {
    switch (this) {
      case NoteStatus.paid:
        return const Color(0xFF30D158).withValues(alpha: 0.20);
      case NoteStatus.pending:
        return const Color(0xFF0A84FF).withValues(alpha: 0.22);
      case NoteStatus.overdue:
        return const Color(0xFFFF453A).withValues(alpha: 0.22);
      case NoteStatus.verifying:
        return const Color(0xFFFF9F0A).withValues(alpha: 0.22);
    }
  }

  IconData get icon {
    switch (this) {
      case NoteStatus.paid:
        return CupertinoIcons.checkmark_alt_circle_fill;
      case NoteStatus.pending:
        return CupertinoIcons.clock_fill;
      case NoteStatus.overdue:
        return CupertinoIcons.exclamationmark_triangle_fill;
      case NoteStatus.verifying:
        return CupertinoIcons.timelapse;
    }
  }
}

class Customer {
  final String id;
  final String name;
  final String tcOrTaxNo;
  final String phone;
  final String email;
  final String address;
  final String contractNo;

  const Customer({
    required this.id,
    required this.name,
    required this.tcOrTaxNo,
    required this.phone,
    required this.email,
    required this.address,
    required this.contractNo,
  });
}

class PromissoryNote {
  final String id;
  final String customerId;
  final String senetNo;
  final int installmentIndex;
  final int totalInstallments;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidDate;
  final NoteStatus status;
  final String description;
  final String? receiptFileName;
  final String? receiptNote;
  final DateTime? submittedAt;
  final String? paymentMethod;
  final String? rejectionReason;

  const PromissoryNote({
    required this.id,
    required this.customerId,
    required this.senetNo,
    required this.installmentIndex,
    required this.totalInstallments,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    required this.status,
    required this.description,
    this.receiptFileName,
    this.receiptNote,
    this.submittedAt,
    this.paymentMethod,
    this.rejectionReason,
  });

  PromissoryNote copyWith({
    NoteStatus? status,
    DateTime? paidDate,
    String? receiptFileName,
    String? receiptNote,
    DateTime? submittedAt,
    String? paymentMethod,
    String? rejectionReason,
  }) {
    return PromissoryNote(
      id: id,
      customerId: customerId,
      senetNo: senetNo,
      installmentIndex: installmentIndex,
      totalInstallments: totalInstallments,
      amount: amount,
      dueDate: dueDate,
      paidDate: paidDate ?? this.paidDate,
      status: status ?? this.status,
      description: description,
      receiptFileName: receiptFileName ?? this.receiptFileName,
      receiptNote: receiptNote ?? this.receiptNote,
      submittedAt: submittedAt ?? this.submittedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      rejectionReason: rejectionReason,
    );
  }
}

class BankAccount {
  final String bankName;
  final String accountHolder;
  final String iban;
  final String branchName;
  final Color brandColor;

  const BankAccount({
    required this.bankName,
    required this.accountHolder,
    required this.iban,
    required this.branchName,
    required this.brandColor,
  });
}

class ChatMessage {
  final String id;
  final bool isFromAdmin;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final String? attachmentName;

  const ChatMessage({
    required this.id,
    required this.isFromAdmin,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.attachmentName,
  });
}

class SupportTicket {
  final String id;
  final String customerId;
  final String subject;
  final String category;
  final String? relatedSenetNo;
  final bool isResolved;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const SupportTicket({
    required this.id,
    required this.customerId,
    required this.subject,
    required this.category,
    this.relatedSenetNo,
    required this.isResolved,
    required this.updatedAt,
    required this.messages,
  });

  SupportTicket copyWith({
    bool? isResolved,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return SupportTicket(
      id: id,
      customerId: customerId,
      subject: subject,
      category: category,
      relatedSenetNo: relatedSenetNo,
      isResolved: isResolved ?? this.isResolved,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }
}

class AppNotification {
  final String id;
  final String customerId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String type; // 'overdue', 'approved', 'message', 'reminder'

  const AppNotification({
    required this.id,
    required this.customerId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    required this.type,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      customerId: customerId,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      type: type,
    );
  }
}

String formatCurrency(double amount) {
  final intPart = amount.truncate();
  final decPart = ((amount - intPart).abs() * 100).round();
  final str = intPart.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }
  return '${buffer.toString()},${decPart.toString().padLeft(2, '0')} ₺';
}

String formatDate(DateTime date) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}
