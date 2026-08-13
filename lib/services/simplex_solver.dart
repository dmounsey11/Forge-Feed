/// A linear constraint `coefficients · x {<=, >=, =} rhs`.
enum ConstraintType { lessOrEqual, greaterOrEqual, equal }

class LpConstraint {
  final List<double> coefficients;
  final ConstraintType type;
  final double rhs;

  const LpConstraint(this.coefficients, this.type, this.rhs);
}

class LpResult {
  final bool feasible;
  final List<double> solution;
  final double objectiveValue;

  const LpResult({required this.feasible, required this.solution, required this.objectiveValue});

  static const LpResult infeasible = LpResult(feasible: false, solution: [], objectiveValue: double.nan);
}

/// A small self-contained two-phase Simplex solver for
/// `minimize costs · x subject to constraints, x >= 0`.
///
/// Built in-house rather than pulling in a package: the problems this app
/// solves are small (a few dozen ingredients, roughly a dozen nutrient/
/// safety constraints), and a hand-rolled tableau method is simple enough
/// to fully unit-test on its own (see simplex_solver_test.dart) before
/// diet_calculator.dart depends on it for anything. Uses Bland's rule
/// (smallest-index entering/leaving variable) throughout to guarantee
/// termination - no cycling - at the cost of not being the fastest
/// possible pivot rule, which doesn't matter at this problem size.
class SimplexSolver {
  static const double _epsilon = 1e-7;

  static LpResult minimize({
    required List<double> costs,
    required List<LpConstraint> constraints,
  }) {
    final n = costs.length;
    final m = constraints.length;

    if (m == 0) {
      // Minimizing over x >= 0 with no other constraints is only bounded
      // (at the origin) if every cost is already non-negative.
      if (costs.every((c) => c >= -_epsilon)) {
        return LpResult(feasible: true, solution: List.filled(n, 0.0), objectiveValue: 0.0);
      }
      return LpResult.infeasible;
    }

    // Normalize so every rhs is >= 0 - required for the initial slack/
    // artificial basis below to start at a non-negative value.
    final normalized = constraints.map((c) {
      if (c.rhs >= 0) return c;
      final flipped = switch (c.type) {
        ConstraintType.lessOrEqual => ConstraintType.greaterOrEqual,
        ConstraintType.greaterOrEqual => ConstraintType.lessOrEqual,
        ConstraintType.equal => ConstraintType.equal,
      };
      return LpConstraint(c.coefficients.map((v) => -v).toList(), flipped, -c.rhs);
    }).toList();

    var numSlack = 0;
    var numArtificial = 0;
    for (final c in normalized) {
      switch (c.type) {
        case ConstraintType.lessOrEqual:
          numSlack++;
          break;
        case ConstraintType.greaterOrEqual:
          numSlack++;
          numArtificial++;
          break;
        case ConstraintType.equal:
          numArtificial++;
          break;
      }
    }

    final totalCols = n + numSlack + numArtificial;
    // Rows 0..m-1 are the constraints; row m is the objective/reduced-cost
    // row. Column totalCols is the rhs. Kept as one tableau so a single
    // pivot operation maintains every row - including the objective row -
    // consistently.
    final tableau = List.generate(m + 1, (_) => List<double>.filled(totalCols + 1, 0.0));
    final basis = List<int>.filled(m, -1);
    final artificialCols = <int>{};

    var slackIdx = n;
    var artIdx = n + numSlack;
    for (var i = 0; i < m; i++) {
      final row = tableau[i];
      final c = normalized[i];
      for (var j = 0; j < n; j++) {
        row[j] = c.coefficients[j];
      }
      row[totalCols] = c.rhs;
      switch (c.type) {
        case ConstraintType.lessOrEqual:
          row[slackIdx] = 1.0;
          basis[i] = slackIdx;
          slackIdx++;
          break;
        case ConstraintType.greaterOrEqual:
          row[slackIdx] = -1.0;
          slackIdx++;
          row[artIdx] = 1.0;
          basis[i] = artIdx;
          artificialCols.add(artIdx);
          artIdx++;
          break;
        case ConstraintType.equal:
          row[artIdx] = 1.0;
          basis[i] = artIdx;
          artificialCols.add(artIdx);
          artIdx++;
          break;
      }
    }

    if (artificialCols.isNotEmpty) {
      final phase1Cost = List<double>.filled(totalCols, 0.0);
      for (final col in artificialCols) {
        phase1Cost[col] = 1.0;
      }
      _setObjectiveRow(tableau, basis, phase1Cost, totalCols);
      _runSimplex(tableau, basis, m, totalCols, totalCols);

      final phase1Objective = -tableau[m][totalCols];
      if (phase1Objective > _epsilon) {
        return LpResult.infeasible;
      }

      // Drive out any artificial variable left basic at (near) zero, so it
      // can never re-enter with a positive value in phase 2. If no
      // non-artificial pivot is available, the row is a redundant
      // constraint and is simply left as-is.
      for (var i = 0; i < m; i++) {
        if (!artificialCols.contains(basis[i])) continue;
        var pivoted = false;
        for (var j = 0; j < n + numSlack; j++) {
          if (tableau[i][j].abs() > _epsilon) {
            _pivot(tableau, i, j);
            basis[i] = j;
            pivoted = true;
            break;
          }
        }
        if (!pivoted) continue;
      }
    }

    final phase2Cost = List<double>.filled(totalCols, 0.0);
    for (var j = 0; j < n; j++) {
      phase2Cost[j] = costs[j];
    }
    _setObjectiveRow(tableau, basis, phase2Cost, totalCols);
    // Artificial columns are excluded from re-entering: their job is done
    // once phase 1 reaches a feasible point.
    _runSimplex(tableau, basis, m, totalCols, n + numSlack);

    final solution = List<double>.filled(n, 0.0);
    for (var i = 0; i < m; i++) {
      if (basis[i] < n) {
        solution[basis[i]] = tableau[i][totalCols];
      }
    }
    var objectiveValue = 0.0;
    for (var j = 0; j < n; j++) {
      objectiveValue += costs[j] * solution[j];
    }
    return LpResult(feasible: true, solution: solution, objectiveValue: objectiveValue);
  }

