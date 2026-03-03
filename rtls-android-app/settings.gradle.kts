rootProject.name = "rtls-android-app"
include(":app")
include(":rtls-kmp")
project(":rtls-kmp").projectDir = file("../rtls-kmp")
