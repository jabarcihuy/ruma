import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';

import 'assistant_draft.dart';
import 'agent_tools.dart';

const assistantBase = String.fromEnvironment(
  'ASSISTANT_BASE_URL',
  defaultValue: 'https://ruma-api.abduljabarbrngkl.workers.dev',
);
const assistantEndpoint = '$assistantBase/v2/agent/turn';

class ScheduleReadCancellation {
  bool cancelled = false;
  void Function()? abort;
  void cancel() {
    cancelled = true;
    abort?.call();
  }
}

// Bounded conversation context, never an automatic ledger upload or auto retry.
class AssistantService {
  AssistantService(this.auth) : uid = auth.currentUser!.uid;
  final FirebaseAuth auth;
  final String uid;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  bool _closed = false;
  void check() {
    if (_closed || auth.currentUser?.uid != uid) {
      throw const DraftFailure('Sesi berubah. Jawaban akun lama diabaikan.');
    }
  }

  Future<Map<String, dynamic>> propose(
    String message,
    String requestId, {
    List<Map<String, String>>? messages,
    List<Map<String, dynamic>> activeProposal = const [],
    String? conversationId,
  }) async => parseAssistantResponse(
    await _postJson(assistantEndpoint, {
      'requestId': requestId,
      'conversationId': conversationId ?? requestId,
      'turnId': requestId,
      'timezone': 'Asia/Jakarta',
      'clientNow': DateTime.now().toUtc().toIso8601String(),
      'messages':
          messages ??
          [
            {'role': 'user', 'content': message},
          ],
      if (activeProposal.isNotEmpty) 'proposal': activeProposal,
    }),
    requestId,
  );

