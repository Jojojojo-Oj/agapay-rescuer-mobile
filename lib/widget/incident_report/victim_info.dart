import 'package:equatable/equatable.dart';

class VictimInfo extends Equatable {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String? photoUrl;

  const VictimInfo({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [name, phone, email, address, photoUrl];
}
