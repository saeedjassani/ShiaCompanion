import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Two columns of cards whose [floating] cards each go under whichever
/// column is shorter at the time, so neither column ends far above the
/// other: [start] and [end] are stacked first, in order, then each of
/// [floating] in turn.
///
/// [start] is the left column in a left-to-right language and the right one
/// in a right-to-left one, as in a [Row]. The columns share the width
/// [startFlex] to [endFlex], with [gap] between them. A child that shows
/// nothing (a [SizedBox.shrink]) takes no room.
class BalancedColumns extends MultiChildRenderObjectWidget {
  BalancedColumns({
    super.key,
    required List<Widget> start,
    required List<Widget> end,
    List<Widget> floating = const [],
    this.startFlex = 1,
    this.endFlex = 1,
    this.gap = 0,
  })  : startCount = start.length,
        endCount = end.length,
        super(children: [...start, ...end, ...floating]);

  final int startCount;
  final int endCount;
  final int startFlex;
  final int endFlex;
  final double gap;

  @override
  RenderBalancedColumns createRenderObject(BuildContext context) =>
      RenderBalancedColumns(
        startCount: startCount,
        endCount: endCount,
        startFlex: startFlex,
        endFlex: endFlex,
        gap: gap,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
      BuildContext context, RenderBalancedColumns renderObject) {
    renderObject
      ..startCount = startCount
      ..endCount = endCount
      ..startFlex = startFlex
      ..endFlex = endFlex
      ..gap = gap
      ..textDirection = Directionality.of(context);
  }
}

class _BalancedColumnsParentData extends ContainerBoxParentData<RenderBox> {}

class RenderBalancedColumns extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BalancedColumnsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BalancedColumnsParentData> {
  RenderBalancedColumns({
    required int startCount,
    required int endCount,
    required int startFlex,
    required int endFlex,
    required double gap,
    required TextDirection textDirection,
  })  : _startCount = startCount,
        _endCount = endCount,
        _startFlex = startFlex,
        _endFlex = endFlex,
        _gap = gap,
        _textDirection = textDirection;

  int _startCount;
  set startCount(int value) {
    if (value == _startCount) return;
    _startCount = value;
    markNeedsLayout();
  }

  int _endCount;
  set endCount(int value) {
    if (value == _endCount) return;
    _endCount = value;
    markNeedsLayout();
  }

  int _startFlex;
  set startFlex(int value) {
    if (value == _startFlex) return;
    _startFlex = value;
    markNeedsLayout();
  }

  int _endFlex;
  set endFlex(int value) {
    if (value == _endFlex) return;
    _endFlex = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BalancedColumnsParentData) {
      child.parentData = _BalancedColumnsParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final startWidth =
        math.max(0.0, (width - _gap) * _startFlex / (_startFlex + _endFlex));
    final endWidth = math.max(0.0, width - _gap - startWidth);
    final rtl = _textDirection == TextDirection.rtl;
    final startX = rtl ? width - startWidth : 0.0;
    final endX = rtl ? 0.0 : startWidth + _gap;

    var startHeight = 0.0;
    var endHeight = 0.0;
    var index = 0;
    var child = firstChild;
    while (child != null) {
      final bool inStart;
      if (index < _startCount) {
        inStart = true;
      } else if (index < _startCount + _endCount) {
        inStart = false;
      } else {
        inStart = startHeight <= endHeight;
      }
      final columnWidth = inStart ? startWidth : endWidth;
      child.layout(BoxConstraints.tightFor(width: columnWidth),
          parentUsesSize: true);
      final parentData = child.parentData! as _BalancedColumnsParentData;
      if (inStart) {
        parentData.offset = Offset(startX, startHeight);
        startHeight += child.size.height;
      } else {
        parentData.offset = Offset(endX, endHeight);
        endHeight += child.size.height;
      }
      index++;
      child = parentData.nextSibling;
    }
    size = constraints.constrain(Size(width, math.max(startHeight, endHeight)));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
