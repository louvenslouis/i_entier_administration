enum PharmacyAdminStatus { pending, active, suspended, rejected }

extension PharmacyAdminStatusText on PharmacyAdminStatus {
  String get storageValue => name;

  String get label => switch (this) {
    PharmacyAdminStatus.pending => 'En attente',
    PharmacyAdminStatus.active => 'Active',
    PharmacyAdminStatus.suspended => 'Suspendue',
    PharmacyAdminStatus.rejected => 'Refusée',
  };

  static PharmacyAdminStatus fromStorage(Object? value) =>
      PharmacyAdminStatus.values.firstWhere(
        (status) => status.name == value?.toString(),
        orElse: () => PharmacyAdminStatus.pending,
      );
}

class PharmacyAdminRecord {
  final String id;
  final String name;
  final String legalName;
  final String licenseNumber;
  final DateTime? licenseExpiresOn;
  final String responsiblePharmacist;
  final String phone;
  final String email;
  final String address;
  final PharmacyAdminStatus status;
  final bool publicEnabled;
  final String regulationNote;
  final bool licenseExpired;
  final int productCount;
  final int lowStockCount;
  final int openOrderCount;
  final double monthSalesTotal;
  final DateTime? createdAt;

  const PharmacyAdminRecord({
    required this.id,
    required this.name,
    required this.legalName,
    required this.licenseNumber,
    required this.licenseExpiresOn,
    required this.responsiblePharmacist,
    required this.phone,
    required this.email,
    required this.address,
    required this.status,
    required this.publicEnabled,
    required this.regulationNote,
    required this.licenseExpired,
    required this.productCount,
    required this.lowStockCount,
    required this.openOrderCount,
    required this.monthSalesTotal,
    required this.createdAt,
  });

  factory PharmacyAdminRecord.fromRow(Map<String, dynamic> row) {
    String text(String key) => row[key]?.toString().trim() ?? '';
    int integer(String key) => row[key] is num
        ? (row[key] as num).toInt()
        : int.tryParse(text(key)) ?? 0;
    double number(String key) => row[key] is num
        ? (row[key] as num).toDouble()
        : double.tryParse(text(key)) ?? 0;
    DateTime? date(String key) => DateTime.tryParse(text(key))?.toLocal();

    return PharmacyAdminRecord(
      id: text('pharmacy_id'),
      name: text('display_name'),
      legalName: text('legal_name'),
      licenseNumber: text('license_number'),
      licenseExpiresOn: date('license_expires_on'),
      responsiblePharmacist: text('responsible_pharmacist'),
      phone: text('phone'),
      email: text('email'),
      address: text('address'),
      status: PharmacyAdminStatusText.fromStorage(row['operational_status']),
      publicEnabled: row['public_enabled'] == true,
      regulationNote: text('regulation_note'),
      licenseExpired: row['license_expired'] == true,
      productCount: integer('product_count'),
      lowStockCount: integer('low_stock_count'),
      openOrderCount: integer('open_order_count'),
      monthSalesTotal: number('month_sales_total'),
      createdAt: date('created_at'),
    );
  }
}
