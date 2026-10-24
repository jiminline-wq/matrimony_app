import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:matrimony_app/widgets/app_network_image.dart';
import '../theme/colors.dart';
import '../models/success_story.dart';

// ============================================================
// STORY DETAILS SCREEN — Wedding photo gallery
// ============================================================

class StoryDetailsScreen extends StatefulWidget {
  final SuccessStory story;
  final bool isBangla;

  const StoryDetailsScreen({
    super.key,
    required this.story,
    required this.isBangla,
  });

  @override
  State<StoryDetailsScreen> createState() => _StoryDetailsScreenState();
}

class _StoryDetailsScreenState extends State<StoryDetailsScreen> {
  int _photoIndex = 0;
  final PageController _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD (Responsive Layout Switcher)
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
          bn ? 'সফলতার গল্প' : 'Success Story',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          if (isDesktop) {
            return _buildWebLayout(bn);
          } else {
            return _buildMobileLayout(bn);
          }
        },
      ),
    );
  }

  // ============================================================
  // 📱 ১. মোবাইল লেআউট (হুবহু অক্ষত)
  // ============================================================
  Widget _buildMobileLayout(bool bn) {
    final story = widget.story;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo gallery
          if (story.hasPhotos)
            _buildPhotoGallery(story, isDesktop: false)
          else
            _buildNoPhotosPlaceholder(),

          // Couple info
          _buildCoupleInfo(story, bn),

          // Story text
          _buildStoryText(story, bn),

          // Footer
          _buildFooter(bn),
        ],
      ),
    );
  }

  // ============================================================
  // 💻 ২. ওয়েব লেআউট (নতুন প্রিমিয়াম টু-কলাম ডিজাইন)
  // ============================================================
  Widget _buildWebLayout(bool bn) {
    final story = widget.story;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔴 বাম কলাম (Photo Gallery)
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    if (story.hasPhotos)
                      _buildPhotoGallery(story, isDesktop: true)
                    else
                      _buildNoPhotosPlaceholder(),
                  ],
                ),
              ),

              const SizedBox(width: 30),

              // 🟢 ডান কলাম (Info, Story, Footer)
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoupleInfo(story, bn, isDesktop: true),
                    _buildStoryText(story, bn, isDesktop: true),
                    _buildFooter(bn, isDesktop: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // REUSABLE WIDGETS
  // ============================================================

  Widget _buildPhotoGallery(SuccessStory story, {required bool isDesktop}) {
    final photos = story.weddingPhotos;
    // ওয়েবে ছবির সাইজ একটু বড় করা হলো
    final galleryHeight = isDesktop ? 500.0 : 320.0;

    return Column(
      children: [
        Container(
          height: galleryHeight,
          margin: isDesktop
              ? const EdgeInsets.only(left: 16, right: 0)
              : EdgeInsets.zero,
          decoration: isDesktop
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                )
              : null,
          child: ClipRRect(
            borderRadius:
                isDesktop ? BorderRadius.circular(20) : BorderRadius.zero,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) {
                    setState(() => _photoIndex = i);
                  },
                  itemCount: photos.length,
                  itemBuilder: (_, i) => AppNetworkImage(
                    photos[i],
                    fit: BoxFit.cover, // ওয়েবে কভার করা ভালো দেখায়
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: primaryMaroon),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                ),
                if (photos.length > 1)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_photoIndex + 1} / ${photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (photos.length > 1)
          Container(
            padding: EdgeInsets.symmetric(
                vertical: 10, horizontal: isDesktop ? 16 : 0),
            height: 78,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: isDesktop ? 0 : 16),
              itemCount: photos.length,
              itemBuilder: (_, i) {
                final isActive = i == _photoIndex;
                return GestureDetector(
                  onTap: () {
                    _pageCtrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? primaryMaroon : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppNetworkImage(
                        photos[i],
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: lightMaroon),
                        errorWidget: (_, __, ___) => Container(
                          color: lightMaroon,
                          child: const Icon(
                            Icons.broken_image,
                            color: primaryMaroon,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNoPhotosPlaceholder() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryMaroon.withValues(alpha: 0.1),
            primaryGold.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(Icons.favorite, color: primaryMaroon, size: 60),
      ),
    );
  }

  Widget _buildCoupleInfo(SuccessStory story, bool bn,
      {bool isDesktop = false}) {
    return Container(
      margin: isDesktop
          ? const EdgeInsets.only(bottom: 16)
          : const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryMaroon.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: primaryMaroon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  story.coupleNames,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deepMaroon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (story.district.isNotEmpty)
                _buildMetaChip(Icons.location_on, story.district),
              if (story.marriageDate != null)
                _buildMetaChip(
                  Icons.calendar_today,
                  '${story.marriageDate!.day}/${story.marriageDate!.month}/${story.marriageDate!.year}',
                ),
              _buildMetaChip(
                Icons.verified,
                bn ? 'ভেরিফাইড' : 'Verified',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoryText(SuccessStory story, bool bn,
      {bool isDesktop = false}) {
    return Container(
      margin: isDesktop
          ? const EdgeInsets.only(bottom: 16)
          : const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryMaroon.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: primaryMaroon,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bn ? 'তাদের গল্প' : 'Their Story',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: deepMaroon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            story.story,
            style: const TextStyle(
              fontSize: 14,
              color: mainText,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool bn, {bool isDesktop = false}) {
    return Container(
      margin: isDesktop
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 0, 16, 30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryMaroon.withValues(alpha: 0.08),
            primaryGold.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryMaroon.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration, color: primaryMaroon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bn
                  ? 'তাদের নতুন জীবনের জন্য শুভকামনা ❤️'
                  : 'Wishing them a happy married life ❤️',
              style: const TextStyle(
                fontSize: 12.5,
                color: deepMaroon,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primaryMaroon.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primaryMaroon, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: primaryMaroon,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
