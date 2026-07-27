#!/usr/bin/env python3
"""
生成 iOS/Masaiki.xcodeproj（不依赖 XcodeGen，不依赖 SwiftPM）。
直接把 MasaikiCore 的 5 个源码文件和 iOS 端的 5 个 Swift 文件一起加入到
单一 iOS Application target 中，避免 SwiftPM 试图为 iOS 构建 macOS 的
Masaiki executable target。
"""
import os
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IOS_DIR = ROOT / "iOS"
PROJECT_DIR = IOS_DIR / "Masaiki.xcodeproj"
PBXPROJ = PROJECT_DIR / "project.pbxproj"

PROJECT_DIR.mkdir(exist_ok=True)


def gid():
    return uuid.uuid4().hex.upper()[:24]


# iOS 端源码 (相对 iOS/ 目录)
IOS_SWIFT_FILES = [
    "Masaiki/App/MasaikiApp.swift",
    "Masaiki/App/AppViewModel.swift",
    "Masaiki/Views/ContentView.swift",
    "Masaiki/Views/EditorView.swift",
    "Masaiki/Views/ImageStripView.swift",
]

# MasaikiCore 共享源码 (相对项目根目录) —— 通过相对路径 ../Sources/... 引入
CORE_SWIFT_FILES = [
    "../Sources/MasaikiCore/Models/BlurRegion.swift",
    "../Sources/MasaikiCore/Models/ImageItem.swift",
    "../Sources/MasaikiCore/Services/FaceDetectionService.swift",
    "../Sources/MasaikiCore/Services/ImageIOService.swift",
    "../Sources/MasaikiCore/Services/ImageProcessingService.swift",
]

ALL_SWIFT = IOS_SWIFT_FILES + CORE_SWIFT_FILES

INFO_PLIST_PATH = "Masaiki/Resources/Info.plist"
ENTITLEMENTS_PATH = "Masaiki/Resources/Masaiki.entitlements"
PRIVACY_PATH = "Masaiki/Resources/PrivacyInfo.xcprivacy"
ICON_PATHS = [
    "Masaiki/Resources/AppIcon-120.png",
    "Masaiki/Resources/AppIcon-180.png",
    "Masaiki/Resources/AppIcon-152.png",
    "Masaiki/Resources/AppIcon-167.png",
]

FILE_REFS = {
    p: gid()
    for p in ALL_SWIFT + [INFO_PLIST_PATH, ENTITLEMENTS_PATH, PRIVACY_PATH] + ICON_PATHS
}
BUILD_FILES = {p: gid() for p in ALL_SWIFT + [PRIVACY_PATH] + ICON_PATHS}

PROJECT_ID = gid()
MAIN_GROUP_ID = gid()
PRODUCTS_GROUP_ID = gid()
MASAIKI_GROUP_ID = gid()
APP_GROUP_ID = gid()
VIEWS_GROUP_ID = gid()
RESOURCES_GROUP_ID = gid()
CORE_GROUP_ID = gid()
CORE_MODELS_GROUP_ID = gid()
CORE_SERVICES_GROUP_ID = gid()
TARGET_ID = gid()
BUILD_CONFIG_LIST_TARGET_ID = gid()
BUILD_CONFIG_LIST_PROJECT_ID = gid()
BUILD_CONFIG_TARGET_DEBUG_ID = gid()
BUILD_CONFIG_TARGET_RELEASE_ID = gid()
BUILD_CONFIG_PROJECT_DEBUG_ID = gid()
BUILD_CONFIG_PROJECT_RELEASE_ID = gid()
SOURCES_PHASE_ID = gid()
FRAMEWORKS_PHASE_ID = gid()
RESOURCES_PHASE_ID = gid()
APP_FILE_REF_ID = gid()


def type_for(path):
    if path.endswith(".swift"):
        return "sourcecode.swift"
    if path.endswith(".png"):
        return "image.png"
    if path.endswith(".plist"):
        return "text.plist.xml"
    if path.endswith(".entitlements"):
        return "text.plist.entitlements"
    if path.endswith(".xcprivacy"):
        return "text.plist.xml"
    return "text"


pbxproj = ['// !$*UTF8*$!', '{',
           '\tarchiveVersion = 1;',
           '\tclasses = {',
           '\t};',
           '\tobjectVersion = 56;',
           '\tobjects = {', '']

