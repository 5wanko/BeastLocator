package jp.linkserver.beastlocator

import android.Manifest
import android.animation.ObjectAnimator
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.graphics.Typeface
import android.view.View
import android.widget.Button
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import android.view.animation.LinearInterpolator
import kotlin.math.abs
import kotlin.math.ceil

class MainActivity : AppCompatActivity(), SensorEventListener {
    companion object {
        private const val ARROW_IMAGE_FORWARD_OFFSET_DEGREES = 45f
        private const val ARRIVAL_THRESHOLD_METERS = 50f
        private const val DISTANCE_MASK_STEP_KM = 100
        private const val LOCATION_TIMEOUT_MS = 30_000L
    }

    private lateinit var store: DestinationStore
    private lateinit var arrowView: ImageView
    private lateinit var distanceMaskToggleButton: ImageButton
    private lateinit var distanceView: TextView
    private lateinit var directionView: TextView
    private lateinit var centerContent: LinearLayout
    private lateinit var arrivalContent: LinearLayout
    private lateinit var arrivalNameView: TextView
    private lateinit var arrivalCoordsView: TextView
    private lateinit var fusedClient: com.google.android.gms.location.FusedLocationProviderClient
    private lateinit var sensorManager: SensorManager
    private var loadingArrowAnimator: ObjectAnimator? = null

    private var headingDegrees: Float = 0f
    private var currentLocation: Destination? = null
    private var destination: Destination? = null
    private var hasShownInAppArrival = false
    private var isResolvingArrivalName = false
    private var isShowingPreciseLocationPermissionGuide = false
    private var isShowingBackgroundPermissionGuide = false
    private var skipPermissionGuideOnce = false
    private var isScreenCaptureCallbackRegistered = false
    private var screenCaptureCallbackRef: Any? = null
    private val rotationMatrix = FloatArray(9)
    private val remappedRotationMatrix = FloatArray(9)
    private val orientationAngles = FloatArray(3)
    private val locationTimeoutRunnable = Runnable {
        if (currentLocation == null && !store.isDestinationAnswered()) {
            showLocationUnavailableState(R.string.location_timeout)
        }
    }

