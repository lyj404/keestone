// Bypass flaky GitHub Releases redirects (504s) for all builds, including
// Flutter's `:gradle` included build, by prepending Aliyun/Tencent mirrors.
def ALIYUN_PUBLIC = 'https://maven.aliyun.com/repository/public'
def ALIYUN_GOOGLE = 'https://maven.aliyun.com/repository/google'
def ALIYUN_PLUGIN = 'https://maven.aliyun.com/repository/gradle-plugin'

allprojects {
    buildscript {
        repositories {
            maven { url ALIYUN_PUBLIC }
            maven { url ALIYUN_GOOGLE }
            maven { url ALIYUN_PLUGIN }
        }
    }
    repositories {
        maven { url ALIYUN_PUBLIC }
        maven { url ALIYUN_GOOGLE }
        maven { url ALIYUN_PLUGIN }
    }
}

settingsEvaluated { settings ->
    settings.pluginManagement {
        repositories {
            maven { url ALIYUN_PLUGIN }
            maven { url ALIYUN_PUBLIC }
            maven { url ALIYUN_GOOGLE }
        }
    }
    settings.dependencyResolutionManagement {
        repositories {
            maven { url ALIYUN_PUBLIC }
            maven { url ALIYUN_GOOGLE }
            maven { url ALIYUN_PLUGIN }
        }
    }
}