  /// Sets row [m] (the objective row) so that, for the given [cost] vector,
  /// reduced costs are consistent with the current [basis] - i.e. zero at
  /// every basic column - which is the required starting invariant for the
  /// simplex loop below.
  static void _setObjectiveRow(
    List<List<double>> tableau,
    List<int> basis,
    List<double> cost,
    int totalCols,
  ) {
    final m = basis.length;
    final row = tableau[m];
    row.setAll(0, List.filled(totalCols + 1, 0.0));
    for (var j = 0; j < totalCols; j++) {
      row[j] = cost[j];
    }
    for (var i = 0; i < m; i++) {
      final cb = cost[basis[i]];
      if (cb == 0) continue;
      for (var j = 0; j <= totalCols; j++) {
        row[j] -= cb * tableau[i][j];
      }
    }
  }

  /// Standard tableau simplex loop (minimization), using Bland's rule for
  /// both the entering column (smallest index with a negative reduced
  /// cost) and the leaving row (smallest-index basic variable among tied
  /// minimum ratios) to guarantee termination. Only columns below
  /// [maxEnterCol] are eligible to enter the basis.
  static void _runSimplex(
    List<List<double>> tableau,
    List<int> basis,
    int m,
    int totalCols,
    int maxEnterCol,
  ) {
    while (true) {
      var enterCol = -1;
      for (var j = 0; j < maxEnterCol; j++) {
        if (tableau[m][j] < -_epsilon) {
          enterCol = j;
          break;
        }
      }
      if (enterCol == -1) return; // optimal

      var leaveRow = -1;
      var bestRatio = double.infinity;
      for (var i = 0; i < m; i++) {
        final coeff = tableau[i][enterCol];
        if (coeff <= _epsilon) continue;
        final ratio = tableau[i][totalCols] / coeff;
        if (ratio < bestRatio - _epsilon ||
            (ratio < bestRatio + _epsilon && (leaveRow == -1 || basis[i] < basis[leaveRow]))) {
          bestRatio = ratio;
          leaveRow = i;
        }
      }
      if (leaveRow == -1) return; // unbounded - nothing more this solver can do

      _pivot(tableau, leaveRow, enterCol);
      basis[leaveRow] = enterCol;
    }
  }

  static void _pivot(List<List<double>> tableau, int pivotRow, int pivotCol) {
    final pv = tableau[pivotRow][pivotCol];
    final row = tableau[pivotRow];
    for (var j = 0; j < row.length; j++) {
      row[j] /= pv;
    }
    for (var i = 0; i < tableau.length; i++) {
      if (i == pivotRow) continue;
      final factor = tableau[i][pivotCol];
      if (factor == 0) continue;
      final target = tableau[i];
      for (var j = 0; j < target.length; j++) {
        target[j] -= factor * row[j];
      }
    }
  }
}
