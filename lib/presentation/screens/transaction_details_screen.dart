import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/receipt_image_service.dart';
import '../../domain/entities/finance_transaction.dart';
import '../controllers/finance_controller.dart';
import '../controllers/sync_controller.dart';
import 'edit_transaction_screen.dart';

class TransactionDetailsScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailsScreen({super.key, required this.transactionId});

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  final ReceiptImageService _receiptService = ReceiptImageService();

  bool _working = false;
  bool _loadingReceipt = false;
  bool _receiptDownloadFailed = false;
  String? _requestedStoragePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = context.watch<FinanceController>();
    final transaction = finance.transactionById(widget.transactionId);

    if (transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Операция')),
        body: const Center(child: Text('Операция не найдена')),
      );
    }

    final colors = context.finColors;
    final appearance = _appearance(transaction.type, colors);
    final receiptPath = transaction.receiptPath;
    final storagePath = transaction.receiptStoragePath;
    final receiptAvailable =
        receiptPath != null && File(receiptPath).existsSync();
    if (storagePath != null &&
        !receiptAvailable &&
        !_loadingReceipt &&
        _requestedStoragePath != storagePath) {
      _requestedStoragePath = storagePath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _downloadReceipt();
      });
    }
    final hasLocation =
        transaction.latitude != null && transaction.longitude != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Операция'),
        actions: [
          IconButton(
            tooltip: 'Редактировать',
            onPressed: _working ? null : () => _openEdit(transaction),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            enabled: !_working,
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDelete(transaction);
              }
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded),
                        SizedBox(width: 10),
                        Text('Удалить операцию'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            _HeroCard(
              transaction: transaction,
              finance: finance,
              color: appearance.color,
              icon: appearance.icon,
            ),

            const SizedBox(height: 18),

            _SectionTitle(title: 'Детали'),

            const SizedBox(height: 10),

            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label:
                      transaction.type == FinanceTransactionType.income
                          ? 'Счёт поступления'
                          : 'Счёт',
                  value: finance.accountName(transaction.accountId),
                ),
                if (transaction.type == FinanceTransactionType.transfer) ...[
                  const _CardDivider(),
                  _InfoRow(
                    icon: Icons.south_east_rounded,
                    label: 'Счёт назначения',
                    value: finance.accountName(
                      transaction.destinationAccountId,
                    ),
                  ),
                ] else ...[
                  const _CardDivider(),
                  _InfoRow(
                    icon: Icons.category_outlined,
                    label: 'Категория',
                    value: finance.categoryName(transaction.categoryId),
                  ),
                ],
                if (transaction.person != null &&
                    transaction.person!.trim().isNotEmpty) ...[
                  const _CardDivider(),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Кому / от кого',
                    value: transaction.person!,
                  ),
                ],
                const _CardDivider(),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Дата',
                  value: _formatDateTime(transaction.date),
                ),
              ],
            ),

            if (transaction.description != null &&
                transaction.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionTitle(title: 'Комментарий'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  transaction.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],

            const SizedBox(height: 18),

            _SectionTitle(title: 'Чек'),

            const SizedBox(height: 10),

            if (receiptPath == null && storagePath == null)
              _EmptyReceiptCard(working: _working, onAdd: _showReceiptSource)
            else
              _ReceiptCard(
                path: receiptPath,
                hasCloudCopy: storagePath != null,
                loading: _loadingReceipt,
                downloadFailed: _receiptDownloadFailed,
                working: _working,
                onOpen:
                    receiptAvailable ? () => _openReceipt(receiptPath) : null,
                onRetry: _downloadReceipt,
                onReplace: _showReceiptSource,
                onDelete: () => _removeReceipt(receiptPath),
              ),

            const SizedBox(height: 18),

            _SectionTitle(title: 'Место'),

            const SizedBox(height: 10),

            if (hasLocation)
              _LocationCard(
                latitude: transaction.latitude!,
                longitude: transaction.longitude!,
              )
            else
              const _NoLocationCard(),

            const SizedBox(height: 22),

            OutlinedButton.icon(
              onPressed: _working ? null : () => _openEdit(transaction),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Редактировать операцию'),
            ),

            const SizedBox(height: 10),

            TextButton.icon(
              onPressed: _working ? null : () => _confirmDelete(transaction),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
              label: Text(
                'Удалить операцию',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEdit(FinanceTransaction transaction) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EditTransactionScreen(transaction: transaction),
      ),
    );
  }

  Future<void> _showReceiptSource() async {
    if (_working) {
      return;
    }

    final source = await showModalBottomSheet<ReceiptImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Сделать фото'),
                  onTap: () {
                    Navigator.of(context).pop(ReceiptImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Выбрать из галереи'),
                  onTap: () {
                    Navigator.of(context).pop(ReceiptImageSource.gallery);
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

    await _replaceReceipt(source);
  }

  Future<void> _replaceReceipt(ReceiptImageSource source) async {
    setState(() {
      _working = true;
    });

    final finance = context.read<FinanceController>();
    final oldPath = finance.transactionById(widget.transactionId)?.receiptPath;

    try {
      final newPath = await _receiptService.pick(source);

      if (newPath == null) {
        return;
      }

      final success = await finance.setTransactionReceipt(
        transactionId: widget.transactionId,
        receiptPath: newPath,
      );

      if (!success) {
        await _receiptService.delete(newPath);
        throw StateError('Операция не найдена');
      }

      if (oldPath != null && oldPath != newPath) {
        await _receiptService.delete(oldPath);
      }

      if (!mounted) {
        return;
      }

      _showMessage('Чек сохранён');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Не удалось сохранить чек: $error', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _downloadReceipt() async {
    if (_loadingReceipt) return;
    setState(() {
      _loadingReceipt = true;
      _receiptDownloadFailed = false;
    });
    final success = await context.read<SyncController>().ensureReceiptCached(
      widget.transactionId,
    );
    if (!mounted) return;
    setState(() {
      _loadingReceipt = false;
      _receiptDownloadFailed = !success;
    });
  }

  Future<void> _removeReceipt(String? path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить чек?'),
          content: const Text(
            'Фото будет удалено с устройства и из облака при синхронизации.',
          ),
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
      _working = true;
    });

    final finance = context.read<FinanceController>();

    try {
      final success = await finance.setTransactionReceipt(
        transactionId: widget.transactionId,
        receiptPath: null,
      );

      if (!success) {
        throw StateError('Операция не найдена');
      }

      await _receiptService.delete(path);

      if (!mounted) {
        return;
      }

      _showMessage('Чек удалён');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Не удалось удалить чек: $error', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _confirmDelete(FinanceTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить операцию?'),
          content: Text(
            '«${transaction.title}» будет удалена, '
            'а баланс счёта пересчитается.',
          ),
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
      _working = true;
    });

    final finance = context.read<FinanceController>();

    try {
      final success = await finance.deleteTransaction(transaction.id);

      if (!success) {
        throw StateError('Операция не найдена');
      }

      await _receiptService.delete(transaction.receiptPath);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _working = false;
      });

      _showMessage('Не удалось удалить операцию: $error', error: true);
    }
  }

  void _openReceipt(String path) {
    final file = File(path);

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => _ReceiptViewer(file: file)),
    );
  }

  void _showMessage(String message, {bool error = false}) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? theme.colorScheme.error : null,
        ),
      );
  }
}

