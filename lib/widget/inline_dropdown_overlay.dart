import 'package:flutter/material.dart';

class InlineDropdownOverlay extends StatefulWidget {
  final List<String> items;
  final String selectedItem;
  final ValueChanged<String> onChanged;

  const InlineDropdownOverlay({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
  });

  @override
  State<InlineDropdownOverlay> createState() => _InlineDropdownOverlayState();
}

class _InlineDropdownOverlayState extends State<InlineDropdownOverlay> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  late String selectedItem;
  List<String> filteredItems = [];

  final TextEditingController controller = TextEditingController();
  bool isOpen = false;

  @override
  void initState() {
    super.initState();
    selectedItem = widget.selectedItem;
    filteredItems = widget.items.where((i) => i != selectedItem).toList();
  }

  void openDropdown() {
    _overlayEntry = _createOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => isOpen = true);
  }

  void closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    controller.clear();
    setState(() {
      filteredItems =
          widget.items.where((i) => i != selectedItem).toList();
      isOpen = false;
    });
  }

  OverlayEntry _createOverlay() {
    RenderBox box = context.findRenderObject() as RenderBox;
    Size size = box.size;
    Offset pos = box.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: pos.dx,
        top: pos.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -3),
                  title: Text(filteredItems[index]),
                  onTap: () {
                    selectedItem = filteredItems[index];
                    widget.onChanged(selectedItem);
                    closeDropdown();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          if (!isOpen) {
            openDropdown();
          } else {
            closeDropdown();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),

          // ⭐ UPDATED UI BELOW ⭐
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedItem,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.black54, size: 22),
            ],
          ),
        ),
      ),
    );
  }

}
