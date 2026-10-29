package id.ruma.app

import android.content.Intent
import android.accounts.Account
import android.accounts.AccountManager
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.common.api.Scope
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var calendarResult: MethodChannel.Result? = null
    private var calendarAccount: String? = null
    private val calendarScopes = listOf(
        Scope("https://www.googleapis.com/auth/calendar.calendarlist.readonly"),
        Scope("https://www.googleapis.com/auth/calendar.events.readonly")
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.ruma.app/calendar").setMethodCallHandler { call, result ->
            if (call.method != "authorize") { result.notImplemented() }
            else if (calendarResult != null) { result.error("busy", "Pemilihan akun masih berlangsung.", null) }
            else {
                calendarResult = result
                // Explicit account selection is separate from Firebase sign-in.
                // No account password or refresh token crosses the Flutter channel.
                try {
                    val chooser = AccountManager.newChooseAccountIntent(null, null, arrayOf("com.google"), null, null, null, null)
                    startActivityForResult(chooser, 8100)
                } catch (_: Exception) { finishCalendarError("unavailable", "Pemilih akun Google belum tersedia.") }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.ruma.app/settings").setMethodCallHandler { call, result ->
            if (call.method == "notifications") {
                startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                result.success(null)
            } else result.notImplemented()
        }
    }

    private fun finishCalendarError(code: String, message: String) {
        calendarResult?.error(code, message, null)
        calendarResult = null
        calendarAccount = null
    }

    private fun finishCalendarAuthorization(value: AuthorizationResult) {
        val token = value.accessToken
        if (token.isNullOrEmpty()) { finishCalendarError("denied", "Izin membaca kalender belum diberikan."); return }
        calendarResult?.success(mapOf("accessToken" to token, "account" to calendarAccount))
        calendarResult = null
        calendarAccount = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 8100 && requestCode != 8101) return
        if (resultCode != RESULT_OK || data == null) { finishCalendarError("cancelled", "Pemilihan kalender dibatalkan."); return }
        if (requestCode == 8101) {
            try { finishCalendarAuthorization(Identity.getAuthorizationClient(this).getAuthorizationResultFromIntent(data)) }
            catch (_: Exception) { finishCalendarError("denied", "Google belum memberikan akses kalender. Periksa konfigurasi OAuth aplikasi.") }
            return
        }
        val name = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
        if (name.isNullOrEmpty()) { finishCalendarError("cancelled", "Akun Google belum dipilih."); return }
        calendarAccount = name
        val request = AuthorizationRequest.builder().setAccount(Account(name, "com.google")).setRequestedScopes(calendarScopes).build()
        Identity.getAuthorizationClient(this).authorize(request)
            .addOnSuccessListener { value ->
                if (value.hasResolution()) {
                    try { startIntentSenderForResult(value.pendingIntent!!.intentSender, 8101, null, 0, 0, 0) }
                    catch (_: Exception) { finishCalendarError("unavailable", "Izin Google belum dapat dibuka.") }
                } else finishCalendarAuthorization(value)
            }
            .addOnFailureListener { finishCalendarError("configuration", "Kalender belum tersambung. Periksa OAuth Android, izin Calendar API, dan koneksi Google.") }
    }
}
