import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api_client.dart';
import '../../i18n/app_i18n.dart';

/// Opens the Give / checkout flow for a giving fund. Returns `true` if a payment
/// was confirmed (so the caller can refresh).
Future<bool> showGiveSheet(
  BuildContext context, {
  required ApiClient apiClient,
  required String token,
  required String fundId,
  required String fundTitle,
  required AppLanguage language,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _GiveSheet(
        apiClient: apiClient,
        token: token,
        fundId: fundId,
        fundTitle: fundTitle,
        language: language,
      ),
    ),
  );
  return result ?? false;
}

enum _Stage { amount, awaiting, paid, failed }

class _GiveSheet extends StatefulWidget {
  const _GiveSheet({
    required this.apiClient,
    required this.token,
    required this.fundId,
    required this.fundTitle,
    required this.language,
  });

  final ApiClient apiClient;
  final String token;
  final String fundId;
  final String fundTitle;
  final AppLanguage language;

  @override
  State<_GiveSheet> createState() => _GiveSheetState();
}

class _GiveSheetState extends State<_GiveSheet> {
  static const _presets = [50, 100, 200, 500, 1000];

  final TextEditingController _custom = TextEditingController();
  int? _selectedPreset = 100;
  _Stage _stage = _Stage.amount;
  bool _busy = false;
  String _error = '';
  String _txRef = '';
  String _checkoutUrl = '';
  Timer? _poll;
  int _pollsLeft = 0;

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  double? get _amount {
    if (_selectedPreset != null) return _selectedPreset!.toDouble();
    final v = double.tryParse(_custom.text.trim());
    return (v != null && v >= 1) ? v : null;
  }

  @override
  void dispose() {
    _poll?.cancel();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    final amount = _amount;
    if (amount == null) {
      setState(() => _error = _t('Enter an amount of at least 1 ETB.', 'ቢያንስ 1 ብር ያስገቡ።'));
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final res = await widget.apiClient.createPaymentCheckout(
        widget.token,
        purpose: 'donation',
        referenceId: widget.fundId,
        amount: amount,
      );
      _txRef = '${res['txRef'] ?? ''}';
      _checkoutUrl = '${res['checkoutUrl'] ?? ''}';
      if (_checkoutUrl.isEmpty || _txRef.isEmpty) {
        throw Exception(_t('Could not start the payment.', 'ክፍያውን መጀመር አልተቻለም።'));
      }
      await _openCheckout();
      if (!mounted) return;
      setState(() {
        _stage = _Stage.awaiting;
        _busy = false;
      });
      _autoPoll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString().replaceFirst('Exception: ', '').replaceFirst('HttpException: ', '');
      });
    }
  }

  Future<void> _openCheckout() async {
    final uri = Uri.tryParse(_checkoutUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Poll verification a handful of times after the user returns from checkout.
  void _autoPoll() {
    _poll?.cancel();
    _pollsLeft = 10;
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pollsLeft-- <= 0) {
        _poll?.cancel();
        return;
      }
      _checkStatus(silent: true);
    });
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (_busy && !silent) return;
    if (!silent) setState(() => _busy = true);
    try {
      final res = await widget.apiClient.verifyPayment(widget.token, _txRef);
      final status = '${res['status'] ?? ''}';
      if (!mounted) return;
      if (status == 'paid') {
        _poll?.cancel();
        setState(() {
          _stage = _Stage.paid;
          _busy = false;
        });
      } else if (status == 'failed' || status == 'cancelled') {
        _poll?.cancel();
        setState(() {
          _stage = _Stage.failed;
          _busy = false;
          _error = _t('The payment did not go through.', 'ክፍያው አልተሳካም።');
        });
      } else if (!silent) {
        setState(() {
          _busy = false;
          _error = _t('Not confirmed yet. Finish in the browser, then check again.',
              'ገና አልተረጋገጠም። በአሳሽ ውስጥ ጨርሰው እንደገና ያረጋግጡ።');
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _busy = false;
          _error = error.toString().replaceFirst('HttpException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.volunteer_activism_rounded, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_t('Give to ${widget.fundTitle}', 'ለ${widget.fundTitle} ይለግሱ'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 16),
        switch (_stage) {
          _Stage.amount => _amountStage(colors),
          _Stage.awaiting => _awaitingStage(colors),
          _Stage.paid => _paidStage(colors),
          _Stage.failed => _failedStage(colors),
        },
      ]),
    );
  }

  Widget _amountStage(ColorScheme colors) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(_t('Amount (ETB)', 'መጠን (ብር)'), style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in _presets)
          ChoiceChip(
            label: Text('$p'),
            selected: _selectedPreset == p,
            onSelected: (_) => setState(() {
              _selectedPreset = p;
              _custom.clear();
              _error = '';
            }),
          ),
      ]),
      const SizedBox(height: 10),
      TextField(
        controller: _custom,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onChanged: (v) => setState(() {
          _selectedPreset = null;
          _error = '';
        }),
        decoration: InputDecoration(
          labelText: _t('Custom amount', 'ሌላ መጠን'),
          prefixText: 'ETB ',
          border: const OutlineInputBorder(),
        ),
      ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(_error, style: TextStyle(color: colors.error, fontSize: 13)),
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _busy ? null : _startCheckout,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.lock_rounded, size: 18),
          label: Text(_amount == null
              ? _t('Continue', 'ቀጥል')
              : _t('Give ETB ${_fmt(_amount!)}', 'ETB ${_fmt(_amount!)} ለግስ')),
        ),
      ),
      const SizedBox(height: 8),
      Text(_t('You will complete payment securely via the gateway.', 'ክፍያውን በደህንነት በበሩ በኩል ይጨርሳሉ።'),
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
    ]);
  }

  Widget _awaitingStage(ColorScheme colors) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const SizedBox(width: 4),
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(_t('Complete the payment in your browser. This updates automatically.',
                'ክፍያውን በአሳሽዎ ይጨርሱ። ይህ በራስ-ሰር ይዘመናል።')),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: _busy ? null : _openCheckout,
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: Text(_t('Reopen payment page', 'የክፍያ ገጹን እንደገና ክፈት')),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _busy ? null : () => _checkStatus(),
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh_rounded, size: 18),
        label: Text(_t('I have paid — check status', 'ከፍያለሁ — ሁኔታ ያረጋግጡ')),
      ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(_error, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
      ],
    ]);
  }

  Widget _paidStage(ColorScheme colors) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 4),
      Icon(Icons.check_circle_rounded, color: colors.primary, size: 56),
      const SizedBox(height: 12),
      Center(
        child: Text(_t('Thank you for giving!', 'ስለለገሱ እናመሰግናለን!'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 6),
      Center(
        child: Text(_t('Your gift was received.', 'ስጦታዎ ተቀብሏል።'),
            style: TextStyle(color: colors.onSurfaceVariant)),
      ),
      const SizedBox(height: 18),
      FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(_t('Done', 'ተጠናቀቀ'))),
    ]);
  }

  Widget _failedStage(ColorScheme colors) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 4),
      Icon(Icons.error_outline_rounded, color: colors.error, size: 52),
      const SizedBox(height: 12),
      Center(child: Text(_error.isNotEmpty ? _error : _t('Payment failed.', 'ክፍያው አልተሳካም።'), textAlign: TextAlign.center)),
      const SizedBox(height: 18),
      OutlinedButton(
        onPressed: () => setState(() {
          _stage = _Stage.amount;
          _error = '';
        }),
        child: Text(_t('Try again', 'እንደገና ይሞክሩ')),
      ),
    ]);
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
