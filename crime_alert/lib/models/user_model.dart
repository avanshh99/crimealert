class UserModel {
  String uid;
  String firstName;
  String lastName;
  String email;
  String? mobileNo;
  String? address;
  String? zipcode;
  String? imageURL;
  String? country;
  String? state;
  String? city;
  String? sosMessage;

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.mobileNo = "",
    this.address = "",
    this.zipcode = "",
    this.imageURL,
    this.country,
    this.state,
    this.city,
    this.sosMessage,
  });

  // Add this copyWith method
  UserModel copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    String? mobileNo,
    String? address,
    String? zipcode,
    String? imageURL,
    String? country,
    String? state,
    String? city,
    String? sosMessage,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      mobileNo: mobileNo ?? this.mobileNo,
      address: address ?? this.address,
      zipcode: zipcode ?? this.zipcode,
      imageURL: imageURL ?? this.imageURL,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      sosMessage: sosMessage ?? this.sosMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'mobileNo': mobileNo,
      'address': address,
      'zipcode': zipcode,
      'imageURL': imageURL,
      'country': country,
      'state': state,
      'city': city,
      'sosMessage': sosMessage,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? "",
      firstName: map['firstName'] ?? "Unknown User",
      lastName: map['lastName'] ?? "Unknown User",
      email: map['email'] ?? "no-email@example.com",
      mobileNo: map['mobileNo'] ?? "",
      address: map['address'] ?? "",
      zipcode: map['zipcode'] ?? "",
      imageURL: map['imageURL'],
      country: map['country'],
      state: map['state'],
      city: map['city'],
      sosMessage: map['sosMessage'],
    );
  }
}