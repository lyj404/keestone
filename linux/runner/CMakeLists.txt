cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "legacy_keyring_migration.cc"
  "secure_storage_channel.cc"
  "autotype_channel.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
# Used by the legacy keyring migration (already a runtime dependency via the
# flutter_secure_storage plugin).
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::SECRET)
# AutoType: X11 grab + XTest keystroke injection (X11 sessions only).
find_package(PkgConfig REQUIRED)
pkg_check_modules(XTST REQUIRED IMPORTED_TARGET xtst)
target_link_libraries(${BINARY_NAME} PRIVATE X11 PkgConfig::XTST)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Copy the application icon to the bundle data directory during build
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/bundle/data"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/app_icon.png"
    "${CMAKE_BINARY_DIR}/bundle/data/app_icon.png"
  COMMENT "Copying application icon to bundle..."
)
