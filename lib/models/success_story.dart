import 'package:cloud_firestore/cloud_firestore.dart';

class SuccessStory {
  final String id;
  final String coupleNames;
  final String husbandName;
  final String wifeName;
  final String story;
  final String photoUrl;
  final List<String> weddingPhotos;
  final String district;
  final DateTime? marriageDate;
  final bool isFeatured;
  final bool isApproved; // ✅ NEW
  final String submittedBy; // ✅ NEW — user UID
  final int order;
  final DateTime createdAt;

  SuccessStory({
    required this.id,
    required this.coupleNames,
    required this.husbandName,
    required this.wifeName,
    required this.story,
    required this.photoUrl,
    required this.weddingPhotos,
    required this.district,
    this.marriageDate,
    required this.isFeatured,
    required this.isApproved, // ✅
    required this.submittedBy, // ✅
    required this.order,
    required this.createdAt,
  });

  factory SuccessStory.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    String coupleNames = (data['coupleNames'] ?? '').toString();
    if (coupleNames.isEmpty) {
      final h = (data['husbandName'] ?? '').toString();
      final w = (data['wifeName'] ?? '').toString();
      coupleNames = '$h ❤️ $w';
    }

    final List<String> photos = [];
    if (data['weddingPhotos'] is List) {
      for (final p in (data['weddingPhotos'] as List)) {
        final s = p.toString().trim();
        if (s.isNotEmpty) photos.add(s);
      }
    }

    final cover = (data['photoUrl'] ?? '').toString().trim();
    if (photos.isEmpty && cover.isNotEmpty) {
      photos.add(cover);
    }

    return SuccessStory(
      id: doc.id,
      coupleNames: coupleNames,
      husbandName: (data['husbandName'] ?? '').toString(),
      wifeName: (data['wifeName'] ?? '').toString(),
      story: (data['story'] ?? '').toString(),
      photoUrl: cover,
      weddingPhotos: photos,
      district: (data['district'] ?? '').toString(),
      marriageDate: (data['marriageDate'] as Timestamp?)?.toDate(),
      isFeatured: data['isFeatured'] == true,
      isApproved: data['isApproved'] == true, // ✅
      submittedBy: (data['submittedBy'] ?? '').toString(), // ✅
      order: (data['order'] ?? 0) as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get primaryPhoto {
    if (weddingPhotos.isNotEmpty) return weddingPhotos.first;
    return photoUrl;
  }

  int get photoCount => weddingPhotos.length;
  bool get hasPhotos => weddingPhotos.isNotEmpty;

  String timeAgo(bool isBangla) {
    if (marriageDate == null) return '';
    final diff = DateTime.now().difference(marriageDate!);

    if (diff.inDays < 30) {
      return isBangla ? '${diff.inDays} দিন আগে' : '${diff.inDays}d ago';
    }
    if (diff.inDays < 365) {
      final months = diff.inDays ~/ 30;
      return isBangla ? '$months মাস আগে' : '${months}mo ago';
    }
    final years = diff.inDays ~/ 365;
    return isBangla ? '$years বছর আগে' : '${years}y ago';
  }
}
