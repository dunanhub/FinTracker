import 'package:fin_tracker/domain/entities/debt.dart';
import 'package:fin_tracker/presentation/controllers/budget_controller.dart';
import 'package:fin_tracker/presentation/controllers/debt_controller.dart';
import 'package:fin_tracker/presentation/controllers/goal_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_repositories.dart';

void main() {
  test(
    'budget create, duplicate protection, update and delete persist',
    () async {
      final repository = FakeBudgetRepository();
      final controller = BudgetController(repository: repository);
      await controller.load();

      expect(
        await controller.addBudget(categoryId: 'food', monthlyLimit: 500),
        isTrue,
      );
      expect(
        await controller.addBudget(categoryId: 'food', monthlyLimit: 600),
        isFalse,
      );
      expect(
        await controller.addBudget(categoryId: 'travel', monthlyLimit: 0),
        isFalse,
      );
      final id = controller.budgets.single.id;
      expect(repository.values.single.monthlyLimit, 500);
      expect(
        await controller.updateBudget(
          id: id,
          categoryId: 'food',
          monthlyLimit: 750,
          enabled: false,
        ),
        isTrue,
      );
      expect(controller.budgetById(id)!.monthlyLimit, 750);
      expect(controller.budgetForCategory('food')!.enabled, isFalse);
      expect(await controller.deleteBudget(id), isTrue);
      expect(repository.values, isEmpty);
      expect(await controller.deleteBudget(id), isFalse);
    },
  );

  test(
    'goal contribution, completion and linked account edits persist',
    () async {
      final repository = FakeGoalRepository();
      final controller = GoalController(repository: repository);
      await controller.load();
      final deadline = DateTime.now().add(const Duration(days: 90));

      expect(
        await controller.addGoal(
          name: ' Trip ',
          targetAmount: 1000,
          currentAmount: 250,
          deadline: deadline,
          linkedAccountId: 'savings',
        ),
        isTrue,
      );
      final id = controller.goals.single.id;
      expect(controller.goals.single.name, 'Trip');
      expect(controller.goals.single.linkedAccountId, 'savings');
      expect(controller.remaining(controller.goals.single), 750);
      expect(controller.progress(controller.goals.single), 0.25);
      expect(await controller.addMoney(id: id, amount: 800), isFalse);
      expect(await controller.addMoney(id: id, amount: 250), isTrue);
      expect(repository.values.single.currentAmount, 500);

      expect(
        await controller.updateGoal(
          id: id,
          name: 'Trip 2',
          targetAmount: 1200,
          currentAmount: 500,
          deadline: deadline,
        ),
        isTrue,
      );
      expect(controller.goals.single.linkedAccountId, isNull);
      expect(await controller.addMoney(id: id, amount: 700), isTrue);
      expect(controller.goals.single.currentAmount, 1200);
      expect(controller.progress(controller.goals.single), 1);
      expect(controller.monthlyRequired(controller.goals.single), 0);
      expect(await controller.addMoney(id: id, amount: 1), isFalse);
      expect(await controller.deleteGoal(id), isTrue);
      expect(repository.values, isEmpty);
    },
  );

  test(
    'both debt directions, partial/full payment and edit preserve paid sum',
    () async {
      final repository = FakeDebtRepository();
      final controller = DebtController(repository: repository);
      await controller.load();

      expect(
        await controller.addDebt(
          type: DebtType.iOwe,
          person: 'Alex',
          amount: 1000,
        ),
        isTrue,
      );
      expect(
        await controller.addDebt(
          type: DebtType.owedToMe,
          person: 'Dana',
          amount: 400,
        ),
        isTrue,
      );
      expect(controller.totalIOwe, 1000);
      expect(controller.totalOwedToMe, 400);
      final owedId =
          controller.debts.firstWhere((d) => d.type == DebtType.iOwe).id;
      expect(
        await controller.addPayment(
          debtId: owedId,
          amount: 300,
          accountId: 'cash',
          transactionId: 'payment-tx',
        ),
        isTrue,
      );
      final partlyPaid = controller.debtById(owedId)!;
      expect(partlyPaid.remainingAmount, 700);
      expect(partlyPaid.paidAmount, 300);
      expect(partlyPaid.progress, 0.3);
      expect(partlyPaid.payments.single.transactionId, 'payment-tx');
      expect(await controller.addPayment(debtId: owedId, amount: 701), isFalse);

      expect(
        await controller.updateDebt(
          id: owedId,
          type: DebtType.iOwe,
          person: 'Alex',
          amount: 800,
        ),
        isTrue,
      );
      expect(controller.debtById(owedId)!.remainingAmount, 500);
      expect(await controller.addPayment(debtId: owedId, amount: 500), isTrue);
      expect(controller.debtById(owedId)!.isPaid, isTrue);
      expect(controller.totalIOwe, 0);
      expect(await controller.addPayment(debtId: owedId, amount: 1), isFalse);
      expect(
        repository.values.firstWhere((d) => d.id == owedId).payments,
        hasLength(2),
      );
      expect(await controller.deleteDebt(owedId), isTrue);
      expect(controller.totalOwedToMe, 400);
    },
  );
}
