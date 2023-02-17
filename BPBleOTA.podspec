#
# Be sure to run `pod lib lint BPBleOTA.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'BPBleOTA'
  s.version          = '0.1.0'
  s.summary          = 'BPBleOTA is a swift library support NordicDFU and SMPDFU for compatible devices'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'BPBleOTA is a swift library support NordicDFU and SMPDFU for compatible devices. It depended on iOSDFULibrary and iOSMcuManagerLibrary,so can support NordicDFU and SMPDFU by BLE. All things BPBleOTA done are aggregating them and provide a unified interface，So it can support pure Objective-C projects which are not supported directly by NordicDFU and SMPDFU'

  s.homepage         = 'https://github.com/zhxf2012/BPBleOTA'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'zhouxingfa' => 'zhouxingfa@bibibetter.com' }
  #s.source           = { :git => 'https://github.com/zhxf2012/BPBleOTA.git', :tag => s.version.to_s }
  s.source           = { :git => 'https://github.com/zhxf2012/BPBleOTA.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = {'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }


  s.source_files = 'BPBleOTA/Classes/**/*'
  
  # s.resource_bundles = {
  #   'BPBleOTA' => ['BPBleOTA/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
   s.dependency 'iOSDFULibrary', '~> 4.13.0'
   s.dependency 'iOSMcuManagerLibrary' ,"~> 1.2.7.0"
end
