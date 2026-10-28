package dev.amirzr.singbox.platform

import android.annotation.TargetApi
import android.os.Build
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import dev.amirzr.singbox.SingboxSettings
import io.nekohasekai.libbox.LocalDNSTransport
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asExecutor
import kotlinx.coroutines.suspendCancellableCoroutine
import java.net.InetAddress
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class LocalDNSTransportImpl(private val platformInterface: BoxPlatformInterface) : LocalDNSTransport() {
    @TargetApi(Build.VERSION_CODES.Q)
    override fun rawQuery(network: String?, data: ByteArray?): ByteArray {
        if (network.isNullOrEmpty() || data == null) {
            throw Exception("invalid request")
        }
        // Use a simple DNS-over-UDP approach that works on all Android versions
        // instead of DnsResolver which can be problematic on some ROMs
        throw Exception("rawQuery not implemented")
    }

    @TargetApi(Build.VERSION_CODES.Q)
    override fun lookup(network: String?, domain: String?): String {
        if (network.isNullOrEmpty() || domain.isNullOrEmpty()) {
            throw Exception("invalid request")
        }
        throw Exception("lookup not implemented")
    }
}
