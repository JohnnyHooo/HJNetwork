#
# Be sure to run `pod lib lint HJNetwork.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
s.name             = 'HJNetwork'
s.version          = '1.2.6'
s.summary          = 'A short description of HJNetwork.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

s.description      = <<-DESC
HJNetwork对AFHTTPSessionManager进行二次封装，包括网络请求，文件上传，文件下载这三个方法。并且支持RESTful API GET，POST，HEAD，PUT，DELETE，PATCH的请求。同时使用YYCache做了强大的缓存策略。
DESC

s.homepage         = 'https://github.com/JohnnyHooo/HJNetwork'
# s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
s.license          = { :type => 'MIT', :file => 'LICENSE' }
s.author           = { 'Johnny' => 'hujin123@vip.qq.com' }
s.source           = { :git => 'https://github.com/JohnnyHooo/HJNetwork.git', :tag => s.version.to_s }
# s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

s.ios.deployment_target = '10.0'

s.source_files = 'HJNetwork/Classes/**/*'

# s.resource_bundles = {
#   'HJNetwork' => ['HJNetwork/Assets/*.png']
# }

# s.public_header_files = 'Pod/Classes/**/*.h'
# s.frameworks = 'UIKit', 'MapKit'
s.dependency 'YYCache'
s.dependency 'AFNetworking'



end
