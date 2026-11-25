package dev.amirzr.singbox.network

import android.annotation.TargetApi
import android.content.Context
import android.net.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.nekohasekai.libbox.InterfaceUpdateListener
import java.net.NetworkInterface as JNetworkInterface

/**
 * Monitors the default physical network and notifies the Sing-box core when it changes.
 *
 * Lifecycle:
 *   1. startMonitoring() — register callback + snapshot activeNetwork.
 *      Call this BEFORE commandServer.startOrReloadService() so currentNetwork is
 *      already populated when the Go core calls startDefaultInterfaceMonitor().
 *   2. setListener(listener) — called by Go core via startDefaultInterfaceMonitor().
 *      Synchronously delivers currentNetwork to the listener so the core knows the
 *      physical interface before making any outbound connections.
 *   3. clearListener() — called by Go core via closeDefaultInterfaceMonitor().
 *   4. stopMonitoring() — unregister callback when service stops.
 *
 * IMPORTANT: registerDefaultNetworkCallback returns the VPN interface itself on Android P+:
 * https://android.googlesource.com/platform/frameworks/base/+/dda156ab0c5d66ad82bdcf76cda07cbc0a9c8a2e
 *
 * To get only the underlying physical network (not the VPN), we use:
 *   API 31+  → registerBestMatchingNetworkCallback
 *   API 28-30 → requestNetwork  (REQUEST type, not LISTEN)
 *   API 26-27 → registerDefaultNetworkCallback with Handler
 *   API < 26  → registerDefaultNetworkCallback
 */
class DefaultNetworkMonitor(context: Context) {

    companion object {
        private const val TAG = "DefaultNetworkMonitor"
    }

    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val mainHandler = Handler(Looper.getMainLooper())

    // A single worker thread: the checks below may sleep up to a second, and
    // connectivity callbacks can fire in bursts. Spawning a raw Thread per
    // callback churns the scheduler on low-end devices.
    private val worker = java.util.concurrent.Executors.newSingleThreadExecutor { r ->
        Thread(r, "DefaultNetworkMonitor").apply { isDaemon = true }
    }

    private fun submit(block: () -> Unit) {
        runCatching { worker.execute(block) }
    }

    @Volatile private var currentNetwork: Network? = null
    @Volatile private var listener: InterfaceUpdateListener? = null

    private val request = NetworkRequest.Builder()
        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
        .build()

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            currentNetwork = network
            // Run on background thread — checkDefaultInterfaceUpdate may sleep during retries.
            submit { checkDefaultInterfaceUpdate(network) }
        }

        override fun onLost(network: Network) {
            currentNetwork = null
            listener?.updateDefaultInterface("", -1, false, false)
        }

        override fun onLinkPropertiesChanged(network: Network, lp: LinkProperties) {
            submit { checkDefaultInterfaceUpdate(network, lp) }
        }

        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
            submit { checkDefaultInterfaceUpdate(network) }
        }
    }

    /**
     * Step 1 — call BEFORE commandServer.startOrReloadService().
     * Registers the network callback and snapshots the current active network so that
     * setListener() can deliver it synchronously when the Go core calls
     * startDefaultInterfaceMonitor().
     */
    fun startMonitoring() {
        register()
        currentNetwork = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectivityManager.activeNetwork
        } else null
    }

    /**
     * Step 2 — called by Go core via PlatformInterface.startDefaultInterfaceMonitor().
     * Sets the listener and immediately delivers the current network synchronously so the
     * core knows which physical interface to use before making any outbound connections.
     * Safe to block here because this is called from a Go goroutine, not the main thread.
     */
    fun setListener(listener: InterfaceUpdateListener) {
        this.listener = listener
        checkDefaultInterfaceUpdate(currentNetwork)
    }

    /** Called by Go core via PlatformInterface.closeDefaultInterfaceMonitor(). */
    fun clearListener() {
        listener = null
    }

    /** Step 4 — call when the service is stopping. */
    fun stopMonitoring() {
        listener = null
        currentNetwork = null
        runCatching { connectivityManager.unregisterNetworkCallback(networkCallback) }
        worker.shutdownNow()
    }

    private fun register() {
        try {
            when {
                Build.VERSION.SDK_INT >= 31 -> {
                    @TargetApi(31)
                    connectivityManager.registerBestMatchingNetworkCallback(
                        request, networkCallback, mainHandler,
                    )
                }
                Build.VERSION.SDK_INT >= 28 -> {
                    @TargetApi(28)
                    connectivityManager.requestNetwork(request, networkCallback, mainHandler)
                }
                Build.VERSION.SDK_INT >= 26 -> {
                    @TargetApi(26)
                    connectivityManager.registerDefaultNetworkCallback(networkCallback, mainHandler)
                }
                else -> {
                    connectivityManager.registerDefaultNetworkCallback(networkCallback)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register network callback", e)
        }
    }

    private fun checkDefaultInterfaceUpdate(network: Network?, lp: LinkProperties? = null) {
        val listener = listener ?: return
        if (network == null) {
            listener.updateDefaultInterface("", -1, false, false)
            return
        }
        for (i in 0 until 10) {
            val props = lp ?: connectivityManager.getLinkProperties(network)
            val name = props?.interfaceName
            if (props == null || name == null) {
                Thread.sleep(100)
                continue
            }
            val index = runCatching {
                JNetworkInterface.getByName(name)?.index ?: -1
            }.getOrDefault(-1)
            if (index >= 0) {
                listener.updateDefaultInterface(name, index, false, false)
                return
            }
            Thread.sleep(100)
        }
        Log.w(TAG, "Could not resolve interface index for network $network")
    }
}
