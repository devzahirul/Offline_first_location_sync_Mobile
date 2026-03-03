Pod::Spec.new do |s|
  s.name             = 'rtls_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for offline-first location sync (iOS uses RTLSyncKit).'
  s.homepage         = 'https://github.com/devzahirul/Offline_first_location_sync_iOS'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'RTLS' => '' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.deployment_target = '15.0'
  s.dependency 'Flutter'
  s.swift_version = '5.0'
  # Host app must add the RTLSyncKit Swift package in Xcode (path to repo root).
  s.xcconfig = { 'OTHER_SWIFT_FLAGS' => '-no-objc-arc' }
end
