// ============================================================
// BANNER AD WIDGET — যেকোনো screen-এ reuse করা যাবে
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

class BannerAdWidget extends StatefulWidget {
  final String placementId; // analytics tag
  final AdSize adSize;
  final EdgeInsets padding;

  const BannerAdWidget({
    super.key,
    required this.placementId,
    this.adSize = AdSize.banner,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (_isLoading || _isLoaded) return;
    _isLoading = true;

    _bannerAd = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _isLoading = false;
          });
          debugPrint('✅ Banner loaded: ${widget.placementId}');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _isLoaded = false;
            _isLoading = false;
          });
          debugPrint('❌ Banner failed [${widget.placementId}]: $error');
        },
        onAdOpened: (ad) {
          debugPrint('📢 Banner opened: ${widget.placementId}');
        },
        onAdClosed: (ad) {
          debugPrint('📢 Banner closed: ${widget.placementId}');
        },
      ),
    );

    await _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      // Placeholder — layout jump কমায়
      return SizedBox(height: widget.adSize.height.toDouble());
    }

    return Padding(
      padding: widget.padding,
      child: Container(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
