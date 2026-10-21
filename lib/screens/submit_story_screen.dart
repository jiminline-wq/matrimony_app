import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // ✅ Uint8List এর জন্য

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য

import '../theme/colors.dart';
import '../services/success_story_service.dart';
import '../utils/bd_districts.dart';

// ============================================================
// SUBMIT SUCCESS STORY — User facing form
// ============================================================

class SubmitStoryScreen extends StatefulWidget {
  final bool isBangla;

  const SubmitStoryScreen({super.key, required this.isBangla});

  @override
  State<SubmitStoryScreen> createState() => _SubmitStoryScreenState();
}

class _SubmitStoryScreenState extends State<SubmitStoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _coupleCtrl = TextEditingController();
  final _husbandCtrl = TextEditingController();
  final _wifeCtrl = TextEditingController();
  final _storyCtrl = TextEditingController();

  String? _selectedDistrict;
  DateTime? _marriageDate;
  final List<String> _photoUrls = [];
  bool _isUploading = false;
  bool _isSubmitting = false;

  static const String _cloudName = 'acctuglm';
  static const String _uploadPreset = 'jibon_sathi_chat';

  @override
  void dispose() {
    _coupleCtrl.dispose();
    _husbandCtrl.dispose();
    _wifeCtrl.dispose();
    _storyCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // PICK + UPLOAD PHOTOS
  // ============================================================
  Future<void> _pickPhotos() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(
        imageQuality: 75,
        maxWidth: 1600,
      );
      if (picked.isEmpty) return;

      setState(() => _isUploading = true);

      for (final file in picked) {
        // ✅ XFile থেকে বাইটস রিড করা হচ্ছে (ওয়েব ও মোবাইল সাপোর্টের জন্য)
        final bytes = await file.readAsBytes();
        final url = await _uploadToCloudinary(bytes, file.name);
        if (url != null) {
          _photoUrls.add(url);
        }
      }
    } catch (e) {
      debugPrint('❌ Pick photos failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ✅ ফাংশনটি মডিফাই করা হলো যাতে বাইটস দিয়ে আপলোড হয়
  Future<String?> _uploadToCloudinary(Uint8List bytes, String fileName) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );
      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset;

      // ✅ fromPath এর বদলে fromBytes ব্যবহার করা হলো
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      final res = await req.send();
      final responseBytes = await res.stream.toBytes();
      final json = jsonDecode(String.fromCharCodes(responseBytes));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return json['secure_url'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      return null;
    }
  }

  void _removePhoto(int i) {
    setState(() => _photoUrls.removeAt(i));
  }

  // ============================================================
  // SUBMIT
  // ============================================================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoUrls.isEmpty) {
      _showSnack(
        widget.isBangla
            ? 'কমপক্ষে একটা বিয়ের ছবি যোগ করুন'
            : 'Add at least one wedding photo',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await SuccessStoryService.submitStory(
        coupleNames: _coupleCtrl.text.trim(),
        husbandName: _husbandCtrl.text.trim(),
        wifeName: _wifeCtrl.text.trim(),
        story: _storyCtrl.text.trim(),
        photoUrls: _photoUrls,
        district: _selectedDistrict ?? '',
        marriageDate: _marriageDate,
      );

      if (!mounted) return;

      if (result != null) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isBangla ? 'সফলভাবে জমা হয়েছে!' : 'Submitted!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deepMaroon,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isBangla
                      ? 'Admin approve করার পর আপনার গল্প home page-এ দেখা যাবে।'
                      : 'Your story will appear on home page after admin approval.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: secondaryText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(
                  widget.isBangla ? 'ঠিক আছে' : 'OK',
                  style: const TextStyle(color: primaryMaroon),
                ),
              ),
            ],
          ),
        );
      } else {
        _showSnack(widget.isBangla ? 'জমা দেওয়া যায়নি' : 'Submission failed');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: primaryMaroon,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return Scaffold(
      backgroundColor: warmWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryMaroon),
        title: Text(
          bn ? 'আপনার সফলতার গল্প' : 'Your Success Story',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          // ✅ মূল ফর্ম
          Widget formContent = Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B1E3F), Color(0xFF5E1128)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: primaryGold,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bn
                                  ? 'আপনার গল্প শেয়ার করুন'
                                  : 'Share Your Story',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              bn
                                  ? 'অন্যরাও অনুপ্রাণিত হবেন আপনার গল্পে'
                                  : 'Inspire others with your journey',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildPhotoSection(bn),
                const SizedBox(height: 16),
                _buildField(
                  _coupleCtrl,
                  bn ? 'দম্পতির নাম *' : 'Couple Names *',
                  hint: 'রাকিব ❤️ সাদিয়া',
                  validator: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        _husbandCtrl,
                        bn ? 'বরের নাম' : 'Husband',
                        hint: 'রাকিব',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        _wifeCtrl,
                        bn ? 'কনের নাম' : 'Wife',
                        hint: 'সাদিয়া',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickDistrict,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryMaroon.withValues(alpha: 0.2),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_city,
                          color: primaryMaroon,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedDistrict ??
                                (bn ? 'জেলা নির্বাচন' : 'Select district'),
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedDistrict != null
                                  ? mainText
                                  : secondaryText,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down,
                            color: primaryMaroon),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryMaroon.withValues(alpha: 0.2),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: primaryMaroon,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _marriageDate != null
                                ? '${_marriageDate!.day}/${_marriageDate!.month}/${_marriageDate!.year}'
                                : (bn ? 'বিয়ের তারিখ' : 'Marriage date'),
                            style: TextStyle(
                              fontSize: 14,
                              color: _marriageDate != null
                                  ? mainText
                                  : secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _storyCtrl,
                  maxLines: 6,
                  validator: (v) => (v == null || v.trim().length < 20)
                      ? (bn
                          ? 'কমপক্ষে ২০ অক্ষর লিখুন'
                          : 'At least 20 characters')
                      : null,
                  decoration: InputDecoration(
                    labelText: bn ? 'তাদের গল্প *' : 'Their Story *',
                    hintText: bn
                        ? 'কিভাবে একে অপরকে খুঁজে পেয়েছেন...'
                        : 'How they found each other...',
                    hintStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: primaryMaroon,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || _isUploading) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryMaroon,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                bn ? 'গল্প জমা দিন' : 'Submit Story',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );

          // ✅ ওয়েবে ফর্মটি সুন্দর দেখানোর জন্য সেন্টার করা হলো
          if (isDesktop) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: formContent,
                  ),
                ),
              ),
            );
          }

          return formContent;
        },
      ),
    );
  }

  Widget _buildPhotoSection(bool bn) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryMaroon.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library, color: primaryMaroon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bn
                      ? 'বিয়ের ছবি (${_photoUrls.length}) *'
                      : 'Wedding Photos (${_photoUrls.length}) *',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: deepMaroon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            bn
                ? 'কমপক্ষে ১টা ছবি দিন (প্রথমটা cover হবে)'
                : 'At least 1 photo (first is cover)',
            style: const TextStyle(fontSize: 11, color: secondaryText),
          ),
          const SizedBox(height: 12),
          if (_photoUrls.isEmpty)
            GestureDetector(
              onTap: _isUploading ? null : _pickPhotos,
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: primaryMaroon.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryMaroon.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: _isUploading
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryMaroon),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            color: primaryMaroon,
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ছবি যোগ করতে ট্যাপ করুন',
                            style: TextStyle(
                              fontSize: 13,
                              color: primaryMaroon,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _photoUrls.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, i) {
                if (i == _photoUrls.length) {
                  return GestureDetector(
                    onTap: _isUploading ? null : _pickPhotos,
                    child: Container(
                      decoration: BoxDecoration(
                        color: primaryMaroon.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: primaryMaroon.withValues(alpha: 0.3),
                        ),
                      ),
                      child: _isUploading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: primaryMaroon,
                                strokeWidth: 2,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, color: primaryMaroon, size: 28),
                                SizedBox(height: 4),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: primaryMaroon,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: _photoUrls[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (_, __) => Container(color: lightMaroon),
                        errorWidget: (_, __, ___) => Container(
                          color: lightMaroon,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    if (i == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryMaroon,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Cover',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool validator = false,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: validator
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryMaroon, width: 1.6),
        ),
      ),
    );
  }

  Future<void> _pickDistrict() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Material(
          color: warmWhite,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.builder(
            controller: ctrl,
            itemCount: bdDistricts.length,
            itemBuilder: (_, i) => Material(
              color: Colors.transparent,
              child: ListTile(
                title: Text(bdDistricts[i]),
                onTap: () => Navigator.pop(context, bdDistricts[i]),
              ),
            ),
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _selectedDistrict = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _marriageDate = picked);
  }
}
