import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/presenter_cubit.dart';
import '../gurmukhi_text.dart';

/// Gives the operator keyboard control of the shown line: arrows / space to move
/// line, page-up/down for shabad, home/end, esc to blank, Ctrl+1..4 quick
/// inserts, Ctrl+/ to focus search, Ctrl+C to copy. A body-level [Focus] owns
/// the keys; it regains focus whenever the shown line changes, so keys work
/// right after any selection - but plain keys never steal focus while the
/// operator is typing in the search box (chords still fire, like STTM).
class PresenterKeyboard extends StatefulWidget {
  const PresenterKeyboard({required this.child, this.onFocusSearch, super.key});

  final Widget child;

  /// STTM's Ctrl+/ - focus the search field (the field lives in another pane,
  /// so the owner wires this to its FocusNode).
  final VoidCallback? onFocusSearch;

  @override
  State<PresenterKeyboard> createState() => _PresenterKeyboardState();
}

class _PresenterKeyboardState extends State<PresenterKeyboard> {
  final _focus = FocusNode(debugLabel: 'presenterNav', skipTraversal: true);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final c = context.read<PresenterCubit>();
    final key = event.logicalKey;
    final chord =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // STTM's global chords fire regardless of focus: they bubble up from the
    // search box (the IME ignores Ctrl+digit), so an operator can throw up a
    // quick-insert slide or refocus search without leaving the field. Only on
    // the initial press, not key-repeat.
    if (event is KeyDownEvent && chord) {
      if (key == LogicalKeyboardKey.digit1) {
        c.showWaheguru();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit2) {
        c.showMoolMantar();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit3) {
        c.showBlank();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit4) {
        c.showAnandBhog();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.slash) {
        widget.onFocusSearch?.call();
        return KeyEventResult.handled;
      }
    }

    // Never steal plain keys while a text field (the search box) has focus - its
    // key events bubble up here, and a handled space would both advance the line
    // and never reach the IME, eating the space out of the query.
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused?.findAncestorStateOfType<EditableTextState>() != null) {
      return KeyEventResult.ignored;
    }
    // STTM's Ctrl/Cmd+C: copy the active verse's Gurmukhi. After the focus guard
    // so the search box keeps its own text copy. Only on the initial press.
    if (event is KeyDownEvent && chord && key == LogicalKeyboardKey.keyC) {
      final text = c.state.copyableGurmukhi;
      if (text == null) return KeyEventResult.ignored;
      Clipboard.setData(ClipboardData(text: strippedGurmukhi(text)));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Verse copied to clipboard'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      c.advance(); // STTM's intelligent spacebar; plain when no home is set
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight) {
      c.nextLine();
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      c.prevLine();
    } else if (key == LogicalKeyboardKey.pageDown) {
      c.nextShabad();
    } else if (key == LogicalKeyboardKey.pageUp) {
      c.prevShabad();
    } else if (key == LogicalKeyboardKey.home) {
      c.showLine(0);
    } else if (key == LogicalKeyboardKey.end) {
      c.showLine(c.state.shabad.length - 1);
    } else if (key == LogicalKeyboardKey.escape) {
      c.showBlank();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PresenterCubit, PresenterState>(
      listenWhen: (a, b) => a.current != b.current || a.shabad != b.shabad,
      listener: (_, _) => _focus.requestFocus(),
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, event) => _onKey(event),
        child: widget.child,
      ),
    );
  }
}
