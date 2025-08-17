import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class CustomSearchBar extends StatefulWidget {
  final String hintText;
  final Function(String) onChanged;
  final VoidCallback? onBack; // Optional back button callback
  final TextEditingController? controller; // Optional external controller
  final FocusNode? focus;

  const CustomSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.onBack,
    this.controller,
    this.focus,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  late final TextEditingController _internalController;
  late final TextEditingController _activeController;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController();
    _activeController = widget.controller ?? _internalController;

    _activeController.addListener(() {
      setState(() {
        widget.onChanged(_activeController.text);
        // Notify parent widget of text changes
      }); // Rebuild widget to show/hide clear button
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _internalController.dispose(); // Dispose only if it's internally created
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 4,
      shadowColor: theme.shadowColor.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      child: TextField(
        controller: _activeController,
        //  onChanged: widget.onChanged,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          prefixIcon: IconButton(
            icon: widget.onBack != null
                ? Icon(
                    Icons.arrow_back, // Show back arrow if onBack is provided
                    color: Colors.grey,
                  )
                : Icon(
                    Icons.search,
                    // color: Colors.white,
                    color: theme.colorScheme.primary,
                    size: 30,
                  ),
            // Image.asset(
            //     "assets/3d_icons/search_icon.png",
            //     width: 30, // Adjust the size as needed
            //     height: 30, // Adjust the size as needed
            //   ),
            onPressed: widget.onBack, // Call onBack callback
          ),
          hintText: widget.hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _activeController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Iconsax.close_circle, color: Colors.grey),
                  onPressed: () {
                    _activeController.clear();
                    widget.onChanged('');
                    FocusScope.of(context).unfocus(); // Close keyboard
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        textInputAction: TextInputAction.done,
        onEditingComplete: () {
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}
