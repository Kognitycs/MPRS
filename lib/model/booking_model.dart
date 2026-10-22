class BookingResponse {
  final bool success;
  final List<Booking> data;
  final String? message;

  BookingResponse({required this.success, required this.data, this.message});

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    return BookingResponse(
      success: json['success'] ?? false,
      data:
          json['data'] != null
              ? (json['data'] as List).map((e) => Booking.fromJson(e)).toList()
              : [],
      message: json['message'],
    );
  }
}

class Booking {
  final String? id;
  final String? bookingId;
  final String? accountId;
  final String? trackingId;
  final String? origin;
  final String? destination;
  final String? status;
  final String? containerNumber;
  final String? vesselName;
  final String? etd;
  final String? eta;
  final String? bookingDate;
  final String? createdAt;
  final String? updatedAt;

  Booking({
    this.id,
    this.bookingId,
    this.accountId,
    this.trackingId,
    this.origin,
    this.destination,
    this.status,
    this.containerNumber,
    this.vesselName,
    this.etd,
    this.eta,
    this.bookingDate,
    this.createdAt,
    this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['_id'],
      bookingId: json['bookingId'],
      accountId: json['accountId'],
      trackingId: json['trackingId'],
      origin: json['origin'],
      destination: json['destination'],
      status: json['status'],
      containerNumber: json['containerNumber'],
      vesselName: json['vesselName'],
      etd: json['etd'],
      eta: json['eta'],
      bookingDate: json['bookingDate'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'bookingId': bookingId,
      'accountId': accountId,
      'trackingId': trackingId,
      'origin': origin,
      'destination': destination,
      'status': status,
      'containerNumber': containerNumber,
      'vesselName': vesselName,
      'etd': etd,
      'eta': eta,
      'bookingDate': bookingDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
