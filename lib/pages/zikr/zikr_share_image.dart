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
  final String? code;

  const ZikrShareImageRequest({
    required this.title,
    required this.tabTitle,
    required this.content,
    required this.hideHeaderLine,
    this.code,
  });
}

Future<Uint8List?> buildZikrShareImage(ZikrShareImageRequest request) async {
  const width = 1080.0;
  const height = 1350.0;
  const padding = 72.0;
  const contentWidth = width - (padding * 2);
  const contentBottom = height - padding;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = const Size(width, height);
  final backgroundPaint = Paint()..color = const Color(0xFFFDF9F3);
  final cardPaint = Paint()..color = Colors.white;
  final borderPaint = Paint()
    ..color = const Color(0xFFE7D8CA)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  canvas.drawRect(Offset.zero & size, backgroundPaint);
  final cardRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(36, 36, width - 72, height - 72),
    const Radius.circular(36),
  );
  canvas.drawRRect(cardRect, cardPaint);
  canvas.drawRRect(cardRect, borderPaint);

  var y = padding;
  y = _paintText(
    canvas,
    request.title,
    Rect.fromLTWH(padding, y, contentWidth, 120),
    TextStyle(
      color: const Color(0xFF3F2B24),
      fontSize: 46,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: 0,
    ),
    textAlign: TextAlign.center,
    maxLines: 2,
  );
  y += 20;

  if (request.tabTitle.trim().isNotEmpty &&
      request.tabTitle.trim() != request.title.trim()) {
    y = _paintText(
      canvas,
      request.tabTitle,
      Rect.fromLTWH(padding, y, contentWidth, 64),
      TextStyle(
        color: const Color(0xFF7A5B4B),
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
    );
    y += 16;
  }

  final parsed = ZikrContentParser.parseContent(
    request.content,
    hideHeaderLine: request.hideHeaderLine,
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
        color: const Color(0xFF2E2723),
        fontFamily: arabicFont,
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
        color: const Color(0xFF5C4539),
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
        color: const Color(0xFF4E423C),
        fontSize: 28,
        height: 1.24,
        letterSpacing: 0,
      );
      textAlign = TextAlign.center;
      textDirection = TextDirection.ltr;
    } else {
      style = TextStyle(
        color: const Color(0xFF6B5A51),
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
    ellipsis: maxLines == null ? null : '...',
  )..layout(maxWidth: rect.width);

  painter.paint(canvas, Offset(rect.left, rect.top));
  return rect.top + painter.height;
}

const _minReadableHeight = 48.0;

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
  )..layout(maxWidth: maxWidth);
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

  final displayText = forceEllipsis ? _withTrailingEllipsis(text) : text;
  final painter = TextPainter(
    text: TextSpan(text: displayText, style: style),
    textAlign: textAlign,
    textDirection: textDirection,
  )..layout(maxWidth: rect.width);

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
    text: TextSpan(text: displayText, style: style),
    textAlign: textAlign,
    textDirection: textDirection,
    maxLines: maxLines,
    ellipsis: '...',
  )..layout(maxWidth: rect.width);

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

String _withTrailingEllipsis(String text) {
  final trimmed = text.trimRight();
  if (trimmed.endsWith('...')) return trimmed;
  return '$trimmed ...';
}
