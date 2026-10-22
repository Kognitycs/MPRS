import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';

class SearchableDropdown extends StatefulWidget {
  final String hint;
  final String? selectedValue;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? label;
  final Widget Function(BuildContext context, String? selectedValue)?
      triggerBuilder;

  const SearchableDropdown({
    Key? key,
    required this.hint,
    required this.selectedValue,
    required this.items,
    required this.onChanged,
    this.label,
    this.triggerBuilder,
  }) : super(key: key);

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final GlobalKey _dropdownKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: _dropdownKey,
      onTap: () => _showSearchMenu(context),
      borderRadius: BorderRadius.circular(16),
      child:
          widget.triggerBuilder?.call(context, widget.selectedValue) ??
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.selectedValue ?? widget.hint,
                    style: TextStyle(
                      color:
                          widget.selectedValue != null
                              ? Colors.black87
                              : Colors.grey[600],
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: AppColors.main, size: 20),
              ],
            ),
          ),
    );
  }

  void _showSearchMenu(BuildContext context) {
    FocusScope.of(context).unfocus();

    final RenderBox renderBox =
        _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate available space below and above the dropdown trigger
    const dropdownHeight = 400.0; // max height from _SearchDialog
    final spaceBelow = screenHeight - (offset.dy + size.height + 8);
    final spaceAbove = offset.dy - 8;
    
    // Determine if dropdown should appear above or below
    final showAbove = spaceBelow < dropdownHeight && spaceAbove > spaceBelow;
    final topPosition = showAbove 
        ? offset.dy - dropdownHeight - 8 
        : offset.dy + size.height + 8;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: topPosition,
              width: size.width,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: _SearchDialog(
                  title: widget.label ?? widget.hint,
                  items: widget.items,
                  selectedValue: widget.selectedValue,
                  onSelected: (value) {
                    widget.onChanged(value);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
}

class _SearchDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  const _SearchDialog({
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems =
            widget.items
                .where((item) => item.toLowerCase().contains(query))
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: 400, minHeight: 300),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with search
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.main.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.main,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  autofocus: false,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                            : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: AppColors.main, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_filteredItems.length} result${_filteredItems.length != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),

          // List
          Flexible(
            child:
                _filteredItems.isEmpty
                    ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 32,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No results found',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _filteredItems.length,
                      separatorBuilder:
                          (context, index) => Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Colors.grey[200],
                            indent: 12,
                            endIndent: 12,
                          ),
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = item == widget.selectedValue;

                        return InkWell(
                          onTap: () => widget.onSelected(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            color:
                                isSelected
                                    ? AppColors.main.withOpacity(0.08)
                                    : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? AppColors.main
                                              : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: AppColors.main,
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
