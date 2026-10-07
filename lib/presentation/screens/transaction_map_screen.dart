import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../data/services/location_service.dart';
import '../../domain/entities/finance_transaction.dart';
import '../controllers/finance_controller.dart';

class TransactionMapScreen extends StatefulWidget {
  const TransactionMapScreen({super.key});

  @override
  State<TransactionMapScreen> createState() => _TransactionMapScreenState();
}

class _TransactionMapScreenState extends State<TransactionMapScreen> {
  final LocationService _locationService = LocationService();

  final MapController _mapController = MapController();

  bool _loadingLocation = false;

  String? _error;

  LatLng? _currentLocation;

  final LatLng _initialPosition = const LatLng(43.238949, 76.889709);

  @override
  void dispose() {
    _mapController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final allTransactions = finance.transactions;

    final transactions =
        allTransactions
            .where(
              (transaction) =>
                  transaction.latitude != null && transaction.longitude != null,
            )
            .toList();

    final markers = <Marker>[
      for (final transaction in transactions)
        Marker(
          point: LatLng(transaction.latitude!, transaction.longitude!),
          width: 46,
          height: 46,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              _showTransaction(context, finance, transaction);
            },
            child: _TransactionMarker(transaction: transaction),
          ),
        ),
      if (_currentLocation != null)
        Marker(
          point: _currentLocation!,
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(blurRadius: 8, color: Colors.black26),
              ],
            ),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта операций'),
        actions: [
          IconButton(
            tooltip: 'Добавить геолокацию',
            onPressed: () {
              _showAttachSheet(finance);
            },
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 12,
              minZoom: 3,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fin_tracker',
                maxNativeZoom: 19,
              ),

              MarkerLayer(markers: markers),

              SimpleAttributionWidget(
                source: const Text('OpenStreetMap contributors'),
                backgroundColor: Colors.white70,
              ),
            ],
          ),

          if (_loadingLocation)
            const Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: LinearProgressIndicator(),
            ),

          if (_error != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _ErrorCard(
                message: _error!,
                onClose: () {
                  setState(() {
                    _error = null;
                  });
                },
              ),
            ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: _MapSummaryCard(
              placed: transactions.length,
              total: allTransactions.length,
              onAttach: () {
                _showAttachSheet(finance);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 92),
        child: FloatingActionButton(
          heroTag: 'current-location',
          onPressed: _moveToCurrentLocation,
          child: const Icon(Icons.my_location_rounded),
        ),
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    if (_loadingLocation) {
      return;
    }

    setState(() {
      _loadingLocation = true;
      _error = null;
    });

    try {
      final position = await _locationService.getCurrentPosition();

      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = location;
      });

      _mapController.move(location, 16);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _showAttachSheet(FinanceController finance) async {
    final transactions =
        finance.transactions
            .where(
              (transaction) =>
                  transaction.latitude == null || transaction.longitude == null,
            )
            .toList();

    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Все операции уже имеют геолокацию.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Привязать место',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];

                      return ListTile(
                        leading: Icon(_iconForType(transaction.type)),
                        title: Text(transaction.title),
                        subtitle: Text(
                          '${finance.categoryName(transaction.categoryId)}'
                          ' • '
                          '${transaction.amount.toStringAsFixed(0)} ₸',
                        ),
                        trailing: const Icon(Icons.location_on_outlined),
                        onTap: () async {
                          Navigator.of(sheetContext).pop();

                          await _attachCurrentLocation(finance, transaction);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _attachCurrentLocation(
    FinanceController finance,
    FinanceTransaction transaction,
  ) async {
    if (_loadingLocation) {
      return;
    }

    setState(() {
      _loadingLocation = true;
      _error = null;
    });

    try {
      final position = await _locationService.getCurrentPosition();

      final location = LatLng(position.latitude, position.longitude);

      final success = await finance.setTransactionLocation(
        transactionId: transaction.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!success) {
        throw const LocationException('Операция не найдена.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = location;
      });

      _mapController.move(location, 16);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Место добавлено к операции '
              '«${transaction.title}»',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  void _showTransaction(
    BuildContext context,
    FinanceController finance,
    FinanceTransaction transaction,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TransactionIcon(type: transaction.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        transaction.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                _InfoRow(
                  icon: Icons.category_outlined,
                  value: finance.categoryName(transaction.categoryId),
                ),

                const SizedBox(height: 10),

                _InfoRow(
                  icon: Icons.payments_outlined,
                  value: '${transaction.amount.toStringAsFixed(0)} ₸',
                ),

                const SizedBox(height: 10),

                _InfoRow(
                  icon: Icons.account_balance_wallet_outlined,
                  value: finance.accountName(transaction.accountId),
                ),

                const SizedBox(height: 10),

                _InfoRow(
                  icon: Icons.location_on_outlined,
                  value:
                      '${transaction.latitude!.toStringAsFixed(6)}, '
                      '${transaction.longitude!.toStringAsFixed(6)}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconForType(FinanceTransactionType type) {
    switch (type) {
      case FinanceTransactionType.expense:
        return Icons.arrow_upward_rounded;

      case FinanceTransactionType.income:
        return Icons.arrow_downward_rounded;

      case FinanceTransactionType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }
}

class _TransactionMarker extends StatelessWidget {
  final FinanceTransaction transaction;

  const _TransactionMarker({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = switch (transaction.type) {
      FinanceTransactionType.expense => const Color(0xFFE36E7D),
      FinanceTransactionType.income => const Color(0xFF58A882),
      FinanceTransactionType.transfer => const Color(0xFF718FCB),
    };

    final icon = switch (transaction.type) {
      FinanceTransactionType.expense => Icons.arrow_upward_rounded,
      FinanceTransactionType.income => Icons.arrow_downward_rounded,
      FinanceTransactionType.transfer => Icons.swap_horiz_rounded,
    };

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _TransactionIcon extends StatelessWidget {
  final FinanceTransactionType type;

  const _TransactionIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      FinanceTransactionType.expense => Icons.arrow_upward_rounded,
      FinanceTransactionType.income => Icons.arrow_downward_rounded,
      FinanceTransactionType.transfer => Icons.swap_horiz_rounded,
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _MapSummaryCard extends StatelessWidget {
  final int placed;
  final int total;
  final VoidCallback onAttach;

  const _MapSummaryCard({
    required this.placed,
    required this.total,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
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
                    '$placed из $total операций',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'сохранены с местоположением',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            IconButton(
              tooltip: 'Привязать место',
              onPressed: onAttach,
              icon: const Icon(Icons.add_location_alt_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _ErrorCard({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
