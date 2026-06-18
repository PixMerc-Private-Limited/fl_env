Pod::Spec.new do |s|
  s.name             = 'fl_env'
  s.version          = '0.1.0'
  s.summary          = 'Secure .env encryption for Flutter — native decryption at runtime.'
  s.description      = <<-DESC
    fl_env encrypts your .env files at build time and decrypts them natively
    on Android and iOS at runtime, using AES-256-GCM with HKDF-SHA256 key derivation.
  DESC
  s.homepage         = 'https://github.com/pixmerc/fl_env'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'PixMerc' => 'dev@pixmerc.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{swift,h,m}'
  # Resources (FlEnvKey.bin, FlEnvRegistry.bin) are written by `fl_env build`
  # into the consumer's app bundle (ios/Runner/ by default) and added to Xcode's
  # Copy Bundle Resources phase via the Podfile hook that `fl_env setup` installs.
  # The plugin reads them from Bundle.main at runtime.
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.9'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end
