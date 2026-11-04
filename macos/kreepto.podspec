Pod::Spec.new do |s|
  s.name             = 'kreepto'
  s.version          = '0.1.0'
  s.summary          = 'KeeStone native crypto engine (Rust).'
  s.description      = <<-DESC
  Rust implementation of KDBX crypto primitives (argon2, aes, chacha20, salsa20)
  exposed to Flutter via dart:ffi. Bundled as a dylib in the macOS app so that
  DynamicLibrary.open('libkreepto.dylib') resolves the FFI symbols.
                       DESC
  s.homepage         = 'https://github.com/lyj404/keestone'
  s.license          = { :type => 'Apache-2.0', :file => '../LICENSE' }
  s.author           = { 'lyj404' => 'lyj404@proton.me' }
  s.source           = { :path => '.' }

  s.osx.deployment_target = '12.0'
  s.swift_version         = '5.0'

  # Build the universal Rust dynamic library before the pod is integrated.
  s.prepare_command = 'sh scripts/build_kreepto_macos.sh'

  # The universal dylib produced by the prepare_command. CocoaPods copies
  # vendored libraries into the app bundle's Frameworks directory during the
  # copy-frameworks phase, and @rpath resolves them at load time.
  s.vendored_libraries = 'build/macos/libkreepto.dylib'

  s.source_files = []
  s.preserve_paths = ['build/macos/**/*']

  s.libraries = 'c++'
end
