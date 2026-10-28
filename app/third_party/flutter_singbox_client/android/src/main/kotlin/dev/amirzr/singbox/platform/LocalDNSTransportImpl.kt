package dev.amirzr.singbox.platform

import android.annotation.TargetApi
import android.net.ConnectivityManager
import android.os.Build
import io.nekohasekai.libbox.ExchangeContext
import io.nekohasekai.libbox.LocalDNSTransport
import java.net.InetAddress
import java.net.UnknownHostException

class LocalDNSTransportImpl(
    private val connectivityManager: ConnectivityManager,
) : LocalDNSTransport {

    override fun raw(): Boolean = false

    override fun lookup(ctx: ExchangeContext, network: String, domain: String) {
        try {
            val addrs = InetAddress.getAllByName(domain)
            val result = addrs.mapNotNull { it.hostAddress }.joinToString("\n")
            if (result.isEmpty()) {
                ctx.errorCode(3) // NXDOMAIN
            } else {
                ctx.success(result)
            }
        } catch (e: UnknownHostException) {
            ctx.errorCode(3) // NXDOMAIN
        } catch (e: Exception) {
            ctx.errorCode(2) // SERVFAIL
        }
    }

    @TargetApi(Build.VERSION_CODES.Q)
    override fun exchange(ctx: ExchangeContext, message: ByteArray) {
        ctx.errorCode(2) // SERVFAIL - not implemented
    }
}
