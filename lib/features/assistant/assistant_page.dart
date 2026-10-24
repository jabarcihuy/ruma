import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';
import '../../data/agenda.dart';
import '../../data/agent_tools.dart';
import '../../data/assistant_draft.dart';
import '../../data/assistant_store.dart';
import '../../data/finance.dart';
import '../../ui/components.dart';
import '../agenda/agenda_form.dart';
import '../finance/finance_forms.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    required this.store,
    required this.onTab,
    this.keyboardVisible = false,
  });
  final AssistantStore store;
  final ValueChanged<int> onTab;
  final bool keyboardVisible;
  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.store.input);
    _text.addListener(() => widget.store.input = _text.text);
    widget.store.addListener(_syncText);
  }

  @override
  void dispose() {
    widget.store.removeListener(_syncText);
    _text.dispose();
    super.dispose();
  }

  void _syncText() {
    if (widget.store.ready && _text.text != widget.store.input) {
      _text.text = widget.store.input;
    }
  }

  Future<void> _reloadHistory() async {
    final s = widget.store;
    if (s.storageBlocked) {
      final reload = await showDialog<bool>(
        context: context,
        builder: (c) => RumaDialog(
          title: const Text('Muat ulang riwayat?'),
          content: const Text(
            'Suntingan yang belum tersimpan di perangkat ini akan diganti dengan data akun terbaru.',
          ),
          actions: [
            RumaButton(
              label: 'Batalkan',
              secondary: true,
              onPressed: () => Navigator.pop(c, false),
            ),
            RumaButton(
              label: 'Muat ulang',
              onPressed: () => Navigator.pop(c, true),
            ),
          ],
        ),
      );
      if (!mounted || reload != true) return;
    }
    await s.load();
  }

  Widget _workspace(AssistantStore s, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (s.persistent) ...[
        if (s.storageError.isNotEmpty) ...[
          ErrorNotice(s.storageError),
          const SizedBox(height: 8),
          RumaButton(
            label: s.storageBlocked ? 'Muat ulang riwayat' : 'Coba simpan lagi',
            secondary: true,
            onPressed: (s.busy || !s.usable)
                ? null
                : () => s.storageBlocked ? _reloadHistory() : s.flush(),
          ),
          const SizedBox(height: 12),
        ] else if (s.storagePending)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Menyimpan…'),
          ),
      ],
      if (s.history.isNotEmpty) ...[
        RumaCard(
          child: ExpansionTile(
            key: const ValueKey('assistant-history'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Riwayat percakapan'),
            children: [
              for (final turn in s.history.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        turn['message']!,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (turn['reply']!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(turn['reply']!),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      child,
    ],
  );

  Future<void> _send() async {
    final s = widget.store;
    if (!s.consent) {
      final allowed = await showDialog<bool>(
        context: context,
        builder: (c) => RumaDialog(
          title: const Text('Izinkan Asisten memproses pesan?'),
          content: const Text(
            'Pesan yang kamu ketik dikirim melalui proxy Ruma ke NaraRouter. Pembacaan agenda dan uang dilakukan aplikasi; hasilnya tidak dikirim kembali ke model. AI memilih tool baca atau menyiapkan draf; penyimpanan tetap menunggu persetujuanmu.',
          ),
          actions: [
            RumaButton(
              label: 'Batalkan',
              secondary: true,
              onPressed: () => Navigator.pop(c, false),
            ),
            const SizedBox(height: 8),
            RumaButton(
              label: 'Izinkan dan kirim',
              onPressed: () => Navigator.pop(c, true),
            ),
          ],
        ),
      );
      if (!mounted || allowed != true) return;
      s.consent = true;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await s.send(_text.text);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (c, _) {
      final s = widget.store, d = s.draft;
      if (!s.ready) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.loading)
              const RumaCard(child: Text('Memuat Asisten…'))
            else ...[
              ErrorNotice(s.storageError),
              const SizedBox(height: 12),
              RumaButton(label: 'Coba muat lagi', onPressed: _reloadHistory),
            ],
          ],
        );
      }
      if (s.recordDraft != null) {
        return _workspace(s, _recordReview(s, s.recordDraft!));
      }
      if (d != null) return _workspace(s, _review(s, d));
      final keyboard =
          widget.keyboardVisible || MediaQuery.viewInsetsOf(context).bottom > 0;
      return _workspace(
        s,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: RumaHeading('Mau dibantu apa?', null, compact: true),
                ),
                IconButton(
                  tooltip: 'Tentang Asisten',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (c) => RumaDialog(
                      title: const Text('Tentang Asisten'),
                      content: const Text(
                        'Tambahkan hingga 3 agenda dan 3 transaksi per pesan. Jam disarankan dalam rentang pilihanmu; durasi bisa diubah.\n\nTanyakan agenda, laporan, atau riwayat satu periode. Edit/hapus satu catatan lama per draf memakai nama persis dan tanggal. Draf dan hingga 10 percakapan terakhir disimpan di akunmu. Urungkan tersedia pada tinjauan terakhir selama catatan belum berubah lagi. Pesan baru tetap dikirim sendiri, tanpa mengirim seluruh riwayat ke model.',
                      ),
                      actions: [
                        RumaButton(
                          label: 'Mengerti',
                          onPressed: () => Navigator.pop(c),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(
                    Icons.info_outline,
                    size: 22,
                    color: RumaColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (s.busy) ...[
              const RumaCard(
                color: RumaColors.sage,
                child: Text('Sedang menyiapkan draf…'),
              ),
              const SizedBox(height: 12),
            ],
            if (!keyboard) ...[
              RumaCard(
                padding: 20,
                child: LayoutBuilder(
                  builder: (context, size) {
                    final mascot = ExcludeSemantics(
                      child: SvgPicture.asset(
                        'design/assets/ruma/mascot/abstract-friend.svg',
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                    );
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waktu & uang, tertata.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text('Ceritakan, lalu tinjau sebelum disimpan.'),
                      ],
                    );
                    if (size.maxWidth < 280 ||
                        MediaQuery.textScalerOf(context).scale(13) > 18) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [mascot, const SizedBox(height: 12), copy],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 16),
                        mascot,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const RumaIcon('calendar-days'),
                    label: const Text('Kegiatan & pengeluaran', softWrap: true),
                    onPressed: (s.busy || !s.usable) ? null : () => _text.text = 'Besok revisi laporan satu jam dan baca jurnal 30 menit. Tadi makan 18 ribu dan cetak laporan 15 ribu.',
                  ),
                  ActionChip(
                    avatar: const RumaIcon('wallet'),
                    label: const Text('Pemasukan'),
                    onPressed: (s.busy || !s.usable)
                        ? null
                        : () =>
                              _text.text = 'Tadi menerima uang saku 500 ribu.',
                  ),
                  ActionChip(
                    label: const Text('Agenda hari ini'),
                    onPressed: (s.busy || !s.usable)
                        ? null
                        : () => _text.text = 'Apa agenda saya hari ini?',
                  ),
                  ActionChip(
                    label: const Text('Laporan bulan ini'),
                    onPressed: (s.busy || !s.usable)
                        ? null
                        : () =>
                              _text.text = 'Tampilkan laporan uang bulan ini.',
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text('Jam tersedia (WIB)'),
                TextButton(
                  onPressed: (s.busy || !s.usable) ? null : () => _window(true),
                  child: Text(_minute(s.availableFrom)),
                ),
                const Text('–'),
                TextButton(
                  onPressed: (s.busy || !s.usable)
                      ? null
                      : () => _window(false),
                  child: Text(_minute(s.availableTo)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('assistant-message'),
              controller: _text,
              enabled: !s.busy && s.usable,
              minLines: 2,
              maxLines: 5,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Ceritakan di sini',
                hintText: 'Contoh: tadi makan 18 ribu…',
              ),
            ),
            RumaButton(
              key: const ValueKey('assistant-send'),
              label: s.busy ? 'Menyiapkan draf…' : 'Kirim ke Asisten',
              busy: s.busy,
              onPressed: s.usable ? _send : null,
            ),
            if (s.error.isNotEmpty) ...[
              const SizedBox(height: 12),
              ErrorNotice(s.error),
            ],
            if (s.reply.isNotEmpty) ...[
              const SizedBox(height: 12),
              RumaCard(color: RumaColors.soft, child: Text(s.reply)),
            ],
            const SizedBox(height: 16),
            const Text('Atau isi sendiri', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            RumaActionPair(
              first: RumaButton(
                label: 'Agenda',
                secondary: true,
                onPressed: () => widget.onTab(1),
              ),
              second: RumaButton(
                label: 'Transaksi',
                secondary: true,
                onPressed: () => widget.onTab(3),
              ),
            ),
          ],
        ),
      );
    },
  );
  String _minute(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  Future<void> _window(bool from) async {
    final s = widget.store,
        v = from ? widget.store.availableFrom : widget.store.availableTo;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: v ~/ 60, minute: v % 60),
    );
    if (!mounted || time == null) return;
    final minutes = time.hour * 60 + time.minute;
    if (from ? minutes >= s.availableTo : minutes <= s.availableFrom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam selesai harus setelah jam mulai.')),
      );
      return;
    }
    setState(() {
      if (from) {
        s.availableFrom = minutes;
      } else {
        s.availableTo = minutes;
      }
      s.preferencesChanged();
    });
  }

  String _agendaSummary(AgendaInput a) =>
      '${a.title}\n'
      '${a.startAtUtc == null ? 'Belum dijadwalkan' : '${dateKey(agendaLocal(a.startAtUtc!))} · ${clockLabel(context, a.startAtUtc!)} WIB'}'
      ' · ${a.durationMinutes} menit\n${a.status == 'completed'
          ? 'Selesai'
          : a.status == 'cancelled'
          ? 'Dibatalkan'
          : 'Terjadwal'}'
      '\n${a.kind == 'class' ? 'Kuliah' : 'Tugas'} · Prioritas ${a.priority}'
      '${a.deadlineAtUtc == null ? '' : '\nDeadline ${dateKey(agendaLocal(a.deadlineAtUtc!))} · ${clockLabel(context, a.deadlineAtUtc!)} WIB'}'
      '${a.description.isEmpty ? '' : '\n${a.description}'}';
  String _moneySummary(TransactionInput m) =>
      '${m.description}\n${m.localDate} · ${rupiah(m.amountRupiah)} · ${categoryLabel(m.categoryId)}\n${m.type == 'income' ? 'Pemasukan' : 'Pengeluaran'}';

  Future<void> _editRecord(AssistantStore s, RecordDraft d) async {
    if (d.agenda != null) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AgendaFormPage(
            store: s.agenda,
            existing: AgendaItem(
              id: d.id,
              version: d.version,
              input: d.agenda!,
            ),
            onDraftChanged: (a) => s.editRecord(a, null),
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => FinanceFormPage(
            store: s.finance,
            existing: MoneyTransaction(
              id: d.id,
              version: d.version,
              input: d.money!,
            ),
            onDraftChanged: (m) => s.editRecord(null, m),
          ),
        ),
      );
    }
  }

  Widget _recordReview(AssistantStore s, RecordDraft d) {
    final locked = !s.usable || s.busy || d.applied || d.attempted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RumaHeading(
          d.undone
              ? 'Sudah diurungkan'
              : d.applied
              ? 'Perubahan tersimpan'
              : d.delete
              ? 'Hapus catatan ini?'
              : 'Periksa perubahan',
          null,
        ),
        const SizedBox(height: 16),
        RumaCard(color: RumaColors.soft, child: Text('“${s.message}”')),
        const SizedBox(height: 16),
        Text(
          d.undone
              ? 'Catatan saat ini'
              : d.delete
              ? (d.applied ? 'Catatan dihapus' : 'Catatan yang akan dihapus')
              : 'Sebelumnya',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        RumaCard(
          child: Text(
            d.beforeAgenda != null
                ? _agendaSummary(d.beforeAgenda!)
                : _moneySummary(d.beforeMoney!),
          ),
        ),
        if (!d.delete && !d.undone) ...[
          const SizedBox(height: 16),
          Text('Menjadi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RumaCard(
            color: RumaColors.sage,
            child: Text(
              d.agenda != null
                  ? _agendaSummary(d.agenda!)
                  : _moneySummary(d.money!),
            ),
          ),
          if (!d.applied)
            TextButton(
              onPressed: locked ? null : () => _editRecord(s, d),
              child: const Text('Ubah draf'),
            ),
        ],
        if (s.error.isNotEmpty) ...[
          const SizedBox(height: 12),
          ErrorNotice(s.error),
        ],
        const SizedBox(height: 24),
        if (!d.applied) ...[
          RumaButton(
            key: const ValueKey('record-save'),
            label: d.attempted
                ? 'Periksa dan coba lagi'
                : d.delete
                ? 'Setuju, hapus catatan'
                : 'Simpan perubahan',
            busy: s.busy,
            onPressed: s.usable ? () => s.saveRecord() : null,
          ),
          const SizedBox(height: 8),
          if (!d.attempted)
            RumaButton(
              label: 'Batalkan',
              secondary: true,
              onPressed: (s.busy || !s.usable) ? null : s.discardRecord,
            ),
        ] else ...[
          if (!d.undone) ...[
            RumaButton(
              key: const ValueKey('record-undo'),
              label: d.undoAttempted
                  ? 'Periksa dan urungkan lagi'
                  : 'Urungkan perubahan',
              secondary: true,
              busy: s.busy,
              onPressed: s.usable ? () => s.saveRecord(undo: true) : null,
            ),
            const SizedBox(height: 8),
          ],
          if (!d.undoAttempted || d.undone)
            RumaButton(
              label: 'Selesai',
              onPressed: (s.busy || !s.usable) ? null : s.discardRecord,
            ),
        ],
      ],
    );
  }

  Future<void> _edit(DraftEntry e) async {
    final s = widget.store;
    if (e.agenda != null) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AgendaFormPage(
            store: s.agenda,
            existing: AgendaItem(id: e.id, version: 0, input: e.agenda!),
            onDraftChanged: (v) => s.change(() {
              e.agenda = v;
              e.suggestedTime = false;
            }),
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => FinanceFormPage(
            store: s.finance,
            existing: MoneyTransaction(id: e.id, version: 0, input: e.money!),
            onDraftChanged: (v) => s.change(() {
              e.money = v;
              e.localDate = v.localDate;
            }),
          ),
        ),
      );
    }
  }

  Widget _review(AssistantStore s, AssistantDraft d) {
    final locked = !s.usable || s.busy || d.applied || d.attempted;
    final ac = d.included.where((e) => e.agenda != null).length,
        tc = d.included.where((e) => e.money != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RumaHeading(
          d.applied ? 'Sudah tersimpan' : 'Cek sebelum disimpan',
          '$ac agenda · $tc transaksi',
          compact: true,
        ),
        const SizedBox(height: 12),
        if (!d.applied) ...[
          RumaCard(
            radius: 16,
            color: RumaColors.soft,
            child: Row(
              children: [
                SvgPicture.asset(
                  'design/assets/ruma/assistant/review-dot.svg',
                  width: 6,
                  height: 6,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d.attempted
                        ? 'Menunggu kepastian penyimpanan'
                        : 'Menunggu persetujuan',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        RumaCard(
          color: RumaColors.soft,
          radius: 16,
          child: Text(
            '“${s.message}”',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final isAgenda in [true, false]) ...[
          if (d.items.any((e) => (e.agenda != null) == isAgenda)) ...[
            const SizedBox(height: 16),
            Text(
              isAgenda ? 'Agenda' : 'Transaksi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final e in d.items.where(
              (e) => (e.agenda != null) == isAgenda,
            )) ...[
              Container(
                key: ValueKey('draft-item-${e.id}'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: e.included ? RumaColors.surface : RumaColors.subtle,
                  border: Border.all(color: RumaColors.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      e.agenda?.startAtUtc == null
                          ? e.localDate
                          : dayLabel(
                              context,
                              agendaLocal(e.agenda!.startAtUtc!),
                            ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (e.suggestedTime) const Text('Saran jam · bisa diubah'),
                    const SizedBox(height: 8),
                    Text(
                      e.agenda?.title ?? e.money!.description,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.agenda != null
                          ? '${e.agenda!.startAtUtc == null ? 'Belum dijadwalkan' : '${clockLabel(context, e.agenda!.startAtUtc!)}–${clockLabel(context, e.agenda!.endAtUtc!)} WIB'} · ${e.agenda!.durationMinutes} menit'
                          : '${rupiah(e.money!.amountRupiah)} · ${e.money!.type == 'income' ? 'Pemasukan' : 'Pengeluaran'} · ${categoryLabel(e.money!.categoryId)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (e.agenda?.deadlineAtUtc != null)
                      Text(
                        'Deadline ${dateKey(agendaLocal(e.agenda!.deadlineAtUtc!))} · ${clockLabel(context, e.agenda!.deadlineAtUtc!)} WIB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),

                    if (!d.applied) ...[
                      const SizedBox(height: 12),
                      RumaActionPair(
                        first: RumaButton(
                          key: ValueKey('draft-edit-${e.id}'),
                          label: 'Ubah',
                          secondary: true,
                          onPressed: locked ? null : () => _edit(e),
                        ),
                        second: FilledButton(
                          key: ValueKey('draft-toggle-${e.id}'),
                          style: FilledButton.styleFrom(
                            backgroundColor: RumaColors.dangerSoft,
                            foregroundColor: RumaColors.danger,
                          ),
                          onPressed: locked
                              ? null
                              : () => s.change(() => e.included = !e.included),
                          child: Text(e.included ? 'Keluarkan' : 'Masukkan'),
                        ),
                      ),
                    ],
                    if (!e.included)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Tidak ikut disimpan.'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isAgenda &&
                !d.applied &&
                d.items.any(
                  (e) =>
                      e.included &&
                      e.agenda != null &&
                      e.agenda!.startAtUtc == null,
                ))
              Text(
                'Belum ada jam. Ketuk Ubah untuk menjadwalkan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
        if (s.error.isNotEmpty) ...[
          const SizedBox(height: 16),
          ErrorNotice(s.error),
        ],
        const SizedBox(height: 24),
        if (!d.applied) ...[
          if (!d.attempted)
            TextButton(
              onPressed: (s.busy || !s.usable)
                  ? null
                  : () => s.change(() {
                      for (final e in d.items) {
                        e.included = true;
                      }
                    }),
              child: const Text('Pulihkan semua item'),
            ),
          RumaButton(
            key: const ValueKey('draft-save'),
            label: s.busy
                ? 'Menyimpan…'
                : d.attempted
                ? 'Periksa dan simpan ulang'
                : 'Simpan semua terpilih',
            busy: s.busy,
            onPressed: s.usable ? s.save : null,
          ),
          const SizedBox(height: 8),
          if (!d.attempted) ...[
            RumaButton(
              label: 'Batalkan draf',
              secondary: true,
              onPressed: (s.busy || !s.usable) ? null : s.discard,
            ),
            if (s.error.isNotEmpty)
              TextButton(
                onPressed: (s.busy || !s.usable) ? null : s.reviewAgain,
                child: const Text('Tinjau dengan versi terbaru'),
              ),
          ],
        ] else ...[
          RumaButton(label: 'Lihat beranda', onPressed: () => widget.onTab(0)),
          const SizedBox(height: 8),
          RumaButton(
            label: 'Buat draf baru',
            secondary: true,
            onPressed: () {
              s.discard();
              _text.clear();
            },
          ),
        ],
      ],
    );
  }
}
