import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/services/receipt_image_service.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/finance_transaction.dart';
import '../controllers/finance_controller.dart';

class EditTransactionScreen extends StatefulWidget {
  final FinanceTransaction transaction;

  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late FinanceTransactionType _type;

  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _personController;
  late final TextEditingController _noteController;

  late String _accountId;
  String? _destinationAccountId;

  late String _categoryId;

  late DateTime _date;

  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    _type = transaction.type;

    _amountController = TextEditingController(
      text: _numberText(transaction.amount),
    );

    _titleController = TextEditingController(text: transaction.title);

    _personController = TextEditingController(text: transaction.person ?? '');

    _noteController = TextEditingController(
      text: transaction.description ?? '',
    );

    _accountId = transaction.accountId;

    _destinationAccountId = transaction.destinationAccountId;

    _categoryId =
        transaction.categoryId ??
        (_type == FinanceTransactionType.income ? 'salary' : 'food');

    _date = transaction.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _personController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final finance = context.watch<FinanceController>();

    final accounts = finance.accounts;

    final width = MediaQuery.sizeOf(context).width;

    final compact = width < 360;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Операция')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 20,
            8,
            compact ? 16 : 20,
            150,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeSelector(value: _type, onChanged: _changeType),

              const SizedBox(height: 30),

              Center(
                child: Column(
                  children: [
                    Text('Сумма', style: theme.textTheme.bodyMedium),

                    const SizedBox(height: 7),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: IntrinsicWidth(
                            child: TextField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontSize: compact ? 32 : 38,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 7),

                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '₸',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Text(
                _type == FinanceTransactionType.transfer ? 'Перевод' : 'Детали',
                style: theme.textTheme.titleMedium,
              ),

              const SizedBox(height: 12),

              _FieldCard(
                child: Column(
                  children: [
                    _AccountDropdown(
                      label:
                          _type == FinanceTransactionType.income
                              ? 'Счёт зачисления'
                              : 'Счёт списания',
                      value: _accountId,
                      accounts: accounts,
                      onChanged: (value) {
                        setState(() {
                          _accountId = value;

                          if (_destinationAccountId == value) {
                            final alternatives =
                                accounts
                                    .where((account) => account.id != value)
                                    .toList();

                            _destinationAccountId =
                                alternatives.isEmpty
                                    ? null
                                    : alternatives.first.id;
                          }
                        });
                      },
                    ),

                    if (_type == FinanceTransactionType.transfer) ...[
                      const _FieldDivider(),

                      _AccountDropdown(
                        label: 'Счёт назначения',
                        value: _destinationAccountId,
                        accounts: accounts,
                        excludedId: _accountId,
                        onChanged: (value) {
                          setState(() {
                            _destinationAccountId = value;
                          });
                        },
                      ),
                    ] else ...[
                      const _FieldDivider(),

                      _CategoryDropdown(
                        type: _type,
                        value: _categoryId,
                        onChanged: (value) {
                          setState(() {
                            _categoryId = value;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Text('Дата и время', style: theme.textTheme.titleMedium),

              const SizedBox(height: 12),

              _DateCard(date: _date, onTap: _pickDateTime),

              const SizedBox(height: 18),

              Text('Описание', style: theme.textTheme.titleMedium),

              const SizedBox(height: 12),

              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название операции',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _personController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Кому / от кого',
                  hintText: 'Необязательно',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),

              const SizedBox(height: 12),

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

              const SizedBox(height: 34),

              Text('Опасная зона', style: theme.textTheme.titleMedium),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _deleting || _saving ? null : _requestDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.35),
                    ),
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon:
                      _deleting
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.delete_outline_rounded),
                  label: const Text('Удалить операцию'),
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: _SaveArea(
        saving: _saving,
        deleting: _deleting,
        onSave: _save,
      ),
    );
  }

  void _changeType(FinanceTransactionType type) {
    final accounts = context.read<FinanceController>().accounts;

    setState(() {
      _type = type;

      if (type == FinanceTransactionType.expense) {
        _categoryId = 'food';
      }

      if (type == FinanceTransactionType.income) {
        _categoryId = 'salary';
      }

      if (type == FinanceTransactionType.transfer) {
        final alternatives =
            accounts.where((account) => account.id != _accountId).toList();

        _destinationAccountId =
            alternatives.isEmpty ? null : alternatives.first.id;
      }
    });
  }

  Future<void> _pickDateTime() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _date = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving || _deleting) {
      return;
    }

    final finance = context.read<FinanceController>();

    if (finance.accounts.isEmpty) {
      _showMessage('Нет доступных счетов');

      return;
    }

    final normalized = _amountController.text
        .replaceAll(',', '.')
        .replaceAll(' ', '');

    final amount = double.tryParse(normalized);

    if (amount == null || amount <= 0) {
      _showMessage('Введите корректную сумму');

      return;
    }

    if (_type == FinanceTransactionType.transfer &&
        (_destinationAccountId == null ||
            _destinationAccountId == _accountId)) {
      _showMessage('Выбери другой счёт для перевода');

      return;
    }

    var title = _titleController.text.trim();

    if (title.isEmpty) {
      if (_type == FinanceTransactionType.transfer) {
        title = 'Перевод';
      } else {
        title = finance.categoryName(_categoryId);
      }
    }

    setState(() {
      _saving = true;
    });

    final success = await finance.updateTransaction(
      id: widget.transaction.id,
      type: _type,
      amount: amount,
      accountId: _accountId,
      destinationAccountId:
          _type == FinanceTransactionType.transfer
              ? _destinationAccountId
              : null,
      categoryId: _type == FinanceTransactionType.transfer ? null : _categoryId,
      title: title,
      person: _personController.text,
      description: _noteController.text,
      date: _date,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _saving = false;
      });

      _showMessage('Операция не найдена');

      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _requestDelete() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                    size: 27,
                  ),
                ),

                const SizedBox(height: 16),

                Text('Удалить операцию?', style: theme.textTheme.titleLarge),

                const SizedBox(height: 7),

                Text(
                  'Баланс счёта автоматически пересчитается.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Удалить'),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Отмена'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deleting = true;
    });

    final deleted = await context.read<FinanceController>().deleteTransaction(
      widget.transaction.id,
    );

    if (!mounted) {
      return;
    }

    if (!deleted) {
      setState(() {
        _deleting = false;
      });

      _showMessage('Не удалось удалить операцию');

      return;
    }

    await ReceiptImageService().delete(widget.transaction.receiptPath);
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