  Future<Map<String, dynamic>> correctSchedule(
    List<Map<String, dynamic>> rows,
    List<Map<String, String>> messages,
  ) async {
    if (rows.isEmpty || rows.length > 40) {
      throw const DraftFailure(
        'Pilih periode dengan maksimal 40 baris untuk koreksi lewat chat. Editor tiap baris tetap tersedia.',
      );
    }
    final id = 'schedule-${DateTime.now().microsecondsSinceEpoch}';
    final result = await _postJson('$assistantBase/v2/agent/schedule/correct', {
      'requestId': id,
      'conversationId': id,
      'turnId': id,
      'timezone': 'Asia/Jakarta',
      'clientNow': DateTime.now().toUtc().toIso8601String(),
      'messages': messages,
      'rows': [
        for (var i = 0; i < rows.length; i++)
          {
            'index': i,
            'title': rows[i]['title'],
            'weekday': rows[i]['weekday'],
            'date': rows[i]['date'],
            'start': rows[i]['start'],
            'end': rows[i]['end'],
            'location': rows[i]['location'],
            'included': rows[i]['included'],
          },
      ],
    });
    if (result['requestId'] != id ||
        result['type'] != 'schedule_correction' ||
        result['updates'] is! List ||
        result['question'] is! String ||
        (result['question'] as String).length > 1000) {
      throw const DraftFailure('Koreksi jadwal belum dapat diverifikasi.');
    }
    final seen = <int>{};
    for (final raw in result['updates'] as List) {
      if (raw is! Map ||
          raw['index'] is! int ||
          (raw['index'] as int) < 0 ||
          (raw['index'] as int) >= rows.length ||
          !seen.add(raw['index'] as int) ||
          !['title', 'start', 'end', 'location'].every(
            (k) => raw[k] is String && (raw[k] as String).length <= 120,
          ) ||
          ![null, 1, 2, 3, 4, 5, 6, 7].contains(raw['weekday']) ||
          raw['date'] != null &&
              (raw['date'] is! String ||
                  !RegExp(r'^\d{4}-\d{2}-\d{2}$')
                      .hasMatch(raw['date'] as String)) ||
          raw['included'] is! bool) {
        throw const DraftFailure('Baris koreksi jadwal belum valid.');
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> _postJson(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    check();
    final payload = jsonEncode(body);
    if (utf8.encode(payload).length > 65536) {
      throw const DraftFailure(
        'Konteks terlalu panjang. Ringkas pesan atau gunakan editor jadwal.',
      );
    }
    final token = await auth.currentUser!.getIdToken().timeout(
      const Duration(seconds: 15),
    );
    check();
    final request = await _client.postUrl(Uri.parse(endpoint));
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(payload);
    final deadline = Timer(
      const Duration(seconds: 50),
      () => request.abort(const SocketException('assistant_timeout')),
    );
    try {
      final response = await request.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 131072) {
          throw const DraftFailure(
            'Jawaban terlalu besar. Tidak ada catatan yang disimpan.',
          );
        }
        bytes.addAll(chunk);
      }
      check();
      if (response.statusCode != 200) {
        throw DraftFailure(switch (response.statusCode) {
          401 => 'Sesi AI tidak valid. Masuk kembali lalu coba lagi.',
          404 => 'Versi layanan percakapan belum aktif. Perbarui layanan Ruma sebelum mencoba lagi.',
          429 => 'Batas pemakaian AI tercapai. Form manual tetap bisa dipakai.',
          422 => 'Pesan melebihi batas tiga agenda dan tiga transaksi. Pisahkan pesannya.',
          504 => 'AI belum menjawab tepat waktu. Coba lagi secara manual.',
          _ => 'Asisten belum tersedia. Coba lagi atau gunakan form manual.',
        });
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) {
        throw const DraftFailure('Format jawaban Asisten tidak valid.');
      }
      return value;
    } finally {
      deadline.cancel();
    }
  }

  Future<Map<String, dynamic>> extractSchedule(
    List<Uint8List> images,
    List<String> mediaTypes, {
    ScheduleReadCancellation? cancellation,
  }) async {
    check();
    if (images.isEmpty ||
        images.length > 3 ||
        images.length != mediaTypes.length ||
        images.any((b) => b.length > 3000000) ||
        images.fold<int>(0, (n, b) => n + b.length) > 8000000 ||
        mediaTypes.any((t) => !['image/png', 'image/jpeg'].contains(t))) {
      throw const DraftFailure(
        'Pilih hingga tiga gambar JPG/PNG, maksimal 3 MB per gambar dan 8 MB total.',
      );
    }
    final token = await auth.currentUser!.getIdToken().timeout(
      const Duration(seconds: 15),
    );
    check();
    if (cancellation?.cancelled == true) {
      throw const DraftFailure('Pembacaan gambar dibatalkan.');
    }
    final request = await _client.postUrl(
      Uri.parse('$assistantBase/v2/agent/schedule'),
    );
    request.followRedirects = false;
    if (cancellation != null) {
      cancellation.abort = () =>
          request.abort(const SocketException('schedule_cancelled'));
    }
    final boundary = 'ruma-${DateTime.now().microsecondsSinceEpoch}';
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );
    for (var i = 0; i < images.length; i++) {
      request.add(
        utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="images"; filename="schedule-$i.${mediaTypes[i] == 'image/png' ? 'png' : 'jpg'}"\r\nContent-Type: ${mediaTypes[i]}\r\n\r\n',
        ),
      );
      request.add(images[i]);
      request.add(utf8.encode('\r\n'));
    }
    request.add(utf8.encode('--$boundary--\r\n'));
    final deadline = Timer(
      const Duration(seconds: 55),
      () => request.abort(const SocketException('schedule_timeout')),
    );
    try {
      final response = await request.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 131072) {
          throw const DraftFailure(
            'Jawaban gambar terlalu besar. Coba gambar yang lebih ringkas.',
          );
        }
        bytes.addAll(chunk);
      }
      check();
      if (response.statusCode != 200) {
        throw DraftFailure(switch (response.statusCode) {
          401 => 'Sesi berubah. Masuk kembali sebelum membaca gambar.',
          429 =>
            'Batas pemakaian AI tercapai. Gambar dan isian tetap tersedia.',
          404 => 'Layanan pembacaan gambar belum aktif pada server Ruma.',
          _ => 'Gambar belum dapat dibaca. Coba lagi atau isi jadwal secara manual.',
        });
      }
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map<String, dynamic> ||
          data['type'] != 'schedule_extraction' ||
          data['rows'] is! List) {
        throw const DraftFailure('Hasil gambar tidak dapat diverifikasi.');
      }
      return data;
    } finally {
      deadline.cancel();
      if (cancellation != null) cancellation.abort = null;
    }
  }

  void dispose() {
    _closed = true;
    _client.close(force: true);
  }
}

