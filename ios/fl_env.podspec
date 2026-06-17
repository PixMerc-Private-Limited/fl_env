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
  s.source_files     = 'Classes/**/*'
  s.resources        = 'Classes/Resources/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.9'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end
