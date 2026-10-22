import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mprs_android/controller/booking_controller.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/app_text_styles.dart';
import 'package:mprs_android/screens/home_screen/home_actions.dart';

class GenieScreen extends StatefulWidget {
  final String? initialPrompt;

  const GenieScreen({super.key, this.initialPrompt});

  @override
  State<GenieScreen> createState() => _GenieScreenState();
}

class _GenieMessage {
  final bool fromUser;
  final String text;
  final List<_GenieAction> actions;

  const _GenieMessage({
    required this.fromUser,
    required this.text,
    this.actions = const [],
  });
}

class _GenieAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GenieAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _GenieScreenState extends State<GenieScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final BookingController _bookings = Get.put(
    BookingController(),
    tag: 'all_bookings',
  );
  final List<_GenieMessage> _messages = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final prompt = widget.initialPrompt?.trim() ?? '';
    if (prompt.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit(prompt);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final query = raw.trim();
    if (query.isEmpty || _busy) return;
    _controller.clear();
    setState(() {
      _busy = true;
      _messages.add(_GenieMessage(fromUser: true, text: query));
    });
    _scrollToEnd();

    final reply = _replyFor(query);
    if (reply.runTrack) {
      await HomeActions.trackShipment(context, reply.trackQuery, _bookings);
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _messages.add(
        _GenieMessage(
          fromUser: false,
          text: reply.text,
          actions: reply.actions,
        ),
      );
    });
    _scrollToEnd();
  }

  _GenieReply _replyFor(String query) {
    final lower = query.toLowerCase();
    if (HomeActions.looksLikeTrackingId(query)) {
      return _GenieReply(
        text: 'Looking up "$query" in your shipments.',
        runTrack: true,
        trackQuery: query,
      );
    }
    if (lower.contains('rate') ||
        lower.contains('cheap') ||
        lower.contains(' to ')) {
      return _GenieReply(
        text:
            'I can open Search Rates so you can compare live prices for that lane.',
        actions: [
          _GenieAction(
            label: 'Search Rates',
            icon: Icons.payments_outlined,
            onTap: HomeActions.openSearch,
          ),
        ],
      );
    }
    if (lower.contains('quote') || lower.contains('quotation')) {
      return _GenieReply(
        text: 'Create a quotation with the same form used in Book.',
        actions: [
          _GenieAction(
            label: 'Create Quotation',
            icon: Icons.description_outlined,
            onTap: () => HomeActions.openCreateQuote(context),
          ),
          _GenieAction(
            label: 'Saved Quotations',
            icon: Icons.folder_open_outlined,
            onTap: () => HomeActions.openBook(bookTab: 1),
          ),
        ],
      );
    }
    if (lower.contains('track') ||
        lower.contains('container') ||
        lower.contains('shipment')) {
      return _GenieReply(
        text:
            'Open Track to see booked and in-progress shipments, or paste a QT, order, or container number here.',
        actions: [
          _GenieAction(
            label: 'Track',
            icon: Icons.inventory_2_outlined,
            onTap: () => HomeActions.openTrack(),
          ),
        ],
      );
    }
    if (lower.contains('book')) {
      return _GenieReply(
        text: 'Book a shipment from Search Rates, then save the quotation.',
        actions: [
          _GenieAction(
            label: 'Book Shipment',
            icon: Icons.local_shipping_outlined,
            onTap: () => HomeActions.openBook(bookTab: 1, quoteFilter: 1),
          ),
        ],
      );
    }
    if (lower.contains('support') ||
        lower.contains('contact') ||
        lower.contains('help')) {
      return _GenieReply(
        text: 'I can connect you with the MPRS support team.',
        actions: [
          _GenieAction(
            label: 'Contact Support',
            icon: Icons.headset_mic_outlined,
            onTap: () => HomeActions.openSupport(context),
          ),
        ],
      );
    }
    return _GenieReply(
      text:
          'I can track a container, search rates, create a quotation, or reach support. Try “Cheapest rate Mumbai to Dubai” or a QT number.',
      actions: [
        _GenieAction(
          label: 'Search Rates',
          icon: Icons.payments_outlined,
          onTap: HomeActions.openSearch,
        ),
        _GenieAction(
          label: 'Track',
          icon: Icons.inventory_2_outlined,
          onTap: () => HomeActions.openTrack(),
        ),
        _GenieAction(
          label: 'Create Quotation',
          icon: Icons.description_outlined,
          onTap: () => HomeActions.openCreateQuote(context),
        ),
      ],
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.main),
                  const SizedBox(width: 8),
                  Text(
                    'MPRS Genie',
                    style: AppTextStyles.montserratBold.copyWith(
                      fontSize: 20,
                      color: const Color(0xFF1C2434),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  _messages.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _bubble(_messages[index]);
                        },
                      ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _submit,
                        decoration: InputDecoration(
                          hintText: 'Ask anything… e.g. Cheapest rate Mumbai to Dubai',
                          hintStyle: AppTextStyles.montserratRegular.copyWith(
                            color: const Color(0xFF98A2B3),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child:
                          _busy
                              ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                              : Material(
                                color: AppColors.main,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => _submit(_controller.text),
                                  child: const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Icon(
                                      Icons.auto_awesome,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        Text(
          'What can I help you ship today?',
          style: AppTextStyles.montserratBold.copyWith(
            fontSize: 22,
            color: const Color(0xFF1C2434),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Ask for a rate, a quotation, or a container number. Genie opens the same screens you already use.",
          style: AppTextStyles.montserratRegular.copyWith(
            fontSize: 14,
            color: const Color(0xFF667085),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _suggestion('Cheapest rate Mumbai to Dubai'),
            _suggestion('Track my shipment'),
            _suggestion('Create a quotation'),
            _suggestion('Contact support'),
          ],
        ),
      ],
    );
  }

  Widget _suggestion(String text) {
    return ActionChip(
      label: Text(text),
      labelStyle: AppTextStyles.montserratMedium.copyWith(fontSize: 12),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE4E7EC)),
      onPressed: () => _submit(text),
    );
  }

  Widget _bubble(_GenieMessage message) {
    final align = message.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.fromUser ? AppColors.main : Colors.white;
    final textColor = message.fromUser ? Colors.white : const Color(0xFF1C2434);
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border:
              message.fromUser
                  ? null
                  : Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTextStyles.montserratMedium.copyWith(
                color: textColor,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (message.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final action in message.actions)
                    ActionChip(
                      avatar: Icon(action.icon, size: 16, color: AppColors.main),
                      label: Text(action.label),
                      onPressed: action.onTap,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GenieReply {
  final String text;
  final List<_GenieAction> actions;
  final bool runTrack;
  final String trackQuery;

  const _GenieReply({
    required this.text,
    this.actions = const [],
    this.runTrack = false,
    this.trackQuery = '',
  });
}
