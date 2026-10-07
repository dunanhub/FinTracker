import 'dart:io';

/// Checks the LCOV files reported by Flutter. Flutter omits untouched sources;
/// this threshold therefore applies to coverage/lcov.info, not every lib file.
void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln('Missing coverage/lcov.info. Run flutter test --coverage.');
    exitCode = 2;
    return;
  }

  var linesFound = 0;
  var linesHit = 0;
  var files = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) files++;
    if (line.startsWith('LF:')) linesFound += int.parse(line.substring(3));
    if (line.startsWith('LH:')) linesHit += int.parse(line.substring(3));
  }

  if (files == 0 || linesFound == 0 || linesHit > linesFound) {
    stderr.writeln('Invalid or empty LCOV report: ${file.path}');
    exitCode = 2;
    return;
  }

  const threshold = 40.0;
  final percent = linesHit / linesFound * 100;
  stdout.writeln(
    'LCOV: LF=$linesFound LH=$linesHit '
    'coverage=${percent.toStringAsFixed(2)}% '
    'files=$files threshold=${threshold.toStringAsFixed(1)}%',
  );
  if (percent < threshold) {
    stderr.writeln('Coverage is below $threshold%.');
    exitCode = 1;
  }
}
