/// Simple line-based diff (LCS) for previewing changes between original and fixed content.
/// Not optimized for very large inputs but sufficient for template sizes.
class DiffSegment {
  final DiffOp op; // equal, add, remove
  final String line;
  DiffSegment(this.op, this.line);
}

enum DiffOp { equal, add, remove }

List<DiffSegment> computeLineDiff(String original, String modified) {
  final a = original.split(RegExp(r'\r?\n'));
  final b = modified.split(RegExp(r'\r?\n'));
  final n = a.length;
  final m = b.length;
  // LCS table
  final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (int i = n - 1; i >= 0; i--) {
    for (int j = m - 1; j >= 0; j--) {
      if (a[i] == b[j]) {
        lcs[i][j] = lcs[i + 1][j + 1] + 1;
      } else {
        lcs[i][j] = lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1];
      }
    }
  }
  final result = <DiffSegment>[];
  int i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      result.add(DiffSegment(DiffOp.equal, a[i]));
      i++; j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      result.add(DiffSegment(DiffOp.remove, a[i]));
      i++;
    } else {
      result.add(DiffSegment(DiffOp.add, b[j]));
      j++;
    }
  }
  while (i < n) { result.add(DiffSegment(DiffOp.remove, a[i++])); }
  while (j < m) { result.add(DiffSegment(DiffOp.add, b[j++])); }
  return _collapse(result);
}

// Collapse consecutive removes/adds for readability (keep line granularity)
List<DiffSegment> _collapse(List<DiffSegment> segs) {
  // Currently no merging; kept for potential future optimization.
  return segs;
}
