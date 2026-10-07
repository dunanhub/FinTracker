import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/debt.dart';
import '../controllers/debt_controller.dart';

class AddDebtScreen extends StatefulWidget {
  final Debt? debt;

  const AddDebtScreen({super.key, this.debt});

  bool get editing => debt != null;

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  late DebtType _type;

  late final TextEditingController _personController;

  late final TextEditingController _amountController;

  late final TextEditingController _noteController;

  DateTime? _deadline;

  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();

    final debt = widget.debt;

    _type = debt?.type ?? DebtType.iOwe;

    _personController = TextEditingController(text: debt?.person ?? '');

    _amountController = TextEditingController(
      text: debt == null ? '' : _numberText(debt.originalAmount),
    );

    _noteController = TextEditingController(text: debt?.note ?? '');

    _deadline = debt?.deadline;
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Редактировать долг' : 'Новый долг'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                _TypeButton(
                  title: 'Я должен',
                  icon: Icons.north_east_rounded,
                  selected: _type == DebtType.iOwe,
                  onTap: () {
                    setState(() {
                      _type = DebtType.iOwe;
                    });
                  },
                ),
                _TypeButton(
                  title: 'Мне должны',
                  icon: Icons.south_west_rounded,
                  selected: _type == DebtType.owedToMe,
                  onTap: () {
                    setState(() {
                      _type = DebtType.owedToMe;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          TextField(
            controller: _personController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Человек',
              hintText: 'Например, Магжан',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Сумма долга',
              hintText: '100000',
              suffixText: '₸',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),

          const SizedBox(height: 22),

          Text('Срок возврата', style: theme.textTheme.titleMedium),

          const SizedBox(height: 10),

          Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _pickDeadline,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _deadline == null ? 'Без срока' : _dateText(_deadline!),
                      ),
                    ),
                    if (_deadline != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _deadline = null;
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    else
                      const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              hintText: 'Необязательно',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: Icon(Icons.notes_rounded),
              ),
            ),
          ),

          if (widget.editing) ...[
            const SizedBox(height: 34),

            Text('Опасная зона', style: theme.textTheme.titleMedium),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _saving || _deleting ? null : _requestDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                minimumSize: const Size.fromHeight(54),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Удалить долг'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton.icon(
            onPressed: _saving || _deleting ? null : _save,
            icon:
                _saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check_rounded),
            label: Text(
              widget.editing ? 'Сохранить изменения' : 'Добавить долг',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _deadline = selected;
    });
  }

  Future<void> _save() async {
    final person = _personController.text.trim();

    final amount = _parseAmount(_amountController.text);

    if (person.isEmpty) {
      _message('Введите имя человека');
      return;
    }

    if (amount == null || amount <= 0) {
      _message('Введите сумму долга');
      return;
    }

    setState(() {
      _saving = true;
    });

    final controller = context.read<DebtController>();

    final success =
        widget.editing
            ? await controller.updateDebt(
              id: widget.debt!.id,
              type: _type,
              person: person,
              amount: amount,
              deadline: _deadline,
              note: _noteController.text,
            )
            : await controller.addDebt(
              type: _type,
              person: person,
              amount: amount,
              deadline: _deadline,
              note: _noteController.text,
            );

    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _saving = false;
      });

      _message('Не удалось сохранить долг');

      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _requestDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить долг?'),
          content: const Text('История выплат этого долга тоже будет удалена.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deleting = true;
    });

    await context.read<DebtController>().deleteDebt(widget.debt!.id);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
      );
  }
}

class _TypeButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color:
                    selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color:
                      selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double? _parseAmount(String value) {
  return double.tryParse(value.replaceAll(',', '.').replaceAll(' ', ''));
}

String _numberText(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }

  return value.toString();
}

String _dateText(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}
