// Bypass flaky GitHub Releases redirects (504s) for all builds, including
// Flutter's `:gradle` included build, by prepending Aliyun mirrors.
val aliyunPublic = "https://maven.aliyun.com/repository/public"
val aliyunGoogle = "https://maven.aliyun.com/repository/google"
val aliyunPlugin = "https://maven.aliyun.com/repository/gradle-plugin"

allprojects {
    buildscript {
        repositories {
            maven { url = uri(aliyunPublic) }
            maven { url = uri(aliyunGoogle) }
            maven { url = uri(aliyunPlugin) }
        }
    }
    repositories {
        maven { url = uri(aliyunPublic) }
        maven { url = uri(aliyunGoogle) }
        maven { url = uri(aliyunPlugin) }
    }
}

settingsEvaluated {
    pluginManagement {
        repositories {
            maven { url = uri(aliyunPlugin) }
            maven { url = uri(aliyunPublic) }
            maven { url = uri(aliyunGoogle) }
        }
    }
    dependencyResolutionManagement {
        repositories {
            maven { url = uri(aliyunPublic) }
            maven { url = uri(aliyunGoogle) }
            maven { url = uri(aliyunPlugin) }
        }
    }
}
