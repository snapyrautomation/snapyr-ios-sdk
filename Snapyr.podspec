Pod::Spec.new do |s|
  s.name             = "Snapyr"
  s.module_name      = "Snapyr"
  s.version          = "0.9.0"
  s.summary          = "The hassle-free way to add Snapyr sdk to your iOS app."

  s.description      = <<-DESC
                       Snapyr SDK.
                       DESC

  s.homepage         = "http://snapyr.com/"
  s.license          =  { :type => 'MIT' }
  s.source           = { :git => "https://github.com/snapyrautomation/snapyr-ios-sdk", :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'
  s.osx.deployment_target = '10.13'

  s.static_framework = true  

  s.source_files = [
    'Snapyr/Classes/**/*.{h,m}',
    'Snapyr/Internal/**/*.{h,m}'
  ]
end