# PBXBuildFile
pbxproj.append('/* Begin PBXBuildFile section */')
for p in ALL_SWIFT:
    pbxproj.append(f'\t\t{BUILD_FILES[p]} /* {os.path.basename(p)} in Sources */ = '
                   f'{{isa = PBXBuildFile; fileRef = {FILE_REFS[p]} /* {os.path.basename(p)} */; }};')
pbxproj.append(f'\t\t{BUILD_FILES[PRIVACY_PATH]} /* PrivacyInfo.xcprivacy in Resources */ = '
               f'{{isa = PBXBuildFile; fileRef = {FILE_REFS[PRIVACY_PATH]} /* PrivacyInfo.xcprivacy */; }};')
for p in ICON_PATHS:
    pbxproj.append(f'\t\t{BUILD_FILES[p]} /* {os.path.basename(p)} in Resources */ = '
                   f'{{isa = PBXBuildFile; fileRef = {FILE_REFS[p]} /* {os.path.basename(p)} */; }};')
pbxproj.append('/* End PBXBuildFile section */\n')

# PBXFileReference
pbxproj.append('/* Begin PBXFileReference section */')
for p in ALL_SWIFT:
    basename = os.path.basename(p)
    if p.startswith("../"):
        # 用完整相对路径引用外部源码
        pbxproj.append(f'\t\t{FILE_REFS[p]} /* {basename} */ = {{isa = PBXFileReference; '
                       f'lastKnownFileType = {type_for(p)}; name = "{basename}"; path = "{p}"; sourceTree = "<group>"; }};')
    else:
        pbxproj.append(f'\t\t{FILE_REFS[p]} /* {basename} */ = {{isa = PBXFileReference; '
                       f'lastKnownFileType = {type_for(p)}; path = "{basename}"; sourceTree = "<group>"; }};')

for p in [INFO_PLIST_PATH, ENTITLEMENTS_PATH, PRIVACY_PATH] + ICON_PATHS:
    basename = os.path.basename(p)
    pbxproj.append(f'\t\t{FILE_REFS[p]} /* {basename} */ = {{isa = PBXFileReference; '
                   f'lastKnownFileType = {type_for(p)}; path = "{basename}"; sourceTree = "<group>"; }};')

