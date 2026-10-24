import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/finance.dart';
import '../../data/savings.dart';
import '../../data/savings_store.dart';
import '../../ui/components.dart';

class SavingsFormPage extends StatefulWidget {
  const SavingsFormPage({
    super.key,
    required this.store,
    this.goal,
    this.movement,
  }) : assert(movement == null || goal != null);
  final SavingsStore store;
  final SavingsGoal? goal;
  final String? movement;
  @override
  State<SavingsFormPage> createState() => _SavingsFormPageState();
}

class _SavingsFormPageState extends State<SavingsFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _amount, _note;
  late final String _id;
  late String _type, _date;
  String? _targetDate, _error, _iconId;
  bool _dirty = false, _leaving = false;
  SavingsMutation? _pending;
  bool get _transfer => widget.movement != null;
  @override
  void initState() {
    super.initState();
    _id = widget.goal?.id ?? widget.store.repository.newId();
    _name = TextEditingController(text: widget.goal?.input.name ?? '');
    _amount = TextEditingController(
      text: _transfer ? '' : widget.goal?.input.targetRupiah.toString() ?? '',
    );
    _note = TextEditingController();
    _targetDate = widget.goal?.input.targetDate;
    _iconId = widget.goal?.input.iconId;
    _type = widget.movement ?? 'deposit';
    _date = financeToday();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _changed() => setState(() {
    _dirty = true;
    _error = null;
  });

  Future<void> _back() async {
    if (widget.store.saving) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => RumaDialog(
          title: const Text('Tinggalkan isian ini?'),
          content: const Text('Perubahan belum disimpan.'),
          actions: [
            RumaButton(
              label: 'Lanjut mengedit',
              secondary: true,
              onPressed: () => Navigator.pop(c, false),
            ),
            const SizedBox(height: 8),
            RumaButton(
              label: 'Buang perubahan',
              destructive: true,
              onPressed: () => Navigator.pop(c, true),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _leaving = true);
    Navigator.pop(context);
  }

  Future<void> _save() async {
    if (widget.store.saving || !_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    SavingsMutation mutation(String operationId) => _transfer
        ? SavingsMutation.transfer(
            operationId: operationId,
            goalId: _id,
            expectedVersion: widget.goal!.version,
            input: SavingsMovementInput(
              type: _type,
              amountRupiah: parseRupiah(_amount.text)!,
              localDate: _date,
              description: _note.text,
            ),
          )
        : SavingsMutation.goal(
            operationId: operationId,
            goalId: _id,
            originalVersion: widget.goal?.version,
            input: SavingsGoalInput(
              name: _name.text,
              targetRupiah: parseRupiah(_amount.text)!,
              targetDate: _targetDate,
              iconId: _iconId,
            ),
          );
    var m = mutation(_pending?.operationId ?? widget.store.repository.newId());
    final error = m.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (_pending != null && m.requestKey != _pending!.requestKey) {
      m = mutation(widget.store.repository.newId());
    }
    _pending = m;
    final ok = await widget.store.save(m);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = widget.store.error);
      return;
    }
    setState(() => _leaving = true);
    Navigator.pop(context, true);
  }

  Future<void> _pickDate({bool target = false}) async {
    final value = target ? _targetDate : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(value ?? financeToday()),
      firstDate: DateTime(2000),
      lastDate: target
          ? DateTime(2100, 12, 31)
          : DateTime.parse(financeToday()),
    );
    if (picked != null && mounted) {
      setState(() {
        if (target) {
          _targetDate = dateKey(picked);
        } else {
          _date = dateKey(picked);
        }
      });
      _changed();
    }
  }

  Widget _label(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final busy = widget.store.saving;
      final current =
          widget.store.snapshot?.goals.where((g) => g.id == _id).firstOrNull ??
          widget.goal;
      return PopScope(
        canPop: _leaving || (!_dirty && !busy),
        onPopInvokedWithResult: (p, _) {
          if (!p) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Tabungan'),
            leading: IconButton(
              tooltip: 'Kembali',
              onPressed: busy ? null : _back,
              icon: const RumaIcon('arrow-left', color: RumaColors.accent),
            ),
          ),
          body: RumaPageBody(
            child: AbsorbPointer(
              absorbing: busy,
              child: Form(
                key: _form,
                onChanged: _changed,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RumaHeading(
                      _transfer
                          ? (_type == 'deposit'
                                ? 'Setor tabungan.'
                                : 'Tarik tabungan.')
                          : widget.goal == null
                          ? 'Buat tujuan tabungan.'
                          : 'Edit tujuan tabungan.',
                      null,
                      compact: true,
                    ),
                    const SizedBox(height: 20),
                    if (_transfer) ...[
                      RumaActionPair(
                        first: RumaButton(
                          key: const ValueKey('savings-type-deposit'),
                          label: 'Setoran',
                          secondary: _type != 'deposit',
                          onPressed: () {
                            setState(() => _type = 'deposit');
                            _changed();
                          },
                        ),
                        second: RumaButton(
                          key: const ValueKey('savings-type-withdrawal'),
                          label: 'Penarikan',
                          secondary: _type != 'withdrawal',
                          onPressed: () {
                            setState(() => _type = 'withdrawal');
                            _changed();
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('Tujuan'),
                      InputDecorator(
                        decoration: const InputDecoration(),
                        child: Text(current!.input.name),
                      ),
                    ] else ...[
                      _label('Nama tujuan'),
                      TextFormField(
                        key: const ValueKey('savings-name'),
                        controller: _name,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Beli headphone',
                          counterText: '',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (s) => (s ?? '').trim().isEmpty
                            ? 'Isi nama tujuan.'
                            : null,
                      ),
                    ],
                    if (!_transfer) ...[
                      const SizedBox(height: 16),
                      _label('Ikon tujuan'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry
                              in SavingsGoalInput.iconLabels.entries)
                            ChoiceChip(
                              key: ValueKey('savings-icon-${entry.key}'),
                              avatar: RumaIcon(
                                entry.key,
                                size: 20,
                                color: (_iconId ?? 'wallet') == entry.key
                                    ? RumaColors.accentInk
                                    : RumaColors.muted,
                              ),
                              label: Text(entry.value),
                              selected: (_iconId ?? 'wallet') == entry.key,
                              // Keep the chosen SVG visible; the chip exposes
                              // selected semantics without painting over it.
                              showCheckmark: false,
                              selectedColor: RumaColors.peach,
                              backgroundColor: RumaColors.surface,
                              labelStyle: const TextStyle(
                                color: RumaColors.ink,
                              ),
                              side: BorderSide(
                                color: (_iconId ?? 'wallet') == entry.key
                                    ? RumaColors.accentInk
                                    : RumaColors.line,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              onSelected: (_) {
                                setState(() => _iconId = entry.key);
                                _changed();
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    _label(_transfer ? 'Nominal (Rp)' : 'Target tabungan (Rp)'),
                    TextFormField(
                      key: const ValueKey('savings-amount'),
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: 100.000',
                      ),
                      validator: (s) {
                        final n = parseRupiah(s ?? '');
                        return n == null || n < 1 || n > 1000000000
                            ? 'Isi rupiah bulat Rp1 sampai Rp1 miliar.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _label(_transfer ? 'Tanggal' : 'Tanggal target · opsional'),
                    RumaCard(
                      radius: 16,
                      padding: 0,
                      child: ListTile(
                        key: const ValueKey('savings-date'),
                        title: Text(
                          _transfer ? _date : _targetDate ?? 'Belum ditentukan',
                        ),
                        trailing: !_transfer && _targetDate != null
                            ? IconButton(
                                tooltip: 'Hapus tanggal target',
                                onPressed: () {
                                  setState(() => _targetDate = null);
                                  _changed();
                                },
                                icon: const Icon(Icons.close),
                              )
                            : const RumaIcon('calendar-days'),
                        onTap: () => _pickDate(target: !_transfer),
                      ),
                    ),
                    if (_transfer) ...[
                      const SizedBox(height: 16),
                      _label('Catatan · opsional'),
                      TextFormField(
                        key: const ValueKey('savings-note'),
                        controller: _note,
                        maxLines: 2,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          hintText: 'Tambahkan catatan',
                          counterText: '',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    RumaCard(
                      color: RumaColors.sage,
                      radius: 24,
                      padding: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _transfer
                                ? widget.store.snapshot == null
                                      ? 'Uang tersedia belum termuat.'
                                      : 'Tersedia ${rupiah(widget.store.snapshot!.availableRupiah)}'
                                : widget.goal == null
                                ? 'Mulai dari Rp0'
                                : 'Terkumpul ${rupiah(current!.balanceRupiah)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _transfer
                                ? 'Tabungan tujuan ini ${rupiah(current!.balanceRupiah)}.'
                                : widget.goal == null
                                ? 'Tambah setoran setelah tujuan dibuat.'
                                : 'Mengubah target tidak memindahkan dana.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      ErrorNotice(_error!),
                    ],
                    const SizedBox(height: 16),
                    RumaButton(
                      key: const ValueKey('savings-save'),
                      label: _transfer ? 'Simpan catatan' : 'Simpan tujuan',
                      busy: busy,
                      onPressed: _save,
                    ),
                    const SizedBox(height: 12),
                    RumaButton(
                      key: const ValueKey('savings-cancel'),
                      label: 'Batalkan',
                      secondary: true,
                      onPressed: busy ? null : _back,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
