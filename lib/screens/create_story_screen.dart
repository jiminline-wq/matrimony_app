import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../models/story.dart';
import '../services/story_service.dart';
import '../theme/colors.dart';

class CreateStoryScreen extends StatefulWidget {
  final bool isBangla;
  final String userName;
  final String userPhoto;

  const CreateStoryScreen({
    super.key,
    required this.isBangla,
    required this.userName,
    required this.userPhoto,
  });

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  // ✅ File এর বদলে XFile ব্যবহার করা হলো (যা ওয়েব ও মোবাইল উভয় জায়গায় কাজ করে)
  XFile? _pickedFile;
  StoryMediaType? _pickedType;
  int _videoDuration = 15;
  bool _posting = false;
  final _captionCtrl = TextEditingController();
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1080,
      );
      if (x == null) return;
      setState(() {
        _pickedFile = x;
        _pickedType = StoryMediaType.image;
      });
    } catch (e) {
      _snack(widget.isBangla ? 'ছবি নিতে সমস্যা: $e' : 'Image pick error: $e');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final x = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 15),
      );
      if (x == null) return;

      // ✅ ওয়েবে StoryService.getVideoDurationSeconds কাজ করবে না, তাই চেক দেওয়া হলো
      int dur = 15;
      if (!kIsWeb) {
        dur = await StoryService.getVideoDurationSeconds(File(x.path));
        if (dur > StoryService.maxDurationSeconds) {
          _snack(
            widget.isBangla
                ? 'ভিডিও $dur সেকেন্ড — সর্বোচ্চ ১৫ সেকেন্ড দরকার'
                : 'Video $dur s — max 15 s allowed',
          );
          return;
        }
      }

      setState(() {
        _pickedFile = x;
        _pickedType = StoryMediaType.video;
        _videoDuration = dur;
      });
    } catch (e) {
      _snack(
          widget.isBangla ? 'ভিডিও নিতে সমস্যা: $e' : 'Video pick error: $e');
    }
  }

  Future<void> _post() async {
    if (_pickedFile == null || _pickedType == null) return;

    // ✅ ওয়েবে StoryService আপাতত সাপোর্ট করবে না (File ছাড়া)
    if (kIsWeb) {
      _snack(widget.isBangla
          ? 'ওয়েবে স্টোরি আপলোড শীঘ্রই আসছে!'
          : 'Web story upload is coming soon!');
      return;
    }

    setState(() => _posting = true);
    try {
      await StoryService.createStory(
        file: File(_pickedFile!.path), // মোবাইলে File এ কনভার্ট করে পাঠানো হলো
        type: _pickedType!,
        userName: widget.userName,
        userPhoto: widget.userPhoto,
        caption:
            _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack(widget.isBangla ? 'Post fail: $e' : 'Post fail: $e');
      setState(() => _posting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    // ✅ মূল কন্টেন্ট
    Widget mainContent = Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          bn ? 'Story যোগ করুন' : 'Add Story',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_pickedFile != null)
            TextButton(
              onPressed: _posting ? null : _post,
              child: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      bn ? 'পোস্ট' : 'Post',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: _pickedFile == null ? _buildPicker(bn) : _buildPreview(bn),
    );

    // ✅ ওয়েবে ফোন-সিমুলেটর লুক দেওয়া হলো
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E1E), // ডার্ক গ্রে ব্যাকগ্রাউন্ড
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 850),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: mainContent,
            ),
          ),
        ),
      );
    }

    // মোবাইলে আগের মতোই ফুল স্ক্রিন
    return mainContent;
  }

  Widget _buildPicker(bool bn) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, color: Colors.white54, size: 72),
          const SizedBox(height: 16),
          Text(
            bn
                ? 'ছবি বা ভিডিও (সর্বোচ্চ ১৫ সেকেন্ড)'
                : 'Photo or video (max 15s)',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _pickBtn(
                icon: Icons.photo_library,
                label: bn ? 'গ্যালারি' : 'Gallery',
                onTap: () => _showSource(bn, isVideo: false),
              ),
              _pickBtn(
                icon: Icons.videocam,
                label: bn ? 'ভিডিও' : 'Video',
                onTap: () => _showSource(bn, isVideo: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pickBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [primaryGold, primaryMaroon]),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  void _showSource(bool bn, {required bool isVideo}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: Text(bn ? 'ক্যামেরা' : 'Camera',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                isVideo
                    ? _pickVideo(ImageSource.camera)
                    : _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.white),
              title: Text(bn ? 'গ্যালারি' : 'Gallery',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                isVideo
                    ? _pickVideo(ImageSource.gallery)
                    : _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(bool bn) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: _pickedType == StoryMediaType.image
                ? (kIsWeb
                    ? AppNetworkImage(_pickedFile!.path, fit: BoxFit.contain)
                    : Image.file(File(_pickedFile!.path), fit: BoxFit.contain))
                : _videoPreview(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: _posting
                    ? null
                    : () => setState(() {
                          _pickedFile = null;
                          _pickedType = null;
                        }),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(bn ? 'বদলান' : 'Change',
                    style: const TextStyle(color: Colors.white)),
              ),
              Expanded(
                child: TextField(
                  controller: _captionCtrl,
                  maxLength: 80,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: bn ? 'ক্যাপশন (অপশনাল)' : 'Caption (optional)',
                    hintStyle: const TextStyle(color: Colors.white54),
                    counterStyle: const TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _videoPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam, color: Colors.white54, size: 64),
        const SizedBox(height: 12),
        Text(
          widget.isBangla
              ? 'ভিডিও • $_videoDuration সেকেন্ড'
              : 'Video • $_videoDuration sec',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }
}
