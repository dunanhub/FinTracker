import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/services/location_service.dart';
import '../../data/services/receipt_image_service.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/finance_transaction.dart';
import '../controllers/finance_controller.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  FinanceTransactionType _type = FinanceTransactionType.expense;

  final TextEditingController _amountController = TextEditingController();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _personController = TextEditingController();

  final TextEditingController _noteController = TextEditingController();

  final ReceiptImageService _receiptImageService = ReceiptImageService();
  final LocationService _locationService = LocationService();

  String? _receiptPath;
  double? _latitude;
  double? _longitude;

  bool _pickingReceipt = false;
  bool _loadingLocation = false;

  String? _accountId;
  String? _destinationAccountId;

  String _categoryId = 'food';

  bool _accountsInitialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_accountsInitialized) {
      return;
    }

    final finance = context.read<FinanceController>();
    final accounts = finance.accounts;

    if (accounts.isNotEmpty) {
      _accountId = accounts.first.id;

      if (accounts.length > 1) {
        _destinationAccountId = accounts[1].id;
      }
    }

    _accountsInitialized = true;
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
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Новая операция'),
      ),
      body:
          accounts.isEmpty
              ? const _NoAccountsState()
              : SafeArea(
                top: false,
                bottom: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 20,
                    8,
                    compact ? 16 : 20,
                    130,
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
                                      style: theme.textTheme.headlineLarge
                                          ?.copyWith(
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
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      _SectionTitle(
                        title:
                            _type == FinanceTransactionType.transfer
                                ? 'Перевод'
                                : 'Детали',
                      ),

                      const SizedBox(height: 12),

                      _FieldCard(
                        child: Column(
                          children: [
                            _AccountDropdown(
                              label:
                                  _type == FinanceTransactionType.income
                                      ? 'Куда поступят деньги'
                                      : 'Счёт списания',
                              value: _accountId,
                              accounts: accounts,
                              onChanged: (value) {
                                setState(() {
                                  _accountId = value;

                                  if (_type ==
                                          FinanceTransactionType.transfer &&
                                      _destinationAccountId == value) {
                                    final alternatives =
                                        accounts
                                            .where(
                                              (account) => account.id != value,
                                            )
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
                                label: 'Куда перевести',
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

                      _SectionTitle(title: 'Описание'),

                      const SizedBox(height: 12),

                      TextField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Название операции',
                          hintText: _titleHint(),
                          prefixIcon: const Icon(Icons.edit_outlined),
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
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 2,
                        maxLines: 4,
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

                      const SizedBox(height: 18),

                      if (_receiptPath != null) ...[
                        _ReceiptPreview(
                          path: _receiptPath!,
                          onRemove: _pickingReceipt ? null : _removeReceipt,
                        ),
                        const SizedBox(height: 10),
                      ],

                      _OptionalAction(
                        icon: Icons.camera_alt_outlined,
                        title:
                            _receiptPath == null
                                ? 'Добавить чек'
                                : 'Изменить чек',
                        subtitle:
                            _pickingReceipt
                                ? 'Открываем изображение...'
                                : _receiptPath == null
                                ? 'Сфотографировать или выбрать из галереи'
                                : 'Чек добавлен к операции',
                        onTap: _pickingReceipt ? () {} : _chooseReceipt,
                      ),

                      const SizedBox(height: 10),

                      _OptionalAction(
                        icon: Icons.location_on_outlined,
                        title:
                            _latitude == null
                                ? 'Добавить место'
                                : 'Обновить место',
                        subtitle:
                            _loadingLocation
                                ? 'Определяем местоположение...'
                                : _latitude == null || _longitude == null
                                ? 'Геолокация операции'
                                : '${_latitude!.toStringAsFixed(5)}, '
                                    '${_longitude!.toStringAsFixed(5)}',
                        onTap: _loadingLocation ? () {} : _addCurrentLocation,
                      ),
                    ],
                  ),
                ),
              ),
      bottomNavigationBar:
          accounts.isEmpty ? null : _SaveArea(saving: _saving, onSave: _save),
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
        final sourceId = _accountId;

        final alternatives =
            accounts.where((account) => account.id != sourceId).toList();

        _destinationAccountId =
            alternatives.isEmpty ? null : alternatives.first.id;
      }
    });
  }

  String _titleHint() {
    switch (_type) {
      case FinanceTransactionType.expense:
        return 'Например, ужин';

      case FinanceTransactionType.income:
        return 'Например, зарплата';

      case FinanceTransactionType.transfer:
        return 'Например, на депозит';
    }
  }

  Future<void> _chooseReceipt() async {
    final source = await showModalBottomSheet<ReceiptImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Сделать фото'),
                  subtitle: const Text('Открыть камеру'),
                  onTap: () {
                    Navigator.of(sheetContext).pop(ReceiptImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Выбрать из галереи'),
                  subtitle: const Text('Использовать готовое изображение'),
                  onTap: () {
                    Navigator.of(sheetContext).pop(ReceiptImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    setState(() {
      _pickingReceipt = true;
    });

    try {
      final newPath = await _receiptImageService.pick(source);

      if (newPath == null || !mounted) {
        return;
      }

      final oldPath = _receiptPath;

      setState(() {
        _receiptPath = newPath;
      });

      if (oldPath != null && oldPath != newPath) {
        await _receiptImageService.delete(oldPath);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Не удалось добавить чек');
    } finally {
      if (mounted) {
        setState(() {
          _pickingReceipt = false;
        });
      }
    }
  }

  Future<void> _removeReceipt() async {
    final path = _receiptPath;

    if (path == null) {
      return;
    }

    setState(() {
      _receiptPath = null;
    });

    await _receiptImageService.delete(path);
  }

  Future<void> _addCurrentLocation() async {
    if (_loadingLocation) {
      return;
    }

    setState(() {
      _loadingLocation = true;
    });

    try {
      final position = await _locationService.getCurrentPosition();

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Местоположение добавлено'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final finance = context.read<FinanceController>();

    final accounts = finance.accounts;

    if (accounts.isEmpty) {
      _showError('Сначала добавь хотя бы один счёт');

      return;
    }

    var sourceAccountId = _accountId;

    if (sourceAccountId == null ||
        !accounts.any((account) => account.id == sourceAccountId)) {
      sourceAccountId = accounts.first.id;
    }

    String? destinationId = _destinationAccountId;

    if (_type == FinanceTransactionType.transfer) {
      final alternatives =
          accounts.where((account) => account.id != sourceAccountId).toList();

      if (alternatives.isEmpty) {
        _showError('Для перевода нужно минимум два счёта');

        return;
      }

      if (destinationId == null ||
          destinationId == sourceAccountId ||
          !alternatives.any((account) => account.id == destinationId)) {
        destinationId = alternatives.first.id;
      }
    }

    final normalized = _amountController.text
        .replaceAll(',', '.')
        .replaceAll(' ', '');

    final amount = double.tryParse(normalized);

    if (amount == null || amount <= 0) {
      _showError('Введите сумму операции');

      return;
    }

    var title = _titleController.text.trim();

    if (title.isEmpty) {
      switch (_type) {
        case FinanceTransactionType.expense:
        case FinanceTransactionType.income:
          title = finance.categoryName(_categoryId);
          break;

        case FinanceTransactionType.transfer:
          title = 'Перевод';
          break;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      await finance.addTransaction(
        type: _type,
        amount: amount,
        accountId: sourceAccountId,
        destinationAccountId:
            _type == FinanceTransactionType.transfer ? destinationId : null,
        categoryId:
            _type == FinanceTransactionType.transfer ? null : _categoryId,
        title: title,
        person: _personController.text,
        description: _noteController.text,
        date: DateTime.now(),
        receiptPath: _receiptPath,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showError('Не удалось сохранить операцию');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

class _NoAccountsState extends StatelessWidget {
  const _NoAccountsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: theme.colorScheme.primary,
                size: 32,
              ),
            ),

            const SizedBox(height: 18),

            Text('Сначала нужен счёт', style: theme.textTheme.titleLarge),

            const SizedBox(height: 7),

            Text(
              'Добавь карту, наличные или депозит в разделе «Ещё → Счета».',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
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
                '$label-$selectedValue-'
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
                      child: Row(
                        children: [
                          Icon(
                            _accountTypeIcon(account.type),
                            size: 17,
                            color: theme.colorScheme.primary,
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              account.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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

class _ReceiptPreview extends StatelessWidget {
  final String path;
  final VoidCallback? onRemove;

  const _ReceiptPreview({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(path);

    return Container(
      height: 180,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (file.existsSync())
            Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: ((MediaQuery.sizeOf(context).width - 40) *
                      MediaQuery.devicePixelRatioOf(context))
                  .round()
                  .clamp(1, 1200),
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image_outlined, size: 34),
                );
              },
            )
          else
            const Center(child: Icon(Icons.broken_image_outlined, size: 34)),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Удалить чек',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionalAction extends StatelessWidget {
  final IconData icon;

  final String title;
  final String subtitle;

  final VoidCallback onTap;

  const _OptionalAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
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
  final VoidCallback onSave;

  const _SaveArea({required this.saving, required this.onSave});

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
          onPressed: saving ? null : onSave,
          icon:
              saving
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.check_rounded),
          label: Text(saving ? 'Сохраняем...' : 'Сохранить операцию'),
        ),
      ),
    );
  }
}

IconData _accountTypeIcon(AccountType type) {
  switch (type) {
    case AccountType.card:
      return Icons.credit_card_rounded;

    case AccountType.cash:
      return Icons.payments_outlined;

    case AccountType.deposit:
      return Icons.account_balance_outlined;

    case AccountType.savings:
      return Icons.savings_outlined;

    case AccountType.other:
      return Icons.wallet_outlined;
  }
}
