package eu.kanade.tachiyomi.data.server

import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.IBinder
import androidx.core.content.ContextCompat
import eu.kanade.tachiyomi.R
import eu.kanade.tachiyomi.data.notification.NotificationReceiver
import eu.kanade.tachiyomi.data.notification.Notifications
import eu.kanade.tachiyomi.util.system.notificationBuilder
import timber.log.Timber

/**
 * Foreground service that hosts the Komikku HTTP server for KOReader communication.
 */
class KomikkuHttpService : Service() {

    private var server: KomikkuHttpServer? = null

    override fun onCreate() {
        super.onCreate()
        Timber.tag(TAG).i("Creating HTTP server service")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                Timber.tag(TAG).i("Starting HTTP server")
                startServer()
            }
            ACTION_STOP -> {
                Timber.tag(TAG).i("Stopping HTTP server")
                stopServer()
                stopSelf()
                return START_NOT_STICKY
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent): IBinder? = null

    override fun onDestroy() {
        stopServer()
        super.onDestroy()
    }

    private fun startServer() {
        try {
            server = KomikkuHttpServer(this@KomikkuHttpService, SERVER_PORT)
            server?.start()

            val ipAddress = getLocalIpAddress()
            Timber.tag(TAG).i("HTTP server started on $ipAddress:$SERVER_PORT")

            // Enter foreground with notification
            showNotification(ipAddress)
        } catch (e: Exception) {
            Timber.tag(TAG).e(e, "Failed to start HTTP server")
            stopSelf()
        }
    }

    private fun stopServer() {
        try {
            server?.stop()
            server = null
            NotificationReceiver.dismissNotification(this, Notifications.ID_HTTP_SERVER)
            Timber.tag(TAG).i("HTTP server stopped")
        } catch (e: Exception) {
            Timber.tag(TAG).e(e, "Error stopping HTTP server")
        }
    }

    private fun showNotification(ipAddress: String) {
        val stopIntent = Intent(this, KomikkuHttpService::class.java).apply {
            action = ACTION_STOP
        }

        val builder = notificationBuilder(Notifications.CHANNEL_HTTP_SERVER) {
            setSmallIcon(R.drawable.globe)
            setColor(ContextCompat.getColor(this@KomikkuHttpService, R.color.ic_launcher))
            setContentTitle(getString(R.string.http_server_running))
            setContentText("$ipAddress:$SERVER_PORT")
            setOngoing(true)
            setAutoCancel(false)
        }

        startForeground(Notifications.ID_HTTP_SERVER, builder.build())
    }

    private fun getLocalIpAddress(): String {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val wifiInfo = wifiManager?.connectionInfo
            val ipAddress = wifiInfo?.ipAddress ?: 0

            if (ipAddress == 0) {
                "Unknown IP"
            } else {
                String.format(
                    "%d.%d.%d.%d",
                    (ipAddress and 0xff),
                    ((ipAddress ushr 8) and 0xff),
                    ((ipAddress ushr 16) and 0xff),
                    ((ipAddress ushr 24) and 0xff),
                )
            }
        } catch (e: Exception) {
            Timber.tag(TAG).w(e, "Failed to get WiFi IP address")
            "Unknown IP"
        }
    }

    companion object {
        private const val TAG = "KomikkuHttpService"
        private const val SERVER_PORT = 8080
        const val ACTION_START = "eu.kanade.tachiyomi.server.ACTION_START"
        const val ACTION_STOP = "eu.kanade.tachiyomi.server.ACTION_STOP"

        fun startService(context: Context) {
            val intent = Intent(context, KomikkuHttpService::class.java).apply {
                action = ACTION_START
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stopService(context: Context) {
            val intent = Intent(context, KomikkuHttpService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}
