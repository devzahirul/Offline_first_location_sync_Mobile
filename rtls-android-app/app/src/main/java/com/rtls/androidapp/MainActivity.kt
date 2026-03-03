package com.rtls.androidapp

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import com.rtls.kmp.LocationSyncClientEvent
import com.rtls.kmp.RTLSKmp
import com.rtls.androidapp.databinding.ActivityMainBinding
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private var client: com.rtls.kmp.LocationSyncClient? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.etBaseUrl.setText("http://10.0.2.2:3000")
        binding.etUserId.setText("android-user-1")
        binding.etDeviceId.setText("android-device-1")
        binding.etToken.setText("demo-token")

        requestLocationPermission()

        binding.btnConfigure.setOnClickListener { configure() }
        binding.btnStart.setOnClickListener { startTracking() }
        binding.btnStop.setOnClickListener { stopTracking() }
        binding.btnFlush.setOnClickListener { flush() }
    }

    private fun requestLocationPermission() {
        val perms = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            perms.add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }
        val missing = perms.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isNotEmpty()) {
            requestPermissions(missing.toTypedArray(), 100)
        }
    }

    private fun configure() {
        val baseUrl = binding.etBaseUrl.text.toString().trim()
        val userId = binding.etUserId.text.toString().trim()
        val deviceId = binding.etDeviceId.text.toString().trim()
        val token = binding.etToken.text.toString().trim()
        if (baseUrl.isEmpty() || userId.isEmpty() || deviceId.isEmpty()) {
            Toast.makeText(this, "Fill base URL, userId, deviceId", Toast.LENGTH_SHORT).show()
            return
        }
        client?.stopTracking()
        client = RTLSKmp.createLocationSyncClient(this, baseUrl, userId, deviceId, token)
        lifecycleScope.launch {
            client?.events?.collectLatest { event ->
                runOnUiThread {
                    when (event) {
                        is LocationSyncClientEvent.Recorded ->
                            binding.tvLastEvent.text = "Last: ${event.point.lat}, ${event.point.lng}"
                        is LocationSyncClientEvent.SyncEvent ->
                            binding.tvLastEvent.text = "Sync: ${event.event}"
                        is LocationSyncClientEvent.Error ->
                            binding.tvLastEvent.text = "Error: ${event.message}"
                        LocationSyncClientEvent.TrackingStarted ->
                            binding.tvLastEvent.text = "Tracking started"
                        LocationSyncClientEvent.TrackingStopped ->
                            binding.tvLastEvent.text = "Tracking stopped"
                    }
                    refreshStats()
                }
            }
        }
        binding.btnConfigure.isVisible = false
        refreshStats()
        Toast.makeText(this, "Configured", Toast.LENGTH_SHORT).show()
    }

    private fun startTracking() {
        val c = client ?: return
        val userId = binding.etUserId.text.toString().trim()
        val deviceId = binding.etDeviceId.text.toString().trim()
        val flow = RTLSKmp.createLocationFlow(this, userId, deviceId)
        c.startCollectingLocation(flow)
        refreshStats()
    }

    private fun stopTracking() {
        client?.stopTracking()
        refreshStats()
    }

    private fun flush() {
        lifecycleScope.launch {
            client?.flushNow()
            refreshStats()
        }
    }

    private fun refreshStats() {
        lifecycleScope.launch {
            val stats = client?.stats() ?: return@launch
            binding.tvStatus.text = "Pending: ${stats.pendingCount}"
        }
    }
}
