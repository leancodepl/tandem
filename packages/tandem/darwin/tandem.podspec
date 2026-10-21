Pod::Spec.new do |s|
  s.name = 'tandem'
  s.version = '0.1.0'
  s.summary = 'An AG-UI connection to Apple Foundation Models.'
  s.homepage = 'https://github.com/leancodepl/tandem'
  s.license = { :file => '../LICENSE' }
  s.author = { 'LeanCode' => 'contact@leancode.pl' }
  s.source = { :path => '.' }
  s.source_files = 'tandem/Sources/tandem/**/*.swift'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
