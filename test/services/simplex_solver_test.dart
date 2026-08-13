import 'package:flutter_test/flutter_test.dart';
import 'package:forge_feed/services/simplex_solver.dart';

void main() {
  group('SimplexSolver.minimize', () {
    test('simple >= constraint: cheaper variable should be used to its limit', () {
      // minimize 2*x1 + 3*x2 s.t. x1 + x2 >= 10, x1 <= 15, x2 <= 15.
      // x1 is cheaper, so the optimum uses only x1: x1=10, x2=0, cost=20.
      final result = SimplexSolver.minimize(
        costs: [2, 3],
        constraints: [
          const LpConstraint([1, 1], ConstraintType.greaterOrEqual, 10),
          const LpConstraint([1, 0], ConstraintType.lessOrEqual, 15),
          const LpConstraint([0, 1], ConstraintType.lessOrEqual, 15),
        ],
      );
      expect(result.feasible, isTrue);
      expect(result.objectiveValue, closeTo(20, 1e-6));
      expect(result.solution[0], closeTo(10, 1e-6));
      expect(result.solution[1], closeTo(0, 1e-6));
    });

    test('equality constraint pins the sum regardless of individual costs', () {
      // minimize x + y s.t. x + y = 10, x <= 8, y <= 8. Objective is fixed
      // at 10 by the equality constraint no matter how x/y split.
      final result = SimplexSolver.minimize(
        costs: [1, 1],
        constraints: [
          const LpConstraint([1, 1], ConstraintType.equal, 10),
          const LpConstraint([1, 0], ConstraintType.lessOrEqual, 8),
          const LpConstraint([0, 1], ConstraintType.lessOrEqual, 8),
        ],
      );
      expect(result.feasible, isTrue);
      expect(result.objectiveValue, closeTo(10, 1e-6));
      expect(result.solution[0] + result.solution[1], closeTo(10, 1e-6));
    });

    test('mixed <=, >=, and = constraints together', () {
      // minimize x + 2y s.t. x + y = 10, x >= 3, y <= 6.
      // y is twice as expensive as x, so the optimum drives y to its
      // lowest allowed value (0, unconstrained below) and puts everything
      // into x: x=10, y=0, cost=10. x>=3 and y<=6 both hold without
      // binding.
      final result = SimplexSolver.minimize(
        costs: [1, 2],
        constraints: [
          const LpConstraint([1, 1], ConstraintType.equal, 10),
          const LpConstraint([1, 0], ConstraintType.greaterOrEqual, 3),
          const LpConstraint([0, 1], ConstraintType.lessOrEqual, 6),
        ],
      );
      expect(result.feasible, isTrue);
      expect(result.solution[0], closeTo(10, 1e-6));
      expect(result.solution[1], closeTo(0, 1e-6));
      expect(result.objectiveValue, closeTo(10, 1e-6));
    });

    test('an over-constrained system is reported infeasible', () {
      // x + y <= 5 and x + y >= 10 can never both hold for x,y >= 0.
      final result = SimplexSolver.minimize(
        costs: [1, 1],
        constraints: [
          const LpConstraint([1, 1], ConstraintType.lessOrEqual, 5),
          const LpConstraint([1, 1], ConstraintType.greaterOrEqual, 10),
        ],
      );
      expect(result.feasible, isFalse);
    });

    test('a negative rhs constraint is normalized correctly', () {
      // -x <= -4  =>  x >= 4. minimize x subject to that alone (plus an
      // upper bound to keep it bounded) should land exactly on x = 4.
      final result = SimplexSolver.minimize(
        costs: [1],
        constraints: [
          const LpConstraint([-1], ConstraintType.lessOrEqual, -4),
          const LpConstraint([1], ConstraintType.lessOrEqual, 20),
        ],
      );
      expect(result.feasible, isTrue);
      expect(result.solution[0], closeTo(4, 1e-6));
      expect(result.objectiveValue, closeTo(4, 1e-6));
    });

    test('a redundant/degenerate equality constraint does not break the solve', () {
      // x + y = 10 stated twice (redundant) plus a real bound.
      final result = SimplexSolver.minimize(
        costs: [1, 1],
        constraints: [
          const LpConstraint([1, 1], ConstraintType.equal, 10),
          const LpConstraint([1, 1], ConstraintType.equal, 10),
          const LpConstraint([1, 0], ConstraintType.lessOrEqual, 6),
        ],
      );
      expect(result.feasible, isTrue);
      expect(result.objectiveValue, closeTo(10, 1e-6));
    });

    test('three-variable problem mirroring a tiny diet-style formulation', () {
      // Three foods with protein contributions [0.1, 0.3, 0.05] per lb and
      // costs [1, 2, 0.5]. Need total weight = 10 lb (equality) and total
      // protein >= 2 lb. Cheapest way to hit protein floor is to lean on
      // food 2 (highest protein per cost among the two cheaper options) up
      // to what's needed, filling the rest with the cheapest food.
      final result = SimplexSolver.minimize(
        costs: [1, 2, 0.5],
        constraints: [
          const LpConstraint([1, 1, 1], ConstraintType.equal, 10),
          const LpConstraint([0.1, 0.3, 0.05], ConstraintType.greaterOrEqual, 2),
        ],
      );
      expect(result.feasible, isTrue);
      final w = result.solution;
      expect(w[0] + w[1] + w[2], closeTo(10, 1e-6));
      expect(0.1 * w[0] + 0.3 * w[1] + 0.05 * w[2], greaterThanOrEqualTo(2 - 1e-6));
      expect(w.every((v) => v >= -1e-6), isTrue);
    });

    test('no constraints at all: bounded at zero when every cost is non-negative', () {
      final result = SimplexSolver.minimize(costs: [1, 2], constraints: []);
      expect(result.feasible, isTrue);
      expect(result.solution, [0.0, 0.0]);
      expect(result.objectiveValue, closeTo(0, 1e-6));
    });

    test('no constraints at all: unbounded (infeasible) when a cost is negative', () {
      final result = SimplexSolver.minimize(costs: [-1], constraints: []);
      expect(result.feasible, isFalse);
    });
  });
}
