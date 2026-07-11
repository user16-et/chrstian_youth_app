import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../i18n/app_i18n.dart';

/// Full ledger of the user's gateway payment transactions (giving and plan
/// payments), including pending and failed ones. Pending transactions can be
/// re-verified in place.
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.language,
  });

  final ApiClient apiClient;
  final String token;
  final AppLanguage language;

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String _error = '';
  final Set<String> _verifying = {};

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.apiClient.fetchPaymentTransactions(widget.token);
      if (mounted) setState(() { _items = items; _loading = false; _error = ''; });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('HttpException: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _verify(Map<String, dynamic> tx) async {
    final txRef = '${tx['txRef'] ?? ''}';
    if (txRef.isEmpty || _verifying.contains(txRef)) return;
    setState(() => _verifying.add(txRef));
    try {
      final res = await widget.apiClient.verifyPayment(widget.token, txRef);
      final status = '${res['status'] ?? ''}';
      if (!mounted) return;
      setState(() {
        _items = _items.map((t) => '${t['txRef']}' == txRef ? {...t, 'status': status} : t).toList();
        _verifying.remove(txRef);
      });
      if (status != 'paid') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('Still not confirmed. Finish the payment, then check again.',
                'ገና አልተረጋገጠም። ክፍያውን ጨርሰው እንደገና ያረጋግጡ።'))));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _verifying.remove(txRef));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('HttpException: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('Payment history', 'የክፍያ ታሪክ'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _message(_error)
              : _items.isEmpty
                  ? _message(_t('No payments yet.', 'ገና ክፍያ የለም።'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => _tile(_items[i]),
                      ),
                    ),
    );
  }

  Widget _message(String text) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(text,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ),
          ),
        ),
      );

  Widget _tile(Map<String, dynamic> tx) {
    final colors = Theme.of(context).colorScheme;
    final status = '${tx['status'] ?? ''}';
    final amount = tx['amount'] is num ? (tx['amount'] as num) : num.tryParse('${tx['amount']}') ?? 0;
    final currency = '${tx['currency'] ?? 'ETB'}';
    final txRef = '${tx['txRef'] ?? ''}';
    final verifying = _verifying.contains(txRef);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colors.surfaceContainerHighest,
        child: Icon(_purposeIcon('${tx['purpose']}'), color: colors.onSurfaceVariant, size: 20),
      ),
      title: Text(_purposeLabel('${tx['purpose']}'), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_date('${tx['paidAt'] ?? tx['createdAt'] ?? ''}')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_fmt(amount)} $currency', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          verifying
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : _statusChip(colors, status),
        ],
      ),
      onTap: status == 'pending' ? () => _verify(tx) : null,
    );
  }

  Widget _statusChip(ColorScheme colors, String status) {
    final (bg, fg, label) = switch (status) {
      'paid' => (colors.primaryContainer, colors.onPrimaryContainer, _t('Paid', 'ተከፍሏል')),
      'failed' => (colors.errorContainer, colors.onErrorContainer, _t('Failed', 'አልተሳካም')),
      'cancelled' => (colors.surfaceContainerHighest, colors.onSurfaceVariant, _t('Cancelled', 'ተሰርዟል')),
      _ => (colors.tertiaryContainer, colors.onTertiaryContainer, _t('Pending', 'በመጠባበቅ')),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  IconData _purposeIcon(String purpose) => switch (purpose) {
        'donation' => Icons.volunteer_activism_rounded,
        'payment_plan' => Icons.event_repeat_rounded,
        _ => Icons.receipt_long_rounded,
      };

  String _purposeLabel(String purpose) => switch (purpose) {
        'donation' => _t('Giving', 'ልገሳ'),
        'payment_plan' => _t('Plan payment', 'የክፍያ ዕቅድ'),
        _ => _t('Payment', 'ክፍያ'),
      };

  String _fmt(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String _date(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    const monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${monEn[dt.month - 1]} ${dt.day}, ${dt.year} · $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}
