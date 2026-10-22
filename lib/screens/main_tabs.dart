/// Bottom navigation indexes for [MainScreen].
class MainTabs {
  static const int home = 0;
  static const int search = 1;
  static const int book = 2;
  static const int track = 3;
  static const int genie = 4;

  static void Function(MainTabRequest request)? _handler;
  static void Function()? openNotifications;

  static void bind({
    required void Function(MainTabRequest request) onOpenTab,
    required void Function() onOpenNotifications,
  }) {
    _handler = onOpenTab;
    openNotifications = onOpenNotifications;
  }

  static void unbind(void Function(MainTabRequest request) onOpenTab) {
    if (_handler == onOpenTab) {
      _handler = null;
      openNotifications = null;
    }
  }

  static void open(MainTabRequest request) {
    _handler?.call(request);
  }
}

class MainTabRequest {
  final int index;
  final int? bookTab;
  final int? bookQuoteFilter;
  final int? shipmentsTab;
  final String? geniePrompt;

  const MainTabRequest({
    required this.index,
    this.bookTab,
    this.bookQuoteFilter,
    this.shipmentsTab,
    this.geniePrompt,
  });
}
