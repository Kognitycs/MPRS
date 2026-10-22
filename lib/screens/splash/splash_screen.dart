import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/screens/auth/login_mobile_screen.dart';
import 'package:mprs_android/screens/auth/login_with_mpin_screen.dart';
import 'package:mprs_android/screens/auth/new_mpin_screen.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _splashVideo = 'assets/videos/App_Video.mp4';

  /// Fallback for portrait splash when the decoder has not reported size yet.
  static const _fallbackVideoW = 1080.0;
  static const _fallbackVideoH = 1920.0;

  late VideoPlayerController _controller;
  Timer? _initTimeout;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    _controller =
        VideoPlayerController.asset(_splashVideo)
          ..setLooping(false)
          ..setVolume(1.0)
          ..initialize()
              .then((_) {
                if (!mounted) return;
                _initTimeout?.cancel();
                final size = _controller.value.size;
                debugPrint(
                  '🎬 Splash initialized: ${size.width}x${size.height} '
                  'aspect=${_videoAspectRatio.toStringAsFixed(3)}',
                );
                setState(() {});
                _controller.play();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _controller.addListener(_videoListener);
                });
              })
              .catchError((Object e) {
                debugPrint('⚠️ Splash init error: $e');
                _checkLogin();
              });

    _initTimeout = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (!_controller.value.isInitialized) {
        debugPrint('⚠️ Splash timed out — skipping video');
        _checkLogin();
      }
    });
  }

  double get _videoAspectRatio {
    final w = _controller.value.size.width;
    final h = _controller.value.size.height;
    if (w > 0 && h > 0) return w / h;
    return _fallbackVideoW / _fallbackVideoH;
  }

  Size get _videoSourceSize {
    final w = _controller.value.size.width;
    final h = _controller.value.size.height;
    if (w > 0 && h > 0) return Size(w, h);
    return const Size(_fallbackVideoW, _fallbackVideoH);
  }

  void _videoListener() {
    final dur = _controller.value.duration;
    final pos = _controller.value.position;
    if (dur.inMilliseconds <= 0) return;
    if (pos >= dur && !_controller.value.isPlaying) {
      debugPrint('🎬 Splash ended');
      _checkLogin();
    }
  }

  void _checkLogin() {
    if (!mounted) return;
    try {
      _controller.removeListener(_videoListener);
      _controller.dispose();
    } catch (_) {}

    final isUserLogin = AuthDataHelper.isUserLoggedIn();
    final mPin = AuthDataHelper.getMPin();
    if (!isUserLogin) {
      _goTo(const LoginMobileScreen());
    } else if (mPin.isEmpty) {
      _goTo(const NewMpinScreen());
    } else {
      _goTo(const LoginWithMpinScreen());
    }
  }

  void _goTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Full-frame splash video scaled with [BoxFit.contain] so the entire
  /// illustration stays inside the phone frame (no zoom/crop).
  Widget _buildVideoPlayer(BoxConstraints constraints) {
    final source = _videoSourceSize;

    return ColoredBox(
      color: AppColors.white,
      child: Center(
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.contain,
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            child: SizedBox(
              width: source.width,
              height: source.height,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _initTimeout?.cancel();
    try {
      _controller.removeListener(_videoListener);
      _controller.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (!_controller.value.isInitialized) {
            return const ColoredBox(
              color: AppColors.white,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildVideoPlayer(constraints);
        },
      ),
    );
  }
}