    private val locationRequest = LocationRequest.Builder(
        Priority.PRIORITY_HIGH_ACCURACY,
        4_000
    ).setMinUpdateIntervalMillis(2_000).build()

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val last = result.lastLocation ?: return
            if (store.isDebugDistanceOverrideEnabled()) return
            distanceView.removeCallbacks(locationTimeoutRunnable)
            currentLocation = Destination(last.latitude, last.longitude)
            store.setLastKnownLocationFromSystem(last.latitude, last.longitude)
            store.setLastKnownHeading(headingDegrees)
            ensureDestinationExists()
            updateUi(refreshWidgets = true)
        }
    }

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            ensureBackgroundLocationPermission()
            startUpdatesIfPermitted()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        store = DestinationStore(this)
        fusedClient = LocationServices.getFusedLocationProviderClient(this)
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager

        arrowView = findViewById(R.id.arrowView)
        distanceMaskToggleButton = findViewById(R.id.distanceMaskToggleButton)
        distanceView = findViewById(R.id.distanceText)
        directionView = findViewById(R.id.directionText)
        centerContent = findViewById(R.id.centerContent)
        arrivalContent = findViewById(R.id.arrivalContent)
        arrivalNameView = findViewById(R.id.arrivalNameText)
        arrivalCoordsView = findViewById(R.id.arrivalCoordsText)
        arrowView.clearColorFilter()
        findViewById<Button>(R.id.createNextDestinationButton).setOnClickListener {
            resetDestinationProgress()
        }
        findViewById<ImageButton>(R.id.settingsButton).setOnClickListener {
            startActivity(android.content.Intent(this, SettingsActivity::class.java))
        }
        distanceMaskToggleButton.setOnClickListener {
            val enabled = !store.isManualDistanceMaskEnabled()
            store.setManualDistanceMaskEnabled(enabled)
            applyDistanceMaskToggleButtonState()
            updateUi(refreshWidgets = false)
        }
    }

    override fun onResume() {
        super.onResume()
        destination = store.getDestination()
        currentLocation = store.getLastKnownLocation()
        hasShownInAppArrival = store.isDestinationAnswered()
        applyDistanceMaskToggleButtonState()
        arrowView.clearColorFilter()
        updateArrivalUiIfNeeded()
        DestinationWidgetProvider.refreshAllWidgets(this)
        if (skipPermissionGuideOnce) {
            skipPermissionGuideOnce = false
            startUpdatesIfPermitted()
        } else {
            requestRuntimePermissionsIfNeeded()
        }
        syncDestinationGeofence()
        registerCompass()
        registerScreenCaptureCallbackIfSupported()
    }

    override fun onPause() {
        super.onPause()
        fusedClient.removeLocationUpdates(locationCallback)
        distanceView.removeCallbacks(locationTimeoutRunnable)
        sensorManager.unregisterListener(this)
        stopLoadingArrowAnimation()
        unregisterScreenCaptureCallbackIfNeeded()
    }

    private fun requestRuntimePermissionsIfNeeded() {
        if (hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION) &&
            !hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        ) {
            // Ensure stale background registrations are stopped immediately
            // when precise location is no longer granted.
            startUpdatesIfPermitted()
            ensurePreciseLocationPermission()
            return
        }

        val required = mutableListOf<String>()
        if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) {
            required += Manifest.permission.ACCESS_FINE_LOCATION
        }
        if (!hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)) {
            required += Manifest.permission.ACCESS_COARSE_LOCATION
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !hasPermission(Manifest.permission.POST_NOTIFICATIONS)
        ) {
            required += Manifest.permission.POST_NOTIFICATIONS
        }

        if (required.isNotEmpty()) {
            permissionLauncher.launch(required.toTypedArray())
        } else {
            ensureBackgroundLocationPermission()
            startUpdatesIfPermitted()
        }
    }

    private fun ensurePreciseLocationPermission() {
        if (!hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ||
            hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        ) {
            return
        }
        if (isShowingPreciseLocationPermissionGuide) {
            return
        }

        isShowingPreciseLocationPermissionGuide = true
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.precise_permission_guide_title)
            .setMessage(R.string.precise_permission_guide_message)
            .setCancelable(false)
            .setPositiveButton(R.string.precise_permission_guide_positive) { _, _ ->
                isShowingPreciseLocationPermissionGuide = false
                openAppPermissionSettings()
            }
            .setNegativeButton(android.R.string.cancel) { _, _ ->
                isShowingPreciseLocationPermissionGuide = false
                startUpdatesIfPermitted()
            }
            .setOnDismissListener {
                isShowingPreciseLocationPermissionGuide = false
            }
            .show()
    }

    private fun ensureBackgroundLocationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) &&
            !hasPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        ) {
            if (isShowingBackgroundPermissionGuide) {
                return
            }
            isShowingBackgroundPermissionGuide = true
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.background_permission_guide_title)
                .setMessage(R.string.background_permission_guide_message)
                .setCancelable(false)
                .setPositiveButton(R.string.background_permission_guide_positive) { _, _ ->
                    store.setBackgroundPermissionGuideShown(true)
                    isShowingBackgroundPermissionGuide = false
                    openAppPermissionSettings()
                }
                .setNegativeButton(android.R.string.cancel) { _, _ ->
                    isShowingBackgroundPermissionGuide = false
                    startUpdatesIfPermitted()
                }
                .setOnDismissListener {
                    isShowingBackgroundPermissionGuide = false
                }
                .show()
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun startUpdatesIfPermitted() {
        if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) {
            fusedClient.removeLocationUpdates(locationCallback)
            distanceView.removeCallbacks(locationTimeoutRunnable)
            currentLocation = null
            startLoadingArrowAnimation()
            BackgroundLocationUpdater.updateRegistration(this)
            NotificationHelper.cancelApproachProgress(this)
            if (store.isDestinationAnswered()) {
                updateArrivalUiIfNeeded()
            } else {
                setArrivalStateVisible(false)
                distanceView.typeface = Typeface.DEFAULT
                distanceView.text = getString(
                    if (hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)) {
                        R.string.waiting_location
                    } else {
                        R.string.permission_needed
                    }
                )
                directionView.text = ""
                directionView.setTextColor(
                    ContextCompat.getColor(this, R.color.expressive_on_surface_variant)
                )
            }
            return
        }

        if (!isSystemLocationEnabled()) {
            startLoadingArrowAnimation()
            showLocationUnavailableState(R.string.location_service_disabled)
            return
        }

        startLoadingArrowAnimation()
        BackgroundLocationUpdater.updateRegistration(this)
        fusedClient.lastLocation
            .addOnSuccessListener { last ->
                if (last != null &&
                    currentLocation == null &&
                    !store.isDebugDistanceOverrideEnabled()
                ) {
                    currentLocation = Destination(last.latitude, last.longitude)
                    store.setLastKnownLocationFromSystem(last.latitude, last.longitude)
                    store.setLastKnownHeading(headingDegrees)
                    ensureDestinationExists()
                    updateUi(refreshWidgets = true)
                }
            }
        distanceView.removeCallbacks(locationTimeoutRunnable)
        distanceView.postDelayed(locationTimeoutRunnable, LOCATION_TIMEOUT_MS)
        runCatching {
            fusedClient.requestLocationUpdates(locationRequest, locationCallback, mainLooper)
                .addOnFailureListener {
                    distanceView.removeCallbacks(locationTimeoutRunnable)
                    showLocationUnavailableState(R.string.location_update_start_failed)
                }
        }.onFailure {
            distanceView.removeCallbacks(locationTimeoutRunnable)
            showLocationUnavailableState(R.string.location_update_start_failed)
        }
    }

    private fun showLocationUnavailableState(messageResId: Int, detailMessageResId: Int? = null) {
        setArrivalStateVisible(false)
        distanceView.typeface = Typeface.DEFAULT
        distanceView.text = getString(messageResId)
        directionView.text = detailMessageResId?.let(::getString).orEmpty()
        directionView.setTextColor(
            ContextCompat.getColor(this, R.color.expressive_on_surface_variant)
        )
    }

    private fun isSystemLocationEnabled(): Boolean {
        val manager = getSystemService(LOCATION_SERVICE) as? LocationManager ?: return true
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
    }

    private fun ensureDestinationExists() {
        destination = store.getDestination()
        syncDestinationGeofence()
    }

    private fun syncDestinationGeofence() {
        val target = destination ?: return
        if (!store.isDestinationAnswered() && GeofenceHelper.canRegisterDestinationGeofence(this)) {
            GeofenceHelper.registerDestinationGeofence(this, target)
        } else {
            GeofenceHelper.clearDestinationGeofence(this)
        }
    }

    private fun updateUi(refreshWidgets: Boolean) {
        val current = currentLocation ?: return
        val target = destination ?: return

        stopLoadingArrowAnimation()
        if (store.isDestinationAnswered()) {
            updateArrivalUiIfNeeded()
            if (refreshWidgets) {
                DestinationWidgetProvider.refreshAllWidgets(this)
            }
            return
        }

        val distance = GeoUtils.distanceMeters(current, target)
        val bearing = GeoUtils.bearingDegrees(current, target)
        val relativeRotation = normalizeRotation(
            bearing - headingDegrees - ARROW_IMAGE_FORWARD_OFFSET_DEGREES
        )

        setArrivalStateVisible(false)
        arrowView.rotation = relativeRotation
        distanceView.typeface = Typeface.MONOSPACE
        distanceView.text = formatDistanceForMainScreen(distance)
        directionView.setTextColor(
            ContextCompat.getColor(this, R.color.expressive_on_surface_variant)
        )
        directionView.text = if (store.isManualDistanceMaskEnabled()) {
            getString(R.string.direction_placeholder)
        } else {
            getString(
                R.string.direction_label,
                GeoUtils.cardinalFromBearing(bearing)
            )
        }

        updateApproachLiveUpdate(distance)

        if (store.isArrivalRearmRequired()) {
            if (distance > ARRIVAL_THRESHOLD_METERS) {
                store.setArrivalRearmRequired(false)
            }
        }

        if (!store.isArrivalRearmRequired() &&
            distance <= ARRIVAL_THRESHOLD_METERS &&
            !hasShownInAppArrival
        ) {
            hasShownInAppArrival = true
            if (store.isArrivalSoundEnabled()) {
                SoundEffectPlayer.play(this, R.raw.arrival_0km)
            }
            store.setDestinationAnswered(true)
            store.setArrivalDestinationName("${target.lat}, ${target.lng}")
            NotificationHelper.cancelApproachProgress(this)
            resolveArrivalNameIfNeeded(target, shouldNotifyWhenResolved = true)
            updateArrivalUiIfNeeded()
        }
        if (refreshWidgets) {
            DestinationWidgetProvider.refreshAllWidgets(this)
        }
    }

    private fun updateArrivalUiIfNeeded() {
        if (!store.isDestinationAnswered()) {
            setArrivalStateVisible(false)
            if (currentLocation == null) {
                startLoadingArrowAnimation()
            }
            return
        }
        stopLoadingArrowAnimation()
        setArrivalStateVisible(true)
        val target = destination
        if (target != null) {
            arrivalCoordsView.visibility = android.view.View.VISIBLE
            arrivalCoordsView.text = getString(
                R.string.arrival_coords_format,
                target.lat,
                target.lng
            )
        } else {
            arrivalCoordsView.visibility = android.view.View.GONE
        }
        val arrivalName = store.getArrivalDestinationName()
        if (arrivalName.isNullOrBlank()) {
            arrivalNameView.text = getString(R.string.arrival_name_placeholder)
            if (target != null) {
                resolveArrivalNameIfNeeded(target)
            }
            return
        }
        arrivalNameView.text = arrivalName
        if (target != null && arrivalName.contains(",")) {
            resolveArrivalNameIfNeeded(target)
        }
    }

    private fun resolveArrivalNameIfNeeded(
        target: Destination,
        shouldNotifyWhenResolved: Boolean = false
    ) {
        if (isResolvingArrivalName) return
        if (!store.isDestinationAnswered()) return
        val currentName = store.getArrivalDestinationName()
        if (!currentName.isNullOrBlank() && !currentName.contains(",")) return

        isResolvingArrivalName = true
        val provider = store.getGeocodingProvider()
        Thread {
            val resolved = ReverseGeocoder.resolve(this, target, provider)
            runOnUiThread {
                isResolvingArrivalName = false
                val currentTarget = destination
                if (!store.isDestinationAnswered() || currentTarget == null || !sameDestination(currentTarget, target)) {
                    return@runOnUiThread
                }
                store.setArrivalDestinationName(resolved)
                arrivalNameView.text = resolved
                if (shouldNotifyWhenResolved) {
                    NotificationHelper.showDestinationReached(
                        this,
                        getString(R.string.notification_body, resolved)
                    )
                }
            }
        }.start()
    }

    private fun sameDestination(a: Destination, b: Destination): Boolean {
        return a.lat == b.lat && a.lng == b.lng
    }

    private fun setArrivalStateVisible(visible: Boolean) {
        arrivalContent.visibility = if (visible) android.view.View.VISIBLE else android.view.View.GONE
        centerContent.visibility = if (visible) android.view.View.GONE else android.view.View.VISIBLE
    }

    private fun resetDestinationProgress() {
        val fixedDestination = store.getDestination()
        destination = fixedDestination
        store.setDestinationAnswered(false)
        store.setArrivalRearmRequired(true)
        hasShownInAppArrival = false
        GeofenceHelper.registerDestinationGeofence(this, fixedDestination)
        NotificationHelper.cancelApproachProgress(this)
        setArrivalStateVisible(false)
        if (currentLocation != null) {
            updateUi(refreshWidgets = true)
        } else {
            DestinationWidgetProvider.refreshAllWidgets(this)
        }
    }

    private fun updateApproachLiveUpdate(distanceMeters: Float) {
        if (!NotificationHelper.isLiveUpdateSupported()) {
            NotificationHelper.cancelApproachProgress(this)
            store.clearLiveUpdateAnchorDistanceMeters()
            return
        }

        if (!store.isLiveUpdateEnabled() || store.isDestinationAnswered()) {
            NotificationHelper.cancelApproachProgress(this)
            store.clearLiveUpdateAnchorDistanceMeters()
            return
        }

        val startDistanceMeters = store.getLiveUpdateStartDistanceMeters().coerceIn(200, 5000).toFloat()

        if (distanceMeters > startDistanceMeters) {
            NotificationHelper.cancelApproachProgress(this)
            store.clearLiveUpdateAnchorDistanceMeters()
            return
        }

        if (distanceMeters <= ARRIVAL_THRESHOLD_METERS) {
            NotificationHelper.cancelApproachProgress(this)
            store.clearLiveUpdateAnchorDistanceMeters()
            return
        }

        val anchorDistance = store.getLiveUpdateAnchorDistanceMeters()
            ?.takeIf { it > ARRIVAL_THRESHOLD_METERS } ?: distanceMeters.also {
            store.setLiveUpdateAnchorDistanceMeters(it)
        }
        val span = (anchorDistance - ARRIVAL_THRESHOLD_METERS).coerceAtLeast(1f)
        val progress = (((anchorDistance - distanceMeters) / span) * 100f).toInt().coerceIn(0, 100)
        NotificationHelper.showApproachProgress(this, distanceMeters, progress)
    }

    private fun normalizeRotation(value: Float): Float {
        var normalized = value % 360f
        if (normalized > 180f) normalized -= 360f
        if (normalized < -180f) normalized += 360f
        if (abs(normalized) < 0.5f) return 0f
        return normalized
    }

    private fun applyDistanceMaskToggleButtonState() {
        val visible = store.isDistanceMaskButtonVisible()
        distanceMaskToggleButton.visibility = if (visible) View.VISIBLE else View.GONE

        val wasMaskEnabled = store.isManualDistanceMaskEnabled()
        if (!visible && wasMaskEnabled) {
            store.setManualDistanceMaskEnabled(false)
            if (!store.isDestinationAnswered()) {
                updateUi(refreshWidgets = false)
            }
        }

        val enabled = store.isManualDistanceMaskEnabled()
        distanceMaskToggleButton.setImageResource(
            if (enabled) R.drawable.ic_visibility
            else R.drawable.ic_visibility_off
        )
        distanceMaskToggleButton.contentDescription = getString(
            if (enabled) R.string.distance_mask_button_content_description_on
            else R.string.distance_mask_button_content_description_off
        )
        distanceMaskToggleButton.alpha = if (enabled) 1f else 0.68f
    }

    private fun registerScreenCaptureCallbackIfSupported() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
            isScreenCaptureCallbackRegistered
        ) {
            return
        }
        val registered = runCatching {
            registerScreenCaptureCallbackApi34()
        }.isSuccess
        isScreenCaptureCallbackRegistered = registered
    }

    private fun unregisterScreenCaptureCallbackIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
            !isScreenCaptureCallbackRegistered
        ) {
            return
        }
        runCatching {
            unregisterScreenCaptureCallbackApi34()
        }
        isScreenCaptureCallbackRegistered = false
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun registerScreenCaptureCallbackApi34() {
        val callback = Activity.ScreenCaptureCallback {
            onMainScreenCaptured()
        }
        registerScreenCaptureCallback(mainExecutor, callback)
        screenCaptureCallbackRef = callback
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun unregisterScreenCaptureCallbackApi34() {
        val callback = screenCaptureCallbackRef as? Activity.ScreenCaptureCallback ?: return
        unregisterScreenCaptureCallback(callback)
        screenCaptureCallbackRef = null
    }

    private fun onMainScreenCaptured() {
        if (store.isScreenshotWarningEnabled()) {
            Toast.makeText(this, R.string.screenshot_privacy_warning, Toast.LENGTH_LONG).show()
        }
    }

    private fun formatDistanceForMainScreen(distanceMeters: Float): String {
        if (!store.isManualDistanceMaskEnabled()) {
            return GeoUtils.formatDistance(distanceMeters)
        }
        val distanceKm = distanceMeters / 1000f
        val maskedDistanceKm = if (distanceKm <= DISTANCE_MASK_STEP_KM.toFloat()) {
            DISTANCE_MASK_STEP_KM
        } else {
            (ceil(distanceKm / DISTANCE_MASK_STEP_KM).toInt()) * DISTANCE_MASK_STEP_KM
        }
        return getString(R.string.distance_masked_format_km, maskedDistanceKm)
    }

    private fun startLoadingArrowAnimation() {
        if (loadingArrowAnimator?.isRunning == true) {
            return
        }
        loadingArrowAnimator = ObjectAnimator.ofFloat(arrowView, View.ROTATION, 0f, 360f).apply {
            duration = 1400L
            interpolator = LinearInterpolator()
            repeatCount = ObjectAnimator.INFINITE
            start()
        }
    }

    private fun stopLoadingArrowAnimation() {
        loadingArrowAnimator?.cancel()
        loadingArrowAnimator = null
    }

    private fun openAppPermissionSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }
        skipPermissionGuideOnce = true
        runCatching {
            startActivity(intent)
        }.onFailure {
            skipPermissionGuideOnce = false
        }
    }

    private fun registerCompass() {
        sensorManager.unregisterListener(this)
        val preferredType = when (store.getCompassSensorMode()) {
            CompassSensorMode.ROTATION_VECTOR -> Sensor.TYPE_ROTATION_VECTOR
            CompassSensorMode.LEGACY_ORIENTATION -> Sensor.TYPE_ORIENTATION
        }
        val fallbackType = if (preferredType == Sensor.TYPE_ROTATION_VECTOR) {
            Sensor.TYPE_ORIENTATION
        } else {
            Sensor.TYPE_ROTATION_VECTOR
        }
        val sensor = sensorManager.getDefaultSensor(preferredType)
            ?: sensorManager.getDefaultSensor(fallbackType)
        if (sensor != null) {
            sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> {
                headingDegrees = calculateHeadingFromRotationVector(event.values)
                updateUi(refreshWidgets = false)
            }
            Sensor.TYPE_ORIENTATION -> {
                @Suppress("DEPRECATION")
                val azimuth = event.values[0]
                headingDegrees = normalizeTo360(azimuth)
                updateUi(refreshWidgets = false)
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun calculateHeadingFromRotationVector(values: FloatArray): Float {
        SensorManager.getRotationMatrixFromVector(rotationMatrix, values)
        val (xAxis, yAxis) = when (getDisplayRotation()) {
            android.view.Surface.ROTATION_90 -> Pair(SensorManager.AXIS_Y, SensorManager.AXIS_MINUS_X)
            android.view.Surface.ROTATION_180 -> Pair(SensorManager.AXIS_MINUS_X, SensorManager.AXIS_MINUS_Y)
            android.view.Surface.ROTATION_270 -> Pair(SensorManager.AXIS_MINUS_Y, SensorManager.AXIS_X)
            else -> Pair(SensorManager.AXIS_X, SensorManager.AXIS_Y)
        }
        SensorManager.remapCoordinateSystem(
            rotationMatrix,
            xAxis,
            yAxis,
            remappedRotationMatrix
        )
        SensorManager.getOrientation(remappedRotationMatrix, orientationAngles)
        return normalizeTo360(Math.toDegrees(orientationAngles[0].toDouble()).toFloat())
    }

    private fun getDisplayRotation(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display?.rotation ?: android.view.Surface.ROTATION_0
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.rotation
        }
    }

    private fun normalizeTo360(value: Float): Float {
        val mod = value % 360f
        return if (mod < 0f) mod + 360f else mod
    }
}