pbxproj.append(f'\t\t{APP_FILE_REF_ID} /* Masaiki.app */ = {{isa = PBXFileReference; '
               f'explicitFileType = wrapper.application; includeInIndex = 0; path = Masaiki.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
pbxproj.append('/* End PBXFileReference section */\n')

# PBXFrameworksBuildPhase
pbxproj.append('/* Begin PBXFrameworksBuildPhase section */')
pbxproj.append(f'\t\t{FRAMEWORKS_PHASE_ID} /* Frameworks */ = {{')
pbxproj.append('\t\t\tisa = PBXFrameworksBuildPhase;')
pbxproj.append('\t\t\tbuildActionMask = 2147483647;')
pbxproj.append('\t\t\tfiles = (')
pbxproj.append('\t\t\t);')
pbxproj.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
pbxproj.append('\t\t};')
pbxproj.append('/* End PBXFrameworksBuildPhase section */\n')


def group(gid_, name, children, path=None):
    lines = [f'\t\t{gid_} /* {name} */ = {{', '\t\t\tisa = PBXGroup;', '\t\t\tchildren = (']
    for c in children:
        lines.append(f'\t\t\t\t{c},')
    lines.append('\t\t\t);')
    if path:
        lines.append(f'\t\t\tpath = {path};')
    else:
        lines.append(f'\t\t\tname = "{name}";')
    lines.append('\t\t\tsourceTree = "<group>";')
    lines.append('\t\t};')
    return '\n'.join(lines)


app_children = [f'{FILE_REFS[p]} /* {os.path.basename(p)} */' for p in IOS_SWIFT_FILES if "/App/" in p]
views_children = [f'{FILE_REFS[p]} /* {os.path.basename(p)} */' for p in IOS_SWIFT_FILES if "/Views/" in p]
resources_children = [f'{FILE_REFS[INFO_PLIST_PATH]} /* Info.plist */',
                      f'{FILE_REFS[ENTITLEMENTS_PATH]} /* Masaiki.entitlements */',
                      f'{FILE_REFS[PRIVACY_PATH]} /* PrivacyInfo.xcprivacy */'] + [
                      f'{FILE_REFS[p]} /* {os.path.basename(p)} */' for p in ICON_PATHS]
core_models_children = [f'{FILE_REFS[p]} /* {os.path.basename(p)} */'
                        for p in CORE_SWIFT_FILES if "/Models/" in p]
core_services_children = [f'{FILE_REFS[p]} /* {os.path.basename(p)} */'
                          for p in CORE_SWIFT_FILES if "/Services/" in p]

pbxproj.append('/* Begin PBXGroup section */')
pbxproj.append(group(MAIN_GROUP_ID, "Main",
                     [f'{MASAIKI_GROUP_ID} /* Masaiki */',
                      f'{CORE_GROUP_ID} /* MasaikiCore */',
                      f'{PRODUCTS_GROUP_ID} /* Products */']))
pbxproj.append(group(MASAIKI_GROUP_ID, "Masaiki",
                     [f'{APP_GROUP_ID} /* App */',
                      f'{VIEWS_GROUP_ID} /* Views */',
                      f'{RESOURCES_GROUP_ID} /* Resources */'],
                     path="Masaiki"))
pbxproj.append(group(APP_GROUP_ID, "App", app_children, path="App"))
pbxproj.append(group(VIEWS_GROUP_ID, "Views", views_children, path="Views"))
pbxproj.append(group(RESOURCES_GROUP_ID, "Resources", resources_children, path="Resources"))
pbxproj.append(group(CORE_GROUP_ID, "MasaikiCore",
                     [f'{CORE_MODELS_GROUP_ID} /* Models */',
                      f'{CORE_SERVICES_GROUP_ID} /* Services */']))
pbxproj.append(group(CORE_MODELS_GROUP_ID, "Models", core_models_children))
pbxproj.append(group(CORE_SERVICES_GROUP_ID, "Services", core_services_children))
pbxproj.append(group(PRODUCTS_GROUP_ID, "Products", [f'{APP_FILE_REF_ID} /* Masaiki.app */']))
pbxproj.append('/* End PBXGroup section */\n')

# PBXNativeTarget
pbxproj.append('/* Begin PBXNativeTarget section */')
pbxproj.append(f'\t\t{TARGET_ID} /* Masaiki */ = {{')
pbxproj.append('\t\t\tisa = PBXNativeTarget;')
pbxproj.append(f'\t\t\tbuildConfigurationList = {BUILD_CONFIG_LIST_TARGET_ID} /* Build configuration list for PBXNativeTarget "Masaiki" */;')
pbxproj.append('\t\t\tbuildPhases = (')
pbxproj.append(f'\t\t\t\t{SOURCES_PHASE_ID} /* Sources */,')
pbxproj.append(f'\t\t\t\t{FRAMEWORKS_PHASE_ID} /* Frameworks */,')
pbxproj.append(f'\t\t\t\t{RESOURCES_PHASE_ID} /* Resources */,')
pbxproj.append('\t\t\t);')
pbxproj.append('\t\t\tbuildRules = (')
pbxproj.append('\t\t\t);')
pbxproj.append('\t\t\tdependencies = (')
pbxproj.append('\t\t\t);')
pbxproj.append('\t\t\tname = Masaiki;')
pbxproj.append('\t\t\tproductName = Masaiki;')
pbxproj.append(f'\t\t\tproductReference = {APP_FILE_REF_ID} /* Masaiki.app */;')
pbxproj.append('\t\t\tproductType = "com.apple.product-type.application";')
pbxproj.append('\t\t};')
pbxproj.append('/* End PBXNativeTarget section */\n')

# PBXProject
pbxproj.append('/* Begin PBXProject section */')
pbxproj.append(f'\t\t{PROJECT_ID} /* Project object */ = {{')
pbxproj.append('\t\t\tisa = PBXProject;')
pbxproj.append('\t\t\tattributes = {')
pbxproj.append('\t\t\t\tBuildIndependentTargetsInParallel = YES;')
pbxproj.append('\t\t\t\tLastSwiftUpdateCheck = 1500;')
pbxproj.append('\t\t\t\tLastUpgradeCheck = 1500;')
pbxproj.append('\t\t\t\tTargetAttributes = {')
pbxproj.append(f'\t\t\t\t\t{TARGET_ID} = {{')
pbxproj.append('\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;')
pbxproj.append('\t\t\t\t\t};')
pbxproj.append('\t\t\t\t};')
pbxproj.append('\t\t\t};')
pbxproj.append(f'\t\t\tbuildConfigurationList = {BUILD_CONFIG_LIST_PROJECT_ID} /* Build configuration list for PBXProject */;')
pbxproj.append('\t\t\tcompatibilityVersion = "Xcode 14.0";')
pbxproj.append('\t\t\tdevelopmentRegion = zh-Hans;')
pbxproj.append('\t\t\thasScannedForEncodings = 0;')
pbxproj.append('\t\t\tknownRegions = (')
pbxproj.append('\t\t\t\tzh-Hans,')
pbxproj.append('\t\t\t\tBase,')
pbxproj.append('\t\t\t\ten,')
pbxproj.append('\t\t\t);')
pbxproj.append(f'\t\t\tmainGroup = {MAIN_GROUP_ID};')
pbxproj.append(f'\t\t\tproductRefGroup = {PRODUCTS_GROUP_ID} /* Products */;')
pbxproj.append('\t\t\tprojectDirPath = "";')
pbxproj.append('\t\t\tprojectRoot = "";')
pbxproj.append('\t\t\ttargets = (')
pbxproj.append(f'\t\t\t\t{TARGET_ID} /* Masaiki */,')
pbxproj.append('\t\t\t);')
pbxproj.append('\t\t};')
pbxproj.append('/* End PBXProject section */\n')

# PBXResourcesBuildPhase
pbxproj.append('/* Begin PBXResourcesBuildPhase section */')
pbxproj.append(f'\t\t{RESOURCES_PHASE_ID} /* Resources */ = {{')
pbxproj.append('\t\t\tisa = PBXResourcesBuildPhase;')
pbxproj.append('\t\t\tbuildActionMask = 2147483647;')
pbxproj.append('\t\t\tfiles = (')
pbxproj.append(f'\t\t\t\t{BUILD_FILES[PRIVACY_PATH]} /* PrivacyInfo.xcprivacy in Resources */,')
for p in ICON_PATHS:
    pbxproj.append(f'\t\t\t\t{BUILD_FILES[p]} /* {os.path.basename(p)} in Resources */,')
pbxproj.append('\t\t\t);')
pbxproj.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
pbxproj.append('\t\t};')
pbxproj.append('/* End PBXResourcesBuildPhase section */\n')

# PBXSourcesBuildPhase
pbxproj.append('/* Begin PBXSourcesBuildPhase section */')
pbxproj.append(f'\t\t{SOURCES_PHASE_ID} /* Sources */ = {{')
pbxproj.append('\t\t\tisa = PBXSourcesBuildPhase;')
pbxproj.append('\t\t\tbuildActionMask = 2147483647;')
pbxproj.append('\t\t\tfiles = (')
for p in ALL_SWIFT:
    pbxproj.append(f'\t\t\t\t{BUILD_FILES[p]} /* {os.path.basename(p)} in Sources */,')
pbxproj.append('\t\t\t);')
pbxproj.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
pbxproj.append('\t\t};')
pbxproj.append('/* End PBXSourcesBuildPhase section */\n')


def config_project(cid, name, is_release):
    lines = [f'\t\t{cid} /* {name} */ = {{',
             '\t\t\tisa = XCBuildConfiguration;',
             '\t\t\tbuildSettings = {',
             '\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;',
             '\t\t\t\tCLANG_ANALYZER_NONNULL = YES;',
             '\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";',
             '\t\t\t\tCLANG_ENABLE_MODULES = YES;',
             '\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;',
             '\t\t\t\tCOPY_PHASE_STRIP = NO;',
             f'\t\t\t\tDEBUG_INFORMATION_FORMAT = "{"dwarf-with-dsym" if is_release else "dwarf"}";',
             '\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;',
             '\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;',
             '\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;',
             '\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;',
             '\t\t\t\tSDKROOT = iphoneos;',
             f'\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "{"DEBUG" if not is_release else ""}";',
             f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "{"-Onone" if not is_release else "-O"}";',
             '\t\t\t\tSWIFT_VERSION = 5.0;',
             '\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";',
             '\t\t\t\tVALIDATE_PRODUCT = YES;',
             '\t\t\t};',
             f'\t\t\tname = {name};',
             '\t\t};']
    return '\n'.join(lines)


def config_target(cid, name):
    lines = [f'\t\t{cid} /* {name} */ = {{',
             '\t\t\tisa = XCBuildConfiguration;',
             '\t\t\tbuildSettings = {',
             '\t\t\t\tCODE_SIGN_STYLE = Automatic;',
             '\t\t\t\tCURRENT_PROJECT_VERSION = 1;',
             '\t\t\t\tGENERATE_INFOPLIST_FILE = NO;',
             '\t\t\t\tINFOPLIST_FILE = "Masaiki/Resources/Info.plist";',
             '\t\t\t\tCODE_SIGN_ENTITLEMENTS = "Masaiki/Resources/Masaiki.entitlements";',
             '\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");',
             '\t\t\t\tMARKETING_VERSION = 1.0.0;',
             '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.example.masaiki";',
             '\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";',
             '\t\t\t\tSDKROOT = iphoneos;',
             '\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
             '\t\t\t\tSUPPORTS_MACCATALYST = NO;',
             '\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;',
             '\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;',
             '\t\t\t\tSWIFT_VERSION = 5.0;',
             '\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";',
             '\t\t\t};',
             f'\t\t\tname = {name};',
             '\t\t};']
    return '\n'.join(lines)


pbxproj.append('/* Begin XCBuildConfiguration section */')
pbxproj.append(config_project(BUILD_CONFIG_PROJECT_DEBUG_ID, "Debug", False))
pbxproj.append(config_project(BUILD_CONFIG_PROJECT_RELEASE_ID, "Release", True))
pbxproj.append(config_target(BUILD_CONFIG_TARGET_DEBUG_ID, "Debug"))
pbxproj.append(config_target(BUILD_CONFIG_TARGET_RELEASE_ID, "Release"))
pbxproj.append('/* End XCBuildConfiguration section */\n')

# XCConfigurationList
pbxproj.append('/* Begin XCConfigurationList section */')
pbxproj.append(f'\t\t{BUILD_CONFIG_LIST_PROJECT_ID} /* Build configuration list for PBXProject */ = {{')
pbxproj.append('\t\t\tisa = XCConfigurationList;')
pbxproj.append('\t\t\tbuildConfigurations = (')
pbxproj.append(f'\t\t\t\t{BUILD_CONFIG_PROJECT_DEBUG_ID} /* Debug */,')
pbxproj.append(f'\t\t\t\t{BUILD_CONFIG_PROJECT_RELEASE_ID} /* Release */,')
pbxproj.append('\t\t\t);')
pbxproj.append('\t\t\tdefaultConfigurationIsVisible = 0;')
pbxproj.append('\t\t\tdefaultConfigurationName = Release;')
pbxproj.append('\t\t};')
pbxproj.append(f'\t\t{BUILD_CONFIG_LIST_TARGET_ID} /* Build configuration list for PBXNativeTarget */ = {{')
pbxproj.append('\t\t\tisa = XCConfigurationList;')
pbxproj.append('\t\t\tbuildConfigurations = (')
pbxproj.append(f'\t\t\t\t{BUILD_CONFIG_TARGET_DEBUG_ID} /* Debug */,')
pbxproj.append(f'\t\t\t\t{BUILD_CONFIG_TARGET_RELEASE_ID} /* Release */,')
pbxproj.append('\t\t\t);')
pbxproj.append('\t\t\tdefaultConfigurationIsVisible = 0;')
pbxproj.append('\t\t\tdefaultConfigurationName = Release;')
pbxproj.append('\t\t};')
pbxproj.append('/* End XCConfigurationList section */\n')

pbxproj.append('\t};')
pbxproj.append(f'\trootObject = {PROJECT_ID} /* Project object */;')
pbxproj.append('}')

PBXPROJ.write_text('\n'.join(pbxproj), encoding='utf-8')
print(f"生成: {PBXPROJ}")

# ---- 生成共享 scheme ----
SCHEME_DIR = PROJECT_DIR / "xcshareddata" / "xcschemes"
SCHEME_DIR.mkdir(parents=True, exist_ok=True)
SCHEME_FILE = SCHEME_DIR / "Masaiki.xcscheme"
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.3">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{TARGET_ID}"
               BuildableName = "Masaiki.app"
               BlueprintName = "Masaiki"
               ReferencedContainer = "container:Masaiki.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES"/>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{TARGET_ID}"
            BuildableName = "Masaiki.app"
            BlueprintName = "Masaiki"
            ReferencedContainer = "container:Masaiki.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{TARGET_ID}"
            BuildableName = "Masaiki.app"
            BlueprintName = "Masaiki"
            ReferencedContainer = "container:Masaiki.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"/>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
'''
SCHEME_FILE.write_text(scheme, encoding='utf-8')
print(f"生成: {SCHEME_FILE}")
