import 'dart:async';
import 'package:flutter/material.dart';

/// Wraps SnackBar content with an automatic timer that safely hides the SnackBar
/// after [duration] (default 5 seconds), even when [SnackBarAction] is present
/// (which would otherwise cause Flutter to keep the SnackBar persistent).
///
/// Cancels the timer immediately when the widget is disposed, preventing timer leaks.
class AutoHidingSnackBarContent extends StatefulWidget {
  const AutoHidingSnackBarContent({
    super.key,
    required this.content,
    this.duration = const Duration(seconds: 5),
    this.messenger,
  });

  final Widget content;
  final Duration duration;
  final ScaffoldMessengerState? messenger;

  @override
  State<AutoHidingSnackBarContent> createState() =>
      _AutoHidingSnackBarContentState();
}

class _AutoHidingSnackBarContentState extends State<AutoHidingSnackBarContent> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) {
        if (widget.messenger != null) {
          widget.messenger!.hideCurrentSnackBar();
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.content;
  }
}

/// Helper function to show a SnackBar that automatically hides after [duration]
/// (defaults to 5 seconds), clearing any prior SnackBar immediately.
void showAutoHidingSnackBar({
  required ScaffoldMessengerState messenger,
  required Widget content,
  Duration duration = const Duration(seconds: 5),
  SnackBarAction? action,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: AutoHidingSnackBarContent(
        content: content,
        duration: duration,
        messenger: messenger,
      ),
      duration: duration,
      persist: false,
      action: action,
    ),
  );
}
