import 'dart:async';

import 'package:flutter/material.dart';

class CollectionBanner extends StatefulWidget {
  const CollectionBanner({super.key, this.active = true});

  final bool active;

  @override
  State<CollectionBanner> createState() => _CollectionBannerState();
}

class _CollectionBannerState extends State<CollectionBanner>
    with WidgetsBindingObserver {
  static const _photos = [
    'asset/img/7ac34c80-45b0-4928-ad6c-59a941a71de0.jpg',
    'asset/img/2e012365-eaee-4f63-a9ed-f0eb2b9fcd16.jpg',
    'asset/img/3eab6e85-7f91-4ea4-9360-8f231d991f3e.jpg',
    'asset/img/15f94fb5-702d-4e04-a2b4-832912de9378.jpg',
  ];

  int _page = _photos.length * 100;
  late final _pages = PageController(initialPage: _page);
  Timer? _timer;
  bool _paused = false;
  bool _dragging = false;
  bool _animating = false;
  bool _foreground = true;
  bool _reduceMotion = false;
  bool _routeVisible = true;

  int get _index => _page % _photos.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _routeVisible = ModalRoute.of(context)?.isCurrent ?? true;
    _schedule();
  }

  @override
  void didUpdateWidget(covariant CollectionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!mounted ||
        !widget.active ||
        !_foreground ||
        !_routeVisible ||
        _paused ||
        _dragging ||
        _animating ||
        _reduceMotion) {
      return;
    }
    _timer = Timer(const Duration(seconds: 5), () => _move(_page + 1));
  }

  Future<void> _move(int target) async {
    if (_animating || !_pages.hasClients) return;
    _timer?.cancel();
    _animating = true;
    try {
      if (target < 0) {
        _pages.jumpToPage(_photos.length);
        target = _photos.length - 1;
      }
      if (_reduceMotion) {
        _pages.jumpToPage(target);
      } else {
        await _pages.animateToPage(
          target,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    } finally {
      _animating = false;
      if (mounted) _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  Widget _copy({bool compact = false}) => Padding(
    padding: EdgeInsets.all(compact ? 20 : 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'THE ARCHIVE / CH COLLECTION',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            color: Color(0xffd9d6cf),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          compact ? 'Dark essentials.' : 'Silver soul.\nDark essentials.',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: compact ? 30 : 40,
            height: 1.12,
            color: const Color(0xfff2f0eb),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Worn your way.',
          style: TextStyle(color: Color(0xffd9d6cf)),
        ),
      ],
    ),
  );

  Widget _slideshow(double height, {required bool wide}) => SizedBox(
    height: height,
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _dragging = true;
          _schedule();
        } else if (notification is ScrollEndNotification) {
          _dragging = false;
          _schedule();
        }
        return false;
      },
      child: PageView.builder(
        controller: _pages,
        onPageChanged: (page) {
          if (mounted) setState(() => _page = page);
        },
        itemBuilder: (context, page) => Image.asset(
          _photos[page % _photos.length],
          fit: wide ? BoxFit.contain : BoxFit.cover,
          alignment: const Alignment(0, -0.25),
          cacheWidth: 1000,
          semanticLabel:
              'Collection lookbook photo ${page % _photos.length + 1} of ${_photos.length}',
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Color(0xff202023),
            child: Center(child: Icon(Icons.image_outlined, size: 48)),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xff111113),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xff373739)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 700;
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
            if (wide) {
              return Row(
                children: [
                  Expanded(flex: 5, child: _copy()),
                  Expanded(
                    flex: 6,
                    child: _slideshow(
                      (box.maxWidth / 2.4).clamp(320.0, 460.0),
                      wide: true,
                    ),
                  ),
                ],
              );
            }
            final images = _slideshow(
              (box.maxWidth * 1.1).clamp(280.0, 440.0),
              wide: false,
            );
            if (largeText) {
              return Column(children: [images, _copy(compact: true)]);
            }
            return Stack(
              children: [
                images,
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.35, 1],
                          colors: [Colors.transparent, Color(0xf5000000)],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(child: _copy(compact: true)),
                ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous photo',
                onPressed: () => _move(_page - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: List.generate(
                    _photos.length,
                    (index) => Semantics(
                      selected: _index == index,
                      child: IconButton(
                        tooltip: 'Show photo ${index + 1}',
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 44,
                        ),
                        padding: const EdgeInsets.all(8),
                        onPressed: () => _move(_page + index - _index),
                        icon: Icon(
                          _index == index
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next photo',
                onPressed: () => _move(_page + 1),
                icon: const Icon(Icons.chevron_right),
              ),
              if (!_reduceMotion)
                IconButton(
                  tooltip: _paused ? 'Play slideshow' : 'Pause slideshow',
                  onPressed: () {
                    setState(() => _paused = !_paused);
                    _schedule();
                  },
                  icon: Icon(_paused ? Icons.play_arrow_outlined : Icons.pause),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
