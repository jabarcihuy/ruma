import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'assistant_draft.dart';
import 'agent_tools.dart';

const assistantEndpoint =
    'https://ruma-api.abduljabarbrngkl.workers.dev/v1/agent/turn';

// Only the typed message goes to the existing proxy. No ledger upload or auto retry.
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

  Future<Map<String, dynamic>> propose(String message, String requestId) async {
    check();
    final token = await auth.currentUser!.getIdToken().timeout(
      const Duration(seconds: 15),
    );
    check();
    final request = await _client.postUrl(Uri.parse(assistantEndpoint));
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(
      jsonEncode({
        'requestId': requestId,
        'conversationId': requestId,
        'turnId': requestId,
        'timezone': 'Asia/Jakarta',
        'clientNow': DateTime.now().toUtc().toIso8601String(),
        'messages': [
          {'role': 'user', 'content': message},
        ],
      }),
    );
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
          429 => 'Batas pemakaian AI tercapai. Form manual tetap bisa dipakai.',
          422 => 'Pesan melebihi batas tiga agenda dan tiga transaksi. Pisahkan pesannya.',
          504 => 'AI belum menjawab tepat waktu. Coba lagi secara manual.',
          _ => 'Asisten belum tersedia. Coba lagi atau gunakan form manual.',
        });
      }
      return parseAssistantResponse(jsonDecode(utf8.decode(bytes)), requestId);
    } finally {
      deadline.cancel();
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
      ].contains(raw['type']) ||
      raw['content'] is! String ||
      (raw['content'] as String).length > 4000) {
    throw const DraftFailure('Jawaban AI tidak dapat diverifikasi.');
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
