package jp.linkserver.beastlocator

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

object BackgroundLocationUpdater {
    const val ACTION_LOCATION_UPDATE = "jp.linkserver.beastlocator.ACTION_LOCATION_UPDATE"

    fun updateRegistration(context: Context) {
        val store = DestinationStore(context)
        val shouldRunForegroundMonitor =
            store.isSoundForegroundMonitorEnabled() && hasRequiredPermission(context)
        if (shouldRunForegroundMonitor) {
            ForegroundDistanceMonitorService.start(context)
        } else {
            ForegroundDistanceMonitorService.stop(context)
        }

        if (!shouldRunForegroundMonitor &&
            store.isWidgetBackgroundUpdateEnabled() &&
            hasRequiredPermission(context)
        ) {
            start(context)
        } else {
            stop(context)
        }
    }

    @SuppressLint("MissingPermission")
    private fun start(context: Context) {
        if (!hasRequiredPermission(context)) return
        val request = LocationRequest.Builder(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            60_000L
        ).setMinUpdateIntervalMillis(30_000L).build()
        val client = LocationServices.getFusedLocationProviderClient(context)
        runCatching {
            client.requestLocationUpdates(request, locationPendingIntent(context))
                .addOnFailureListener {
                    client.removeLocationUpdates(locationPendingIntent(context))
                }
        }.onFailure {
            client.removeLocationUpdates(locationPendingIntent(context))
        }
    }

    private fun stop(context: Context) {
        LocationServices.getFusedLocationProviderClient(context)
            .removeLocationUpdates(locationPendingIntent(context))
    }

    private fun hasRequiredPermission(context: Context): Boolean {
        val hasFine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasFine) return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val hasBackground = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            if (!hasBackground) return false
        }
        return true
    }

    private fun locationPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, BackgroundLocationReceiver::class.java).apply {
            action = ACTION_LOCATION_UPDATE
        }
        return PendingIntent.getBroadcast(
            context,
            31,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

