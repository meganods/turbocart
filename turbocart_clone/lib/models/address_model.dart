class AddressModel {
  final String id;
  final String flat;
  final String area;
  final String landmark;
  final String label;
  final String city;
  final double lat;
  final double lng;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.flat,
    required this.area,
    required this.landmark,
    required this.label,
    required this.city,
    required this.lat,
    required this.lng,
    required this.isDefault,
  });

  factory AddressModel.fromMap(String id, Map<String, dynamic> map) {
    return AddressModel(
      id: id,
      flat: map['flat'] ?? '',
      area: map['area'] ?? '',
      landmark: map['landmark'] ?? '',
      label: map['label'] ?? 'Home',
      city: map['city'] ?? '',
      lat: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      lng: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      isDefault: map['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flat': flat,
      'area': area,
      'landmark': landmark,
      'label': label,
      'city': city,
      'latitude': lat,
      'longitude': lng,
      'isDefault': isDefault,
    };
  }
}
