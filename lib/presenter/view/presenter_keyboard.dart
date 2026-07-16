import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/presenter_cubit.dart';

/// Gives the operator keyboard control of the shown line: arrows / space to move
/// line, page-up/down for shabad, home/end, esc to blank. A body-level [Focus]
/// owns the keys; it regains focus whenever the shown line changes, so keys work
/// right after any selection - but it never steals focus while the operator is
/// typing in the search box, because typing doesn't change the line.
class PresenterKeyboard extends StatefulWidget {
  const PresenterKeyboard({required this.child, super.key});

  final Widget child;

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
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.space) {
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