class _HeroCard extends StatelessWidget {
  final FinanceTransaction transaction;
  final FinanceController finance;
  final Color color;
  final IconData icon;

  const _HeroCard({
    required this.transaction,
    required this.finance,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(height: 14),
          Text(
            transaction.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            _amountText(transaction),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _subtitle(transaction, finance),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _EmptyReceiptCard extends StatelessWidget {
  final bool working;
  final VoidCallback onAdd;

  const _EmptyReceiptCard({required this.working, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Чек не прикреплён', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Можно сделать фото или выбрать изображение',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Добавить чек',
            onPressed: working ? null : onAdd,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final String? path;
  final bool hasCloudCopy;
  final bool loading;
  final bool downloadFailed;
  final bool working;
  final VoidCallback? onOpen;
  final VoidCallback onRetry;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  const _ReceiptCard({
    required this.path,
    required this.hasCloudCopy,
    required this.loading,
    required this.downloadFailed,
    required this.working,
    required this.onOpen,
    required this.onRetry,
    required this.onReplace,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = path == null ? null : File(path!);
    final exists = file?.existsSync() ?? false;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (exists)
            InkWell(
              onTap: onOpen,
              child: SizedBox(
                width: double.infinity,
                height: 210,
                child: Image.file(
                  file!,
                  fit: BoxFit.cover,
                  cacheWidth: ((MediaQuery.sizeOf(context).width - 40) *
                          MediaQuery.devicePixelRatioOf(context))
                      .round()
                      .clamp(1, 1200),
                  errorBuilder: (context, error, stackTrace) {
                    return const _MissingReceipt();
                  },
                ),
              ),
            )
          else
            const SizedBox(height: 150, child: _MissingReceipt()),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    exists
                        ? 'Нажми на фото, чтобы открыть'
                        : loading
                        ? 'Загружаем чек...'
                        : hasCloudCopy
                        ? downloadFailed
                            ? 'Чек недоступен. Повтори загрузку.'
                            : 'Чек хранится в облаке'
                        : 'Файл чека не найден на устройстве',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (!exists && hasCloudCopy)
                  IconButton(
                    tooltip: 'Повторить загрузку чека',
                    onPressed: loading || working ? null : onRetry,
                    icon: const Icon(Icons.cloud_download_outlined),
                  ),
                IconButton(
                  tooltip: 'Заменить',
                  onPressed: working ? null : onReplace,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: 'Удалить',
                  onPressed: working ? null : onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingReceipt extends StatelessWidget {
  const _MissingReceipt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: theme.colorScheme.onSurfaceVariant,
            size: 34,
          ),
          const SizedBox(height: 8),
          Text('Изображение недоступно', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final double latitude;
  final double longitude;

  const _LocationCard({required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.location_on_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Местоположение сохранено',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                SelectableText(
                  '${latitude.toStringAsFixed(6)}, '
                  '${longitude.toStringAsFixed(6)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoLocationCard extends StatelessWidget {
  const _NoLocationCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_off_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Для этой операции место не сохранено.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptViewer extends StatelessWidget {
  final File file;

  const _ReceiptViewer({required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Чек'),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'Не удалось открыть изображение',
                  style: TextStyle(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionAppearance {
  final IconData icon;
  final Color color;

  const _TransactionAppearance({required this.icon, required this.color});
}

_TransactionAppearance _appearance(
  FinanceTransactionType type,
  FinThemeColors colors,
) {
  switch (type) {
    case FinanceTransactionType.expense:
      return _TransactionAppearance(
        icon: Icons.north_east_rounded,
        color: colors.expense,
      );
    case FinanceTransactionType.income:
      return _TransactionAppearance(
        icon: Icons.south_west_rounded,
        color: colors.income,
      );
    case FinanceTransactionType.transfer:
      return _TransactionAppearance(
        icon: Icons.swap_horiz_rounded,
        color: colors.transfer,
      );
  }
}

String _subtitle(FinanceTransaction transaction, FinanceController finance) {
  if (transaction.type == FinanceTransactionType.transfer) {
    return '${finance.accountName(transaction.accountId)}'
        ' → '
        '${finance.accountName(transaction.destinationAccountId)}';
  }

  return '${finance.categoryName(transaction.categoryId)}'
      ' · '
      '${finance.accountName(transaction.accountId)}';
}

String _amountText(FinanceTransaction transaction) {
  final amount = _formatAmount(transaction.amount);

  switch (transaction.type) {
    case FinanceTransactionType.expense:
      return '-$amount ₸';
    case FinanceTransactionType.income:
      return '+$amount ₸';
    case FinanceTransactionType.transfer:
      return '$amount ₸';
  }
}

String _formatAmount(double value) {
  final integer = value.round().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < integer.length; i++) {
    final remaining = integer.length - i;
    buffer.write(integer[i]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }

  return buffer.toString();
}

String _formatDateTime(DateTime date) {
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

  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');

  return '${date.day} ${months[date.month - 1]} ${date.year}, '
      '$hour:$minute';
}
