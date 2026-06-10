import 'package:cloud_firestore/cloud_firestore.dart';
import 'victim_info.dart';

class VictimRepository {
  const VictimRepository();

  Future<VictimInfo> fetchBySenderId(String senderId) async {
    if (senderId.isEmpty) {
      return const VictimInfo(
        name: 'Unknown sender',
        phone: 'Unknown phone',
        email: 'No email provided',
        address: 'No address provided',
      );
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(senderId).get();
      final data = doc.data();
      if (data == null) {
        return const VictimInfo(
          name: 'Unknown sender',
          phone: 'Unknown phone',
          email: 'No email provided',
          address: 'No address provided',
        );
      }

      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['lastName'] ?? '').toString().trim();
      String name = [first, last].where((s) => s.isNotEmpty).join(' ').trim();
      if (name.isEmpty) {
        name = (data['displayName'] ?? data['fullName'] ?? 'User').toString();
      }

      final phone = (data['phoneNumber'] ?? data['contactNumber'] ?? 'Unknown phone').toString();
      final email = (data['email'] ?? 'No email provided').toString();

      String address = (data['fullAddress'] ?? '').toString();
      if (address.isEmpty) {
        final brgy = (data['brgy'] ?? '').toString();
        final city = (data['city'] ?? '').toString();
        address = [brgy, city].where((s) => s.isNotEmpty).join(', ');
      }
      if (address.isEmpty) address = 'No address provided';

      final photoUrl = (data['selfieUrl'] ?? data['selfieURL'] ?? '').toString();

      return VictimInfo(
        name: name,
        phone: phone,
        email: email,
        address: address,
        photoUrl: photoUrl.isEmpty ? null : photoUrl,
      );
    } catch (_) {
      return const VictimInfo(
        name: 'Unknown sender',
        phone: 'Unknown phone',
        email: 'No email provided',
        address: 'No address provided',
      );
    }
  }
}
