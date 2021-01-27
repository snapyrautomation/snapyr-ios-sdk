Pod::Spec.new do |s|
  s.name             = "Analytics"
  s.module_name      = "Snapyr"
  s.version          = "4.1.2"
  s.summary          = "The hassle-free way to add analytics to your iOS app."

  s.description      = <<-DESC
                       Analytics for iOS provides a single API that lets you
                       integrate with over 100s of tools.
                       DESC

  s.homepage         = "http://snapyr.com/"
  s.license          =  { :type => 'MIT' }
  s.source           = { :git => "https://github.com/snapyrautomation/snapyr-ios-sdk", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/segment'

  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'
  s.osx.deployment_target = '10.13'

  s.static_framework = true  

  s.source_files = [
    'Snapyr/Classes/**/*.{h,m}',
    'Snapyr/Internal/**/*.{h,m}'
  ]
end
