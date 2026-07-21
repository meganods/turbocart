
class PartnerModel {
  final String uid;
  final String name;
  final String phone;
  final String photoUrl;
  final String vehicleType;
  final bool isOnline;

  PartnerModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.photoUrl,
    required this.vehicleType,
    required this.isOnline,
  });

  factory PartnerModel.fromMap(String uid, Map<String, dynamic> data) {
    return PartnerModel(
      uid: uid,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      vehicleType: data['vehicleType'] ?? 'Bicycle',
      isOnline: data['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'vehicleType': vehicleType,
      'isOnline': isOnline,
    };
  }
}
