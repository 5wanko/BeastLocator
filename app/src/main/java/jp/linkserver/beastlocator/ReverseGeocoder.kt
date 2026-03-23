package jp.linkserver.beastlocator

import android.content.Context
import android.location.Geocoder
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale

enum class GeocodingProvider(val prefValue: String) {
    GEOCODER("geocoder"),
    PHOTON("photon"),
    NOMINATIM("nominatim");

    companion object {
        fun fromPref(value: String?): GeocodingProvider {
            return entries.firstOrNull { it.prefValue == value } ?: GEOCODER
        }
    }
}

object ReverseGeocoder {
    fun resolve(context: Context, destination: Destination, provider: GeocodingProvider): String {
        return when (provider) {
            GeocodingProvider.GEOCODER -> resolveWithAndroidGeocoder(context, destination)
            GeocodingProvider.PHOTON -> resolveWithPhoton(destination)
            GeocodingProvider.NOMINATIM -> resolveWithNominatim(destination)
        }
    }

    private fun resolveWithAndroidGeocoder(context: Context, destination: Destination): String {
        return try {
            val geocoder = Geocoder(context, Locale.JAPAN)
            @Suppress("DEPRECATION")
            val address = geocoder.getFromLocation(destination.lat, destination.lng, 1)
                ?.firstOrNull()
                ?.getAddressLine(0)
            address ?: fallbackLatLng(destination)
        } catch (_: Exception) {
            fallbackLatLng(destination)
        }
    }

    private fun resolveWithPhoton(destination: Destination): String {
        return try {
            val url = "https://photon.komoot.io/reverse?lat=${destination.lat}&lon=${destination.lng}&lang=ja&limit=1"
            val json = requestJson(url)
            val features = json.optJSONArray("features")
            val properties = features?.optJSONObject(0)?.optJSONObject("properties")
            if (properties == null) return fallbackLatLng(destination)

            val prefecture = firstNotBlank(
                properties.optString("state"),
                properties.optString("county")
            )
            val city = firstNotBlank(
                properties.optString("city"),
                properties.optString("town"),
                properties.optString("village"),
                properties.optString("locality")
            )
            val district = firstNotBlank(
                properties.optString("district"),
                properties.optString("suburb"),
                properties.optString("neighbourhood"),
                properties.optString("hamlet"),
                properties.optString("street"),
                properties.optString("name")
            )

            composeAddress(
                prefecture = prefecture,
                city = city,
                district = district,
                fallback = fallbackLatLng(destination)
            )
        } catch (_: Exception) {
            fallbackLatLng(destination)
        }
    }

    private fun resolveWithNominatim(destination: Destination): String {
        return try {
            val lat = URLEncoder.encode(destination.lat.toString(), "UTF-8")
            val lon = URLEncoder.encode(destination.lng.toString(), "UTF-8")
            val url =
                "https://nominatim.openstreetmap.org/reverse" +
                    "?format=jsonv2" +
                    "&lat=$lat" +
                    "&lon=$lon" +
                    "&accept-language=ja" +
                    "&zoom=18" +
                    "&addressdetails=1" +
                    "&namedetails=1"
            val json = requestJson(url)
            val address = json.optJSONObject("address")

            val prefecture = firstNotBlank(
                address?.optString("state"),
                address?.optString("region"),
                address?.optString("county")
            )
            val city = firstNotBlank(
                address?.optString("city"),
                address?.optString("town"),
                address?.optString("village"),
                address?.optString("municipality")
            )
            val district = firstNotBlank(
                address?.optString("city_district"),
                address?.optString("suburb"),
                address?.optString("neighbourhood"),
                address?.optString("quarter"),
                address?.optString("hamlet")
            )
            val road = firstNotBlank(
                address?.optString("road"),
                address?.optString("pedestrian"),
                address?.optString("footway")
            )
            val houseNumber = firstNotBlank(address?.optString("house_number"))
            val roadPart = listOf(road, houseNumber).filter { !it.isNullOrBlank() }.joinToString("")

            val displayName = json.optString("display_name").takeIf { it.isNotBlank() }
                ?: fallbackLatLng(destination)

            composeAddress(prefecture, city, district, roadPart, displayName)
        } catch (_: Exception) {
            fallbackLatLng(destination)
        }
    }

    private fun composeAddress(
        prefecture: String?,
        city: String?,
        district: String?,
        roadPart: String? = null,
        fallback: String
    ): String {
        val parts = listOf(prefecture, city, district, roadPart).filter { !it.isNullOrBlank() }
        return if (parts.isNotEmpty()) parts.joinToString("") else fallback
    }

    private fun requestJson(url: String): JSONObject {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 8000
            readTimeout = 8000
            requestMethod = "GET"
            setRequestProperty("Accept", "application/json")
            setRequestProperty(
                "User-Agent",
                "BeastLocator/1.0 (+https://example.local; reverse-geocoding)"
            )
        }
        conn.inputStream.bufferedReader().use { reader ->
            return JSONObject(reader.readText())
        }
    }

    private fun firstNotBlank(vararg values: String?): String? {
        return values.firstOrNull { !it.isNullOrBlank() }
    }

    private fun fallbackLatLng(destination: Destination): String {
        return "${destination.lat}, ${destination.lng}"
    }
}


