// Bypass flaky GitHub Releases redirects (504s) for all builds, including
// Flutter's `:gradle` included build, by prepending Aliyun mirrors.
// Inject only at settings level (before evaluation): project-level repos
// are forbidden by builds that prefer settings repositories.
val aliyunPublic = "https://maven.aliyun.com/repository/public"
val aliyunGoogle = "https://maven.aliyun.com/repository/google"
val aliyunPlugin = "https://maven.aliyun.com/repository/gradle-plugin"

beforeSettings {
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
