import 'package:flutter/material.dart';

int chartIndexForDx(double dx, double width, int count) {
  if (count <= 1 || width <= 0) return 0;
  return ((dx / width) * (count - 1)).round().clamp(0, count - 1);
}

Offset chartPointForIndex(List<double> values, int index, Size size) {
  if (values.isEmpty) return Offset.zero;
  return _chartPoints(values, size)[index];
}

List<Offset> _chartPoints(List<double> values, Size size) {
  if (values.isEmpty) return const [];
  final minValue = values.reduce((a, b) => a < b ? a : b);
  final maxValue = values.reduce((a, b) => a > b ? a : b);
  final range = maxValue - minValue == 0 ? 1.0 : maxValue - minValue;
  return [
    for (var index = 0; index < values.length; index++)
      Offset(
        values.length == 1
            ? size.width / 2
            : size.width * index / (values.length - 1),
        size.height * (0.82 - (values[index] - minValue) / range * 0.64),
      ),
  ];
}

class SmoothLineChart extends StatefulWidget {
  final List<double> values;
  final List<DateTime> dates;
  final double height;
  final Color lineColor;
  final bool showMonthOnly;

  const SmoothLineChart({
    super.key,
    required this.values,
    required this.dates,
    required this.lineColor,
    this.height = 120,
    this.showMonthOnly = false,
  }) : assert(values.length == dates.length);

  @override
  State<SmoothLineChart> createState() => _SmoothLineChartState();
}

class _SmoothLineChartState extends State<SmoothLineChart> {
  int? _selectedIndex;

  void _select(double dx, double width) {
    if (widget.values.isEmpty) return;
    final index = chartIndexForDx(dx, width, widget.values.length);
    if (_selectedIndex != index) setState(() => _selectedIndex = index);
  }

  void _clear() {
    if (_selectedIndex != null) setState(() => _selectedIndex = null);
  }

  @override
  void didUpdateWidget(covariant SmoothLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values || oldWidget.dates != widget.dates) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final selected =
            _selectedIndex != null && _selectedIndex! < widget.values.length
                ? _selectedIndex
                : null;
        final point =
            selected == null
                ? null
                : chartPointForIndex(
                  widget.values,
                  selected,
                  Size(width, widget.height),
                );
        final tooltipWidth = (width - 8).clamp(0.0, 150.0);
        final tooltipLeft =
            point == null
                ? 0.0
                : (point.dx - tooltipWidth / 2).clamp(
                  4.0,
                  (width - tooltipWidth - 4).clamp(4.0, width),
                );
        final tooltipTop =
            point == null
                ? 0.0
                : point.dy >= 62
                ? point.dy - 58
                : (point.dy + 12).clamp(0.0, widget.height - 50);

        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _select(details.localPosition.dx, width),
            onTapUp: (_) => _clear(),
            onTapCancel: _clear,
            onHorizontalDragDown:
                (details) => _select(details.localPosition.dx, width),
            onHorizontalDragStart:
                (details) => _select(details.localPosition.dx, width),
            onHorizontalDragUpdate:
                (details) => _select(details.localPosition.dx, width),
            onHorizontalDragEnd: (_) => _clear(),
            onHorizontalDragCancel: _clear,
            onLongPressStart:
                (details) => _select(details.localPosition.dx, width),
            onLongPressMoveUpdate:
                (details) => _select(details.localPosition.dx, width),
            onLongPressEnd: (_) => _clear(),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder:
                  (context, progress, child) => Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SmoothChartPainter(
                            values: widget.values,
                            progress: progress,
                            lineColor: widget.lineColor,
                            selectedIndex: selected,
                          ),
                        ),
                      ),
                      if (selected != null && point != null)
                        Positioned(
                          left: tooltipLeft,
                          top: tooltipTop,
                          width: tooltipWidth,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              key: const ValueKey('chart-tooltip'),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _dateLabel(
                                        widget.dates[selected],
                                        widget.showMonthOnly,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      '${_formatAmount(widget.values[selected])} ₸',
                                      maxLines: 1,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge?.copyWith(
                                        color: widget.lineColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
            ),
          ),
        );
      },
    );
  }
}

String _dateLabel(DateTime date, bool monthOnly) {
  if (monthOnly) {
    const months = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _formatAmount(double value) {
  final text = value.round().abs().toString();
  final parts = <String>[];
  for (var end = text.length; end > 0; end -= 3) {
    parts.insert(0, text.substring((end - 3).clamp(0, end), end));
  }
  return '${value < 0 ? '−' : ''}${parts.join(' ')}';
}

class _SmoothChartPainter extends CustomPainter {
  final List<double> values;
  final double progress;
  final Color lineColor;
  final int? selectedIndex;

  _SmoothChartPainter({
    required this.values,
    required this.progress,
    required this.lineColor,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final points = _chartPoints(values, size);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    if (points.length >= 2) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 0; i < points.length - 1; i++) {
        final current = points[i];
        final next = points[i + 1];
        final controlX = (current.dx + next.dx) / 2;
        linePath.cubicTo(
          controlX,
          current.dy,
          controlX,
          next.dy,
          next.dx,
          next.dy,
        );
      }
      final fillPath =
          Path.from(linePath)
            ..lineTo(points.last.dx, size.height)
            ..lineTo(points.first.dx, size.height)
            ..close();
      final fillPaint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                lineColor.withValues(alpha: 0.20),
                lineColor.withValues(alpha: 0.01),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    final lastPoint = points.last;
    canvas.drawCircle(lastPoint, 5, Paint()..color = lineColor);
    canvas.drawCircle(
      lastPoint,
      10,
      Paint()..color = lineColor.withValues(alpha: 0.15),
    );
    canvas.restore();

    final selected = selectedIndex;
    if (selected != null && selected < points.length) {
      final point = points[selected];
      canvas.drawLine(
        Offset(point.dx, 0),
        Offset(point.dx, size.height),
        Paint()
          ..color = lineColor.withValues(alpha: 0.28)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        point,
        10,
        Paint()..color = lineColor.withValues(alpha: 0.20),
      );
      canvas.drawCircle(point, 6, Paint()..color = Colors.white);
      canvas.drawCircle(point, 4, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _SmoothChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.selectedIndex != selectedIndex;
}
