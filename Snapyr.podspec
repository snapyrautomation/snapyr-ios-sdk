Pod::Spec.new do |s|
  s.name             = "Snapyr"
  s.module_name      = "Snapyr"
  s.authors          = "Snapyr"
  s.version          = "1.0.0"
  s.summary          = "Adding Snapyr tracking to an iOS app."

  s.description      = <<-DESC
                       Snapyr for iOS lets you track everything you need to
                       run complex marketing campaigns using the Snapyr
                       platform.
                       DESC

  s.homepage         = "http://snapyr.com/"
  s.license          =  { :type => 'MIT' }
  s.source           = { :git => "https://github.com/snapyrautomation/snapyr-ios-sdk.git", :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.static_framework = true  

  s.source_files = [
    'Snapyr/Classes/**/*.{h,m}',
    'Snapyr/Internal/**/*.{h,m}'
  ]
end
