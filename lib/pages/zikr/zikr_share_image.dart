import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../constants.dart';
import 'zikr_content_parser.dart';

class ZikrShareImageRequest {
  final String title;
  final String tabTitle;
  final String content;
  final bool hideHeaderLine;
  final ColorScheme colorScheme;
  final String? code;

  const ZikrShareImageRequest({
    required this.title,
    required this.tabTitle,
    required this.content,
    required this.hideHeaderLine,
    required this.colorScheme,
    this.code,
  });
}

Future<Uint8List?> buildZikrShareImage(ZikrShareImageRequest request) async {
  const width = 1080.0;
  const height = 1350.0;
  const padding = 54.0;
  const contentWidth = width - (padding * 2);
  const contentBottom = height - 54.0;
  final colors = _ShareImageColors.fromScheme(request.colorScheme);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = const Size(width, height);
  final backgroundPaint = Paint()..color = colors.background;

  canvas.drawRect(Offset.zero & size, backgroundPaint);

  var y = 44.0;
  y = _paintText(
    canvas,
    request.title,
    Rect.fromLTWH(padding, y, contentWidth, 68),
    TextStyle(
      color: colors.primaryText,
      fontSize: 40,
      fontWeight: FontWeight.w500,
      height: 1.15,
      letterSpacing: 0,
    ),
    maxLines: 1,
  );
  y += 64;

  if (request.tabTitle.trim().isNotEmpty &&
      !_sameHeaderText(request.tabTitle, request.title)) {
    y = _paintText(
      canvas,
      request.tabTitle,
      Rect.fromLTWH(padding, y, contentWidth, 64),
      TextStyle(
        color: colors.secondaryText,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
    );
    y += 22;
  }

  final parsed = ZikrContentParser.parseContent(
    request.content,
    hideHeaderLine: request.hideHeaderLine || _startsWithVisibleHeader(request),
    code: request.code,
  );
  final shareLines = <_ShareImageLine>[];

  for (var i = 0; i < parsed.lines.length; i++) {
    var line = _plainText(parsed.lines[i].trim());
    if (line.isEmpty) {
      continue;
    }

    TextStyle style;
    TextAlign textAlign;
    TextDirection textDirection;
    var topPadding = 6.0;
    var bottomPadding = 4.0;

    if (parsed.arabicCodes.contains(i)) {
      line = ZikrContentParser.formatArabicText(line);
      style = TextStyle(
        color: colors.primaryText,
        fontFamily: arabicFont,
        // Matches the reader: the privately-encoded Indo-Pak pause signs are
        // drawn from Qalam, which is the only font that has them.
        fontFamilyFallback: const ['Qalam'],
        fontSize: 46,
        height: 1.38,
        letterSpacing: 0,
      );
      textAlign = TextAlign.center;
      textDirection = TextDirection.rtl;
      topPadding = 10;
      bottomPadding = 6;
    } else if (parsed.transliCodes.contains(i)) {
      if (!showTransliteration) continue;
      line = line.toUpperCase();
      style = TextStyle(
        color: colors.primaryText,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.24,
        letterSpacing: 0,
      );
      textAlign = TextAlign.center;
      textDirection = TextDirection.ltr;
    } else if (parsed.translaCodes.contains(i)) {
      if (!showTranslation) continue;
      style = TextStyle(
        color: colors.primaryText,
        fontSize: 28,
        height: 1.24,
        letterSpacing: 0,
      );
      textAlign = TextAlign.center;
      textDirection = TextDirection.ltr;
    } else {
      style = TextStyle(
        color: colors.secondaryText,
        fontSize: 26,
        fontStyle: FontStyle.italic,
        height: 1.22,
        letterSpacing: 0,
      );
      textAlign = TextAlign.start;
      textDirection = TextDirection.ltr;
      topPadding = 7;
    }

    shareLines.add(
      _ShareImageLine(
        text: line,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        topPadding: topPadding,
        bottomPadding: bottomPadding,
      ),
    );
  }

  for (var i = 0; i < shareLines.length; i++) {
    final shareLine = shareLines[i];
    final lineTop = y + shareLine.topPadding;
    final remainingHeight = contentBottom - lineTop;
    if (remainingHeight < _minReadableHeight) {
      break;
    }

    final naturalHeight = _measureTextHeight(
      shareLine.text,
      shareLine.style,
      contentWidth,
      textAlign: shareLine.textAlign,
      textDirection: shareLine.textDirection,
    );
    final hasMoreContent = i < shareLines.length - 1;
    final shouldEndWithEllipsis = hasMoreContent &&
        contentBottom - (lineTop + naturalHeight + shareLine.bottomPadding) <
            _minReadableHeight;
    final result = _paintContentLine(
      canvas,
      shareLine.text,
      Rect.fromLTWH(padding, lineTop, contentWidth, contentBottom - lineTop),
      shareLine.style,
      textAlign: shareLine.textAlign,
      textDirection: shareLine.textDirection,
      forceEllipsis: shouldEndWithEllipsis,
    );

    if (result == null) {
      break;
    }

    y = result.bottom + shareLine.bottomPadding;
    if (result.truncated || shouldEndWithEllipsis || y >= contentBottom) {
      break;
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();

  return byteData?.buffer.asUint8List();
}

double _paintText(
  Canvas canvas,
  String text,
  Rect rect,
  TextStyle style, {
  TextAlign textAlign = TextAlign.start,
  TextDirection textDirection = TextDirection.ltr,
  int? maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: textAlign,
    textDirection: textDirection,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : _ellipsis,
  )..layout(minWidth: rect.width, maxWidth: rect.width);

  painter.paint(canvas, Offset(rect.left, rect.top));
  return rect.top + painter.height;
}

const _minReadableHeight = 48.0;
const _ellipsis = '…';

class _ShareImageColors {
  final Color background;
  final Color primaryText;
  final Color secondaryText;

  const _ShareImageColors({
    required this.background,
    required this.primaryText,
    required this.secondaryText,
  });

  factory _ShareImageColors.fromScheme(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return _ShareImageColors(
      background: Color.lerp(
        scheme.surface,
        scheme.surfaceContainerLowest,
        dark ? 0.08 : 0.18,
      )!,
      primaryText: scheme.onSurface,
      secondaryText: scheme.onSurfaceVariant,
    );
  }
}

class _ShareImageLine {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double topPadding;
  final double bottomPadding;

  const _ShareImageLine({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.textDirection,
    required this.topPadding,
    required this.bottomPadding,
  });
}

class _PaintedLineResult {
  final double bottom;
  final bool truncated;

  const _PaintedLineResult({
    required this.bottom,
    required this.truncated,
  });
}

double _measureTextHeight(
  String text,
  TextStyle style,
  double maxWidth, {
  required TextAlign textAlign,
  required TextDirection textDirection,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: textAlign,
    textDirection: textDirection,
  )..layout(minWidth: maxWidth, maxWidth: maxWidth);
  return painter.height;
}

_PaintedLineResult? _paintContentLine(
  Canvas canvas,
  String text,
  Rect rect,
  TextStyle style, {
  required TextAlign textAlign,
  required TextDirection textDirection,
  bool forceEllipsis = false,
}) {
  final remainingHeight = rect.bottom - rect.top;
  if (remainingHeight < _minReadableHeight) {
    return null;
  }

  final displayText =
      forceEllipsis ? _withTrailingEllipsis(text, textDirection) : text;
  final painter = TextPainter(
    text: TextSpan(text: displayText, style: style),
    textAlign: textAlign,
    textDirection: textDirection,
  )..layout(minWidth: rect.width, maxWidth: rect.width);

  if (rect.top + painter.height <= rect.bottom) {
    painter.paint(canvas, Offset(rect.left, rect.top));
    return _PaintedLineResult(
      bottom: rect.top + painter.height,
      truncated: forceEllipsis,
    );
  }

  final fontSize = style.fontSize ?? 24;
  final lineHeight = math.max(fontSize, fontSize * (style.height ?? 1.2));
  final maxLines = math.max(1, (remainingHeight / lineHeight).floor());
  final truncatedPainter = TextPainter(
    text: TextSpan(
      text: _withTrailingEllipsis(text, textDirection),
      style: style,
    ),
    textAlign: textAlign,
    textDirection: textDirection,
    maxLines: maxLines,
    ellipsis: _ellipsis,
  )..layout(minWidth: rect.width, maxWidth: rect.width);

  truncatedPainter.paint(canvas, Offset(rect.left, rect.top));
  return _PaintedLineResult(
    bottom: rect.top + truncatedPainter.height,
    truncated: true,
  );
}

String _plainText(String line) {
  return ZikrContentParser.parseLineSegments(line)
      .map((segment) => segment.text)
      .join();
}

bool _startsWithVisibleHeader(ZikrShareImageRequest request) {
  final firstLine = request.content
      .split('\n')
      .map((line) => _plainText(line.trim()))
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  if (firstLine.isEmpty) return false;

  final normalizedFirstLine = _normalizeHeaderText(firstLine);
  return normalizedFirstLine.isNotEmpty &&
      (_sameHeaderText(firstLine, request.title) ||
          _sameHeaderText(firstLine, request.tabTitle));
}

bool _sameHeaderText(String first, String second) {
  return _normalizeHeaderText(first) == _normalizeHeaderText(second);
}

String _normalizeHeaderText(String text) {
  return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _withTrailingEllipsis(
  String text, [
  TextDirection textDirection = TextDirection.ltr,
]) {
  final trimmed = text.trimRight();
  if (trimmed.endsWith('...') || trimmed.endsWith(_ellipsis)) return trimmed;
  return '$trimmed $_ellipsis';
}
