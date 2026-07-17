# اسکریپت CI: غیرفعال‌کردن کامل امضای کد (Code Signing) در project.pbxproj
# — کافی نیست فقط تنظیم CODE_SIGNING_ALLOWED=NO در Release.xcconfig شود —
# Xcode مقدار ProvisioningStyle=Automatic را مستقیماً از project.pbxproj
# می‌خواند و پیش از رسیدن به xcconfig، خطای «Development Team لازم است» می‌دهد.
# این نسخه هم Runner.xcodeproj (اپ اصلی) و هم Pods.xcodeproj (پکیج‌های شخص
# ثالث مثل jitsi_meet_flutter_sdk و apivideo_live_stream که فریم‌ورک‌های
# xcframework همراه دارند) را پاکسازی می‌کند، چون همین یک تارگت با
# ProvisioningStyle=Automatic کافی است کل بیلد را متوقف کند.
# نیازمند gem xcodeproj (با نصب CocoaPods می‌آید).
# اجرا در CI: ruby ios/ci_disable_signing.rb (بعد از این‌که pod install
# حداقل یک‌بار اجرا شده و Pods.xcodeproj ساخته شده باشد)

require 'xcodeproj'

def disable_signing_for(project_path)
  unless File.exist?(project_path)
    puts "Skipping #{project_path} (not found yet)."
    return
  end

  project = Xcodeproj::Project.open(project_path)

  project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      config.build_settings['CODE_SIGN_IDENTITY'] = ''
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = '-'
      config.build_settings['DEVELOPMENT_TEAM'] = ''
      config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
    end
  end

  attrs = project.root_object.attributes['TargetAttributes']
  if attrs
    attrs.each do |_, target_attrs|
      target_attrs['ProvisioningStyle'] = 'Manual'
      target_attrs.delete('DevelopmentTeam')
    end
  end

  project.save
  puts "Code signing disabled for all targets/configurations in #{project_path}"
end

runner_project = File.join(__dir__, 'Runner.xcodeproj')
pods_project = File.join(__dir__, 'Pods', 'Pods.xcodeproj')

disable_signing_for(runner_project)
disable_signing_for(pods_project)