Map<String, dynamic> parseAssistantResponse(Object? raw, String requestId) {
  if (raw is! Map<String, dynamic> ||
      raw['requestId'] != requestId ||
      ![
        'draft_proposal',
        'clarification',
        'read_request',
        'change_proposal',
        'answer',
      ].contains(raw['type']) ||
      raw['content'] is! String ||
      (raw['content'] as String).length > 4000) {
    throw const DraftFailure('Jawaban AI tidak dapat diverifikasi.');
  }
  if (raw['type'] == 'answer' ||
      raw['type'] == 'clarification' && raw['reason'] == 'conversation') {
    if (raw['items'] != null &&
        (raw['items'] is! List || (raw['items'] as List).isNotEmpty)) {
      throw const DraftFailure('Jawaban percakapan tidak valid.');
    }
    final text = raw['content'] as String;
    if (RegExp(
      r'\b(sudah|berhasil|telah)\s+(saya\s+)?(di)?(simpan|catat|ubah|hapus|tambahkan)\w*',
      caseSensitive: false,
    ).hasMatch(text)) {
      return {
        ...raw,
        'content': 'Perubahan belum diterapkan. Periksa dan setujui usulan di aplikasi.',
      };
    }
    return raw;
  }
  if (raw['type'] == 'read_request') {
    if (raw['query'] is! Map<String, dynamic>) {
      throw const DraftFailure('Permintaan baca tidak valid.');
    }
    validateReadQuery(raw['query'] as Map<String, dynamic>);
    return {...raw, 'content': 'Membaca catatan…'};
  }
  if (raw['type'] == 'change_proposal') {
    if (raw['change'] is! Map<String, dynamic>) {
      throw const DraftFailure('Usulan perubahan tidak valid.');
    }
    validateChange(raw['change'] as Map<String, dynamic>);
    return {...raw, 'content': 'Periksa perubahan. Data belum disimpan.'};
  }
  // Visible copy is coded: never display an unverified claim of saved data.
  if (raw['type'] == 'clarification') {
    if (![
          'future_purchase',
          'incomplete_draft',
          'transaction_status',
          'target_details',
          'one_change',
          'one_period',
        ].contains(raw['reason']) ||
        raw['items'] is! List ||
        (raw['items'] as List).isNotEmpty) {
      throw const DraftFailure('Klarifikasi AI belum valid.');
    }
    return {
      ...raw,
      'content': switch (raw['reason']) {
        'incomplete_draft' =>
          'Draf belum lengkap. Perjelas kegiatan atau transaksinya.',
        'future_purchase' => 'Ini masih rencana belanja. Jika ingin membuat agenda, kirim ulang dengan kegiatan dan durasinya.',
        'target_details' => 'Sebutkan nama persis dan tanggal catatan yang ingin diubah atau dihapus, beserta perubahan yang diinginkan.',
        'one_change' =>
          'Kirim satu perubahan catatan lama dahulu agar mudah ditinjau.',
        'one_period' => 'Pilih satu tanggal untuk agenda atau satu bulan untuk laporan/riwayat uang.',
        _ => 'Uangnya sudah masuk/keluar atau masih rencana?',
      },
    };
  }
  return {...raw, 'content': 'Draf siap ditinjau. Data belum disimpan.'};
}
