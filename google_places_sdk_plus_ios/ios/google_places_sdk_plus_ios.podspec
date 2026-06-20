#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint google_places_sdk_plus_ios.podspec` to validate before publishing.
#
# NOTE: CocoaPods is supported but Swift Package Manager (SPM) is preferred.
# See Package.swift in this directory for SPM configuration.
#
Pod::Spec.new do |s|
  s.name             = 'google_places_sdk_plus_ios'
  s.version          = '0.3.1'
  s.summary          = 'iOS implementation of the Flutter Google Places SDK plugin.'
  s.description      = <<-DESC
iOS implementation of the Flutter Google Places SDK plugin, providing access to the
Google Places API (New) including place details, autocomplete, text search, and nearby search.
                       DESC
  s.homepage         = 'https://github.com/KamiloChinome/google_places_sdk_plus/tree/master/google_places_sdk_plus_ios'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Kamilo Chinome' => '' }
  s.source           = { :path => '.' }
  # Sources live under the Swift Package Manager layout; CocoaPods and SPM share
  # the same source directory so there is a single source of truth.
  s.source_files = 'google_places_sdk_plus_ios/Sources/google_places_sdk_plus_ios/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Dependencies
  s.dependency 'GooglePlaces', '~> 10.1.0'
  s.static_framework = true
end
