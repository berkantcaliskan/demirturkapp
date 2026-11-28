class CustomerFinance {
  CustomerFinance({
    required this.customerId,
    required this.asOf,
    required this.importedAt,
    required this.contracts,
  });
  final String customerId;
  final DateTime asOf;
  final DateTime importedAt;
  final List<Map<String, dynamic>> contracts;

  factory CustomerFinance.fromRow(Map<String, dynamic> row) {
    final snapshot = Map<String, dynamic>.from(row['snapshot'] as Map);
    if (snapshot['schemaVersion'] != 1 || snapshot['currency'] != 'TRY') {
      throw const FormatException('Ödeme bilgileri doğrulanamadı.');
    }
    final contracts = (snapshot['contracts'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    for (final contract in contracts) {
      for (final field in ['totalCents', 'paidCents', 'remainingCents']) {
        final amount = contract[field];
        if (amount is! int || amount < 0 || amount > 99999999999999) {
          throw const FormatException('Ödeme tutarı doğrulanamadı.');
        }
      }
      if (contract['totalCents'] !=
          contract['paidCents'] + contract['remainingCents']) {
        throw const FormatException('Ödeme bakiyesi doğrulanamadı.');
      }
    }
    return CustomerFinance(
      customerId: row['customer_id'] as String,
      asOf: DateTime.parse(snapshot['asOf'] as String),
      importedAt: DateTime.parse(row['imported_at'] as String),
      contracts: contracts,
    );
  }

  int _sum(String field) => contracts.fold(
    0,
    (total, contract) => total + ((contract[field] as num?)?.toInt() ?? 0),
  );
  double get total => _sum('totalCents') / 100;
  double get paid => _sum('paidCents') / 100;
  double get remaining => _sum('remainingCents') / 100;
  double get plannedDeposit => _sum('plannedDepositCents') / 100;
  double get plannedDownPayment => _sum('plannedDownPaymentCents') / 100;
  double get prepaid => _sum('prepaidCents') / 100;
  double get refunded => _sum('refundedCents') / 100;
  List<Map<String, dynamic>> get payments =>
      contracts
          .expand(
            (contract) => (contract['payments'] as List? ?? const []).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList()
        ..sort(
          (a, b) =>
              (b['paidDate'] as String).compareTo(a['paidDate'] as String),
        );
}