class _TypeSelector extends StatelessWidget {
  final FinanceTransactionType value;

  final ValueChanged<FinanceTransactionType> onChanged;

  const _TypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _TypeButton(
            title: 'Расход',
            icon: Icons.north_east_rounded,
            type: FinanceTransactionType.expense,
            selected: value == FinanceTransactionType.expense,
            onTap: onChanged,
          ),
          _TypeButton(
            title: 'Доход',
            icon: Icons.south_west_rounded,
            type: FinanceTransactionType.income,
            selected: value == FinanceTransactionType.income,
            onTap: onChanged,
          ),
          _TypeButton(
            title: 'Перевод',
            icon: Icons.swap_horiz_rounded,
            type: FinanceTransactionType.transfer,
            selected: value == FinanceTransactionType.transfer,
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String title;
  final IconData icon;

  final FinanceTransactionType type;

  final bool selected;

  final ValueChanged<FinanceTransactionType> onTap;

  const _TypeButton({
    required this.title,
    required this.icon,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          onTap(type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<Account> accounts;

  final String? excludedId;

  final ValueChanged<String> onChanged;

  const _AccountDropdown({
    required this.label,
    required this.value,
    required this.accounts,
    required this.onChanged,
    this.excludedId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final availableAccounts =
        accounts.where((account) => account.id != excludedId).toList();

    String? selectedValue;

    if (value != null &&
        availableAccounts.any((account) => account.id == value)) {
      selectedValue = value;
    } else if (availableAccounts.isNotEmpty) {
      selectedValue = availableAccounts.first.id;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: theme.colorScheme.primary,
              size: 19,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                '$label-'
                '$selectedValue-'
                '${availableAccounts.length}',
              ),
              initialValue: selectedValue,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: label,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              items:
                  availableAccounts.map((account) {
                    return DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(
                        account.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
              onChanged:
                  availableAccounts.isEmpty
                      ? null
                      : (newValue) {
                        if (newValue != null) {
                          onChanged(newValue);
                        }
                      },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final FinanceTransactionType type;
  final String value;

  final ValueChanged<String> onChanged;

  const _CategoryDropdown({
    required this.type,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final categories =
        type == FinanceTransactionType.income
            ? FinanceController.incomeCategories
            : FinanceController.expenseCategories;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.category_outlined,
              color: theme.colorScheme.primary,
              size: 19,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey('$type-$value'),
              initialValue: value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Категория',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              items:
                  categories.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final Widget child;

  const _FieldCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _DateCard extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateCard({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  color: theme.colorScheme.primary,
                  size: 19,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateText(date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(_timeText(date), style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),

              Icon(
                Icons.edit_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveArea extends StatelessWidget {
  final bool saving;
  final bool deleting;

  final VoidCallback onSave;

  const _SaveArea({
    required this.saving,
    required this.deleting,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: saving || deleting ? null : onSave,
          icon:
              saving
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.check_rounded),
          label: Text(saving ? 'Сохраняем...' : 'Сохранить изменения'),
        ),
      ),
    );
  }
}

String _numberText(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }

  return value.toString();
}

String _dateText(DateTime date) {
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  return '${date.day} '
      '${months[date.month - 1]} '
      '${date.year}';
}

String _timeText(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');

  final minute = date.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}
