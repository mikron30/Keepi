import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class KeepiAdMobBanner extends StatefulWidget {
  const KeepiAdMobBanner({super.key});

  @override
  State<KeepiAdMobBanner> createState() => _KeepiAdMobBannerState();
}

class _KeepiAdMobBannerState extends State<KeepiAdMobBanner> {
  static const _androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _iosTestBannerId =
      'ca-app-pub-3940256099942544/2934735716';

  static const _androidProductionBannerId =
      String.fromEnvironment(
        'ADMOB_ANDROID_BANNER_ID',
        defaultValue: 'ca-app-pub-6120568543364688/1935114293',
      );
  static const _iosProductionBannerId =
      String.fromEnvironment(
        'ADMOB_IOS_BANNER_ID',
        defaultValue: 'ca-app-pub-6120568543364688/5595157700',
      );

  BannerAd? _bannerAd;
  bool _loaded = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _adUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidProductionBannerId.isNotEmpty
          ? _androidProductionBannerId
          : _androidTestBannerId;
    }

    return _iosProductionBannerId.isNotEmpty
        ? _iosProductionBannerId
        : _iosTestBannerId;
  }

  @override
  void initState() {
    super.initState();

    if (_supported) {
      _initializeAndLoadBanner();
    }
  }

  Future<void> _initializeAndLoadBanner() async {
    try {
      final params = ConsentRequestParameters();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          ConsentForm.loadAndShowConsentFormIfRequired(
            (formError) async {
              if (formError != null) {
                debugPrint(
                  'Keepi consent form failed: '
                  '${formError.errorCode}: ${formError.message}',
                );
              }

              final canRequestAds =
                  await ConsentInformation.instance.canRequestAds();

              if (!mounted || !canRequestAds) {
                return;
              }

              await MobileAds.instance.initialize();
              if (mounted) {
                _loadBanner();
              }
            },
          );
        },
        (formError) async {
          debugPrint(
            'Keepi consent update failed: '
            '${formError.errorCode}: ${formError.message}',
          );

          // A previous valid consent state may still permit ads.
          final canRequestAds =
              await ConsentInformation.instance.canRequestAds();
          if (!mounted || !canRequestAds) {
            return;
          }

          await MobileAds.instance.initialize();
          if (mounted) {
            _loadBanner();
          }
        },
      );
    } catch (error) {
      debugPrint('Keepi AdMob initialization failed: $error');
      // Advertising must never prevent Keepi itself from starting.
    }
  }

  void _loadBanner() {
    final ad = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _bannerAd = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Keepi AdMob banner failed to load: $error');
          ad.dispose();

          if (mounted) {
            setState(() {
              _bannerAd = null;
              _loaded = false;
            });
          }
        },
      ),
    );

    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;

    if (!_supported || !_loaded || ad == null) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          height: ad.size.height.toDouble(),
          child: Center(
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        ),
      ),
    );
  }
}
