import 'package:flutter/material.dart';

/// Home "Our Services" strip. Native scroller so the card is only as tall
/// as the icons, with no WebView blank space underneath.
class MarqueeWebView extends StatefulWidget {
  const MarqueeWebView({super.key});

  @override
  State<MarqueeWebView> createState() => _MarqueeWebViewState();
}

class _MarqueeWebViewState extends State<MarqueeWebView>
    with SingleTickerProviderStateMixin {
  static const _items = <(String, String)>[
    ('Ocean Freight', 'assets/images/1.webp'),
    ('Surface Transport', 'assets/images/2.webp'),
    ('Consolidation Services', 'assets/images/3.webp'),
    ('Customs Clearance', 'assets/images/4.webp'),
    ('Cross Country Logistics', 'assets/images/5.webp'),
    ('Air Freight', 'assets/images/6.webp'),
    ('Liquid Logistics', 'assets/images/7.webp'),
    ('Warehousing & Cross Stuffing', 'assets/images/8.webp'),
    ('Maritime Legal Consultancy', 'assets/images/9.webp'),
  ];

  late final AnimationController _controller;
  final GlobalKey _stripKey = GlobalKey();
  double _stripWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = _stripKey.currentContext?.findRenderObject() as RenderBox?;
    if (!mounted || box == null || !box.hasSize) return;
    if (box.size.width != _stripWidth) {
      setState(() => _stripWidth = box.size.width);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final dx =
                  _stripWidth == 0 ? 0.0 : -_controller.value * _stripWidth;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Row(
              children: [
                _strip(key: _stripKey),
                _strip(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _strip({Key? key}) {
    return Row(
      key: key,
      children: [
        for (final item in _items) ...[
          _label(item.$1),
          const SizedBox(width: 14),
          _icon(item.$2),
          const SizedBox(width: 28),
        ],
      ],
    );
  }

  Widget _label(String text) {
    return ShaderMask(
      shaderCallback:
          (bounds) => const LinearGradient(
            colors: [Color(0xFF7EAEA8), Color(0xFF9A96C4)],
          ).createShader(bounds),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }

  Widget _icon(String asset) {
    return ClipOval(
      child: Image.asset(
        asset,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
    );
  }
}
