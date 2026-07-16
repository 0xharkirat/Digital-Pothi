import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/presenter/gurmukhi_text.dart';

const _heavy = Color(0xFFF0B429);
const _medium = Color(0xFF888888);
const _line = 'ਸੋਚੈ. ਸੋਚਿ ਨ ਹੋਵਈ; ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ ॥';

String _text(List<InlineSpan> spans) =>
    spans.map((s) => (s as TextSpan).text ?? '').join();

Color? _colorOf(List<InlineSpan> spans, String word) {
  final span = spans.firstWhere(
    (s) => (s as TextSpan).text == word,
    orElse: () => const TextSpan(),
  );
  return (span as TextSpan).style?.color;
}

void main() {
  test('strips the embedded vishraam punctuation from the text', () {
    final spans = gurmukhiSpans(_line, heavy: _heavy, medium: _medium);
    final text = _text(spans);
    expect(text, isNot(contains(';')));
    expect(text, isNot(contains('.')));
    expect(text.replaceAll(' ', ''), 'ਸੋਚੈਸੋਚਿਨਹੋਵਈਜੇਸੋਚੀਲਖਵਾਰ॥');
  });

  test('strips a mark sitting mid-token, not just at the end', () {
    // A handful of corpus lines carry a mark mid-word, e.g. ਸਚ;ੁ.
    final spans = gurmukhiSpans('ਸਚ;ੁ ਵੇਦੁ', heavy: _heavy, medium: _medium);
    expect(_text(spans), isNot(contains(';')));
    expect(_text(spans).replaceAll(' ', ''), 'ਸਚੁਵੇਦੁ');
  });

  test('colours the pause word when vishraam is on', () {
    final spans = gurmukhiSpans(_line, heavy: _heavy, medium: _medium);
    expect(_colorOf(spans, 'ਹੋਵਈ'), _heavy); // before a heavy ; pause
    expect(_colorOf(spans, 'ਸੋਚੈ'), isNull); // a light . pause: no colour
  });

  test('vishraam off leaves every word the base colour', () {
    final spans = gurmukhiSpans(
      _line,
      heavy: _heavy,
      medium: _medium,
      vishraam: false,
    );
    expect(_colorOf(spans, 'ਹੋਵਈ'), isNull);
  });

  test('larivaar runs the words together with no spaces', () {
    final spans = gurmukhiSpans(
      _line,
      heavy: _heavy,
      medium: _medium,
      larivaar: true,
    );
    expect(_text(spans), isNot(contains(' ')));
    expect(_text(spans), 'ਸੋਚੈਸੋਚਿਨਹੋਵਈਜੇਸੋਚੀਲਖਵਾਰ॥');
  });
}
