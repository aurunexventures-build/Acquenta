import 'package:flutter/material.dart';
import '../services/search_service.dart';
import '../services/recall_query.dart';
import '../screens/connection_detail_screen.dart';
import 'face_avatar.dart';
import 'recall_wireframe.dart';

/// Query words flow into the central brain and then into ranked people.
class RecallNetwork extends StatefulWidget {
  final List<SearchResult> results;
  final String query;
  final bool thinking;
  const RecallNetwork({
    super.key,
    required this.results,
    required this.query,
    this.thinking = false,
  });
  @override
  State<RecallNetwork> createState() => _RecallNetworkState();
}

class _RecallNetworkState extends State<RecallNetwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  List<SearchResult> get results => widget.results;
  String get query => widget.query;
  bool get thinking => widget.thinking;
  void _animate() {
    _flow.stop();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context)) {
      _flow.value = 1;
    } else {
      _flow.value = 0;
      _flow.repeat(count: 3);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate();
  }

  @override
  void didUpdateWidget(covariant RecallNetwork old) {
    super.didUpdateWidget(old);
    if (old.query != query || old.thinking != thinking) _animate();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _flow,
    builder: (_, _) => LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 400;
        final terms = SearchService.queryTerms(
          query,
        ).take(compact ? 4 : 6).toList();
        final chipWidth = compact ? 76.0 : 98.0;
        final robotWidth = compact ? 100.0 : 132.0;
        final robotHeight = robotWidth;
        final limit = box.maxWidth < 500 ? 3 : 5;
        final people = <SearchResult>[];
        // A small preview must represent each requested role before filling the
        // remaining places by rank (e.g. plumber + developer, not three developers).
        for (final term in SearchService.queryTerms(query)) {
          if (people.length == limit) break;
          for (final result in results) {
            if (RecallQuery.containsPhrase(result.connection.role, term)) {
              if (!people.contains(result)) people.add(result);
              break;
            }
          }
        }
        for (final result in results) {
          if (people.length == limit) break;
          if (!people.contains(result)) people.add(result);
        }
        people.sort((a, b) => results.indexOf(a).compareTo(results.indexOf(b)));
        final core = Offset(box.maxWidth / 2, box.maxHeight * .41);
        final words = List.generate(
          terms.length,
          (i) => Offset(
            i.isEven ? box.maxWidth * .16 : box.maxWidth * .84,
            20 + (i ~/ 2) * 30.0,
          ),
        );
        final targets = List.generate(
          people.length,
          (i) => Offset(
            box.maxWidth * (i + 1) / (people.length + 1),
            box.maxHeight - 47,
          ),
        );
        return Semantics(
          label:
              'Thinking Logic: search words flow through the robot to ranked connections',
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FlowPainter(
                    core,
                    core - Offset(0, robotHeight * .43),
                    words,
                    targets,
                    _flow.value,
                    terms,
                  ),
                ),
              ),
              Positioned(
                left: core.dx - robotWidth / 2,
                top: core.dy - robotHeight / 2,
                width: robotWidth,
                height: robotHeight,
                child: RecallWireframe(thinking: thinking),
              ),
              ...List.generate(terms.length, (i) {
                final point = words[i];
                return Positioned(
                  left: point.dx - chipWidth / 2,
                  top: point.dy - 13,
                  width: chipWidth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD8CDEE)),
                    ),
                    child: Text(
                      terms[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6554C0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
              ...List.generate(people.length, (i) {
                final p = targets[i];
                final c = people[i].connection;
                return Positioned(
                  left: p.dx - 45,
                  top: p.dy - 24,
                  width: 90,
                  height: 68,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ConnectionDetailScreen(connectionId: c.id),
                        ),
                      ),
                      child: Column(
                        children: [
                          FaceAvatar(
                            name: c.fullName,
                            photo: c.avatarUrl,
                            radius: 18,
                            backgroundColor: i == 0
                                ? const Color(0xFF6554C0)
                                : const Color(0xFFE1D9F0),
                            foregroundColor: i == 0
                                ? Colors.white
                                : const Color(0xFF6554C0),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            c.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF514563),
                              fontSize: 10,
                              fontWeight: i == 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    ),
  );
}

class _FlowPainter extends CustomPainter {
  final Offset core, antenna;
  final List<String> terms;
  final List<Offset> words, people;
  final double progress;
  _FlowPainter(
    this.core,
    this.antenna,
    this.words,
    this.people,
    this.progress,
    this.terms,
  );
  void _path(Canvas canvas, Offset from, Offset to, double amount, bool top) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(
        from.dx,
        from.dy + (to.dy - from.dy) * .5,
        to.dx,
        from.dy + (to.dy - from.dy) * .5,
        to.dx,
        to.dy,
      );
    final paint = Paint()
      ..color = top ? const Color(0xCB6554C0) : const Color(0x766554C0)
      ..strokeWidth = top ? 2 : 1.2
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(path, paint);
      if (amount > 0 && amount < 1) {
        final t = metric.getTangentForOffset(metric.length * amount);
        if (t != null) {
          canvas.drawCircle(
            t.position,
            3,
            Paint()..color = const Color(0xFF80B8B3),
          );
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < words.length; i++) {
      final phase = (progress + i * .17) % 1;
      _path(canvas, words[i], antenna, phase, false);
      if (progress > 0 && progress < 1) {
        final point = Offset.lerp(words[i], antenna, phase)!;
        final label = TextPainter(
          text: TextSpan(
            text: terms[i],
            style: const TextStyle(fontSize: 9, color: Color(0xFF6554C0)),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 65);
        label.paint(canvas, point - Offset(label.width / 2, 12));
      }
    }
    for (var i = 0; i < people.length; i++) {
      _path(
        canvas,
        core + const Offset(0, 53),
        people[i],
        (progress + .65) % 1,
        i == 0,
      );
    }
    final orbit = Paint()
      ..color = const Color(0x1D6554C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawOval(
      Rect.fromCenter(
        center: core + const Offset(0, 74),
        width: 135,
        height: 15,
      ),
      orbit,
    );
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) =>
      old.progress != progress ||
      old.core != core ||
      old.words.length != words.length ||
      old.people.length != people.length;
}
