# اسکریپت CI: غیرفعال‌کردن کامل امضای کد (Code Signing) در project.pbxproj
# چون فقط تنظیم CODE_SIGNING_ALLOWED=NO در Release.xcconfig کافی نیست —
# Xcode مقدار ProvisioningStyle=Automatic را مستقیماً از project.pbxproj
# می‌خواند و پیش از رسیدن به xcconfig، خطای «Development Team لازم است»
# می‌دهد. این اسکریپت با gem xcodeproj (که همراه CocoaPods نصب است)
# امضا را برای همهٔ Target ها و پیکربندی‌ها به‌صورت Manual/خالی تنظیم می‌کند.
#
# اجرا در CI: ruby ios/ci_disable_signing.rb

require 'xcodeproj'

project_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
    config.build_settings['CODE_SIGN_IDENTITY'] = ''
    config.build_settings['DEVELOPMENT_TEAM'] = ''
    config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
    config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
  end
end

attrs = project.root_object.attributes['TargetAttributes']
if attrs
  attrs.each do |_, target_attrs|
    target_attrs['ProvisioningStyle'] = 'Manual'
  end
end

project.save

puts 'Code signing disabled for all targets/configurations.'
