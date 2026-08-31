#!/usr/bin/env python3
"""Generates SiteVantage.xcodeproj/project.pbxproj by walking the SiteVantage/
source tree. Written as a script (rather than hand-authored) because a
~40-file Xcode project has hundreds of interlocking UUID references and a
generator is far less error-prone than typing them by hand -- especially
since this environment has no Xcode to open/repair the project in.

Classic (non-synchronized-group) PBXGroup/PBXFileReference/PBXBuildFile
structure, objectVersion 56 (Xcode 14/15 era format; modern Xcode versions
open and build older-format projects without issue).
"""

import hashlib
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_ROOT = os.path.join(REPO_ROOT, "SiteVantage")
PROJECT_DIR = os.path.join(REPO_ROOT, "SiteVantage.xcodeproj")

PRODUCT_NAME = "SiteVantage"
BUNDLE_ID = "com.sitevantage.SiteVantage"
DEPLOYMENT_TARGET = "17.0"

_counter = [0]
_seen = set()


def new_id(seed):
    """Deterministic, unique 24-hex-char pbxproj object ID."""
    _counter[0] += 1
    base = f"{seed}-{_counter[0]}".encode("utf-8")
    digest = hashlib.sha1(base).hexdigest().upper()[:24]
    while digest in _seen:
        _counter[0] += 1
        base = f"{seed}-{_counter[0]}".encode("utf-8")
        digest = hashlib.sha1(base).hexdigest().upper()[:24]
    _seen.add(digest)
    return digest


class Node:
    """A directory node in the source tree, becoming a PBXGroup."""

    def __init__(self, name, rel_path):
        self.name = name
        self.rel_path = rel_path  # relative to SOURCE_ROOT
        self.children = {}  # name -> Node
        self.files = []  # (name, rel_path_from_source_root)
        self.group_id = new_id(f"group:{rel_path}")


def build_tree():
    root = Node("SiteVantage", "")
    for dirpath, dirnames, filenames in os.walk(SOURCE_ROOT):
        dirnames.sort()
        rel_dir = os.path.relpath(dirpath, SOURCE_ROOT)
        rel_dir = "" if rel_dir == "." else rel_dir

        # Assets.xcassets is represented as a single opaque file reference,
        # not walked into.
        if "Assets.xcassets" in rel_dir.split(os.sep):
            continue

        node = root
        if rel_dir:
            for part in rel_dir.split(os.sep):
                node = node.children.setdefault(part, Node(part, os.path.join(node.rel_path, part) if node.rel_path else part))

        for filename in sorted(filenames):
            if filename.startswith("."):
                continue
            node.files.append(filename)

        if "Assets.xcassets" in dirnames:
            node.files.append("Assets.xcassets")
            dirnames.remove("Assets.xcassets")

    return root


FILE_TYPE_BY_EXT = {
    ".swift": "sourcecode.swift",
    ".plist": "text.plist.xml",
}


def file_type_for(name):
    if name == "Assets.xcassets":
        return "folder.assetcatalog"
    _, ext = os.path.splitext(name)
    return FILE_TYPE_BY_EXT.get(ext, "text")


def main():
    root = build_tree()

    file_refs = []  # (id, name, path_from_source_root, file_type)
    build_files_sources = []  # (build_file_id, file_ref_id, comment)
    build_files_resources = []

    def walk(node):
        for filename in node.files:
            rel = os.path.join(node.rel_path, filename) if node.rel_path else filename
            file_id = new_id(f"file:{rel}")
            ftype = file_type_for(filename)
            file_refs.append((file_id, filename, rel, ftype))
            if filename.endswith(".swift"):
                bf_id = new_id(f"buildfile:{rel}")
                build_files_sources.append((bf_id, file_id, filename))
            elif filename == "Assets.xcassets":
                bf_id = new_id(f"buildfile:{rel}")
                build_files_resources.append((bf_id, file_id, filename))
            # Info.plist: file reference only, no build phase membership.
        for child_name in sorted(node.children.keys()):
            walk(node.children[child_name])

    walk(root)

    product_ref_id = new_id("product:SiteVantage.app")
    project_id = new_id("project")
    target_id = new_id("target:SiteVantage")
    main_group_id = new_id("group:main")
    products_group_id = new_id("group:products")

    sources_phase_id = new_id("phase:sources")
    resources_phase_id = new_id("phase:resources")
    frameworks_phase_id = new_id("phase:frameworks")

    project_debug_config_id = new_id("config:project:debug")
    project_release_config_id = new_id("config:project:release")
    target_debug_config_id = new_id("config:target:debug")
    target_release_config_id = new_id("config:target:release")
    project_config_list_id = new_id("configlist:project")
    target_config_list_id = new_id("configlist:target")

    lines = []

    def emit(s=""):
        lines.append(s)

    emit("// !$*UTF8*$!")
    emit("{")
    emit("\tarchiveVersion = 1;")
    emit("\tclasses = {")
    emit("\t};")
    emit("\tobjectVersion = 56;")
    emit("\tobjects = {")
    emit()

    # PBXBuildFile
    emit("/* Begin PBXBuildFile section */")
    for bf_id, file_id, filename in build_files_sources:
        emit(f"\t\t{bf_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};")
    for bf_id, file_id, filename in build_files_resources:
        emit(f"\t\t{bf_id} /* {filename} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};")
    emit("/* End PBXBuildFile section */")
    emit()

    # PBXFileReference
    emit("/* Begin PBXFileReference section */")
    emit(f"\t\t{product_ref_id} /* {PRODUCT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PRODUCT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for file_id, filename, rel, ftype in file_refs:
        emit(f"\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {filename}; sourceTree = \"<group>\"; }};")
    emit("/* End PBXFileReference section */")
    emit()

    # PBXFrameworksBuildPhase
    emit("/* Begin PBXFrameworksBuildPhase section */")
    emit(f"\t\t{frameworks_phase_id} /* Frameworks */ = {{")
    emit("\t\t\tisa = PBXFrameworksBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
    emit("/* End PBXFrameworksBuildPhase section */")
    emit()

    # PBXGroup section: build recursively
    emit("/* Begin PBXGroup section */")

    def emit_group(node, group_id):
        emit(f"\t\t{group_id} = {{")
        emit("\t\t\tisa = PBXGroup;")
        emit("\t\t\tchildren = (")
        for filename in node.files:
            rel = os.path.join(node.rel_path, filename) if node.rel_path else filename
            match = next(f for f in file_refs if f[2] == rel)
            emit(f"\t\t\t\t{match[0]} /* {filename} */,")
        for child_name in sorted(node.children.keys()):
            child = node.children[child_name]
            emit(f"\t\t\t\t{child.group_id} /* {child_name} */,")
        emit("\t\t\t);")
        # Every node's `path` matches its real folder name; nested paths
        # compose naturally since sourceTree is "<group>" (relative to the
        # parent group's resolved directory) all the way down. The root
        # "SiteVantage" node's path is the real SiteVantage/ folder at the
        # repo root, alongside SiteVantage.xcodeproj.
        emit(f"\t\t\tpath = {node.name};")
        emit("\t\t\tsourceTree = \"<group>\";")
        emit("\t\t};")
        for child_name in sorted(node.children.keys()):
            emit_group(node.children[child_name], node.children[child_name].group_id)

    # Root "SiteVantage" group (mirrors the SiteVantage/ folder on disk).
    emit_group(root, root.group_id)

    # Products group
    emit(f"\t\t{products_group_id} /* Products */ = {{")
    emit("\t\t\tisa = PBXGroup;")
    emit("\t\t\tchildren = (")
    emit(f"\t\t\t\t{product_ref_id} /* {PRODUCT_NAME}.app */,")
    emit("\t\t\t);")
    emit("\t\t\tname = Products;")
    emit("\t\t\tsourceTree = \"<group>\";")
    emit("\t\t};")

    # Main group (top-level of the project navigator)
    emit(f"\t\t{main_group_id} = {{")
    emit("\t\t\tisa = PBXGroup;")
    emit("\t\t\tchildren = (")
    emit(f"\t\t\t\t{root.group_id} /* {PRODUCT_NAME} */,")
    emit(f"\t\t\t\t{products_group_id} /* Products */,")
    emit("\t\t\t);")
    emit("\t\t\tsourceTree = \"<group>\";")
    emit("\t\t};")
    emit("/* End PBXGroup section */")
    emit()

    # PBXNativeTarget
    emit("/* Begin PBXNativeTarget section */")
    emit(f"\t\t{target_id} /* {PRODUCT_NAME} */ = {{")
    emit("\t\t\tisa = PBXNativeTarget;")
    emit(f"\t\t\tbuildConfigurationList = {target_config_list_id} /* Build configuration list for PBXNativeTarget \"{PRODUCT_NAME}\" */;")
    emit("\t\t\tbuildPhases = (")
    emit(f"\t\t\t\t{sources_phase_id} /* Sources */,")
    emit(f"\t\t\t\t{frameworks_phase_id} /* Frameworks */,")
    emit(f"\t\t\t\t{resources_phase_id} /* Resources */,")
    emit("\t\t\t);")
    emit("\t\t\tbuildRules = (")
    emit("\t\t\t);")
    emit("\t\t\tdependencies = (")
    emit("\t\t\t);")
    emit(f"\t\t\tname = {PRODUCT_NAME};")
    emit("\t\t\tproductName = " + PRODUCT_NAME + ";")
    emit(f"\t\t\tproductReference = {product_ref_id} /* {PRODUCT_NAME}.app */;")
    emit("\t\t\tproductType = \"com.apple.product-type.application\";")
    emit("\t\t};")
    emit("/* End PBXNativeTarget section */")
    emit()

    # PBXProject
    emit("/* Begin PBXProject section */")
    emit(f"\t\t{project_id} /* Project object */ = {{")
    emit("\t\t\tisa = PBXProject;")
    emit("\t\t\tattributes = {")
    emit("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    emit("\t\t\t\tLastSwiftUpdateCheck = 1510;")
    emit("\t\t\t\tLastUpgradeCheck = 1510;")
    emit("\t\t\t\tTargetAttributes = {")
    emit(f"\t\t\t\t\t{target_id} = {{")
    emit("\t\t\t\t\t\tCreatedOnToolsVersion = 15.1;")
    emit("\t\t\t\t\t};")
    emit("\t\t\t\t};")
    emit("\t\t\t};")
    emit(f"\t\t\tbuildConfigurationList = {project_config_list_id} /* Build configuration list for PBXProject \"{PRODUCT_NAME}\" */;")
    emit("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    emit("\t\t\tdevelopmentRegion = en;")
    emit("\t\t\thasScannedForEncodings = 0;")
    emit("\t\t\tknownRegions = (")
    emit("\t\t\t\ten,")
    emit("\t\t\t\tBase,")
    emit("\t\t\t);")
    emit(f"\t\t\tmainGroup = {main_group_id};")
    emit(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    emit("\t\t\tprojectDirPath = \"\";")
    emit("\t\t\tprojectRoot = \"\";")
    emit("\t\t\ttargets = (")
    emit(f"\t\t\t\t{target_id} /* {PRODUCT_NAME} */,")
    emit("\t\t\t);")
    emit("\t\t};")
    emit("/* End PBXProject section */")
    emit()

    # PBXResourcesBuildPhase
    emit("/* Begin PBXResourcesBuildPhase section */")
    emit(f"\t\t{resources_phase_id} /* Resources */ = {{")
    emit("\t\t\tisa = PBXResourcesBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    for bf_id, file_id, filename in build_files_resources:
        emit(f"\t\t\t\t{bf_id} /* {filename} in Resources */,")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
    emit("/* End PBXResourcesBuildPhase section */")
    emit()

    # PBXSourcesBuildPhase
    emit("/* Begin PBXSourcesBuildPhase section */")
    emit(f"\t\t{sources_phase_id} /* Sources */ = {{")
    emit("\t\t\tisa = PBXSourcesBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    for bf_id, file_id, filename in build_files_sources:
        emit(f"\t\t\t\t{bf_id} /* {filename} in Sources */,")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
    emit("/* End PBXSourcesBuildPhase section */")
    emit()

    # XCBuildConfiguration
    common_debug = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = %(deployment_target)s;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
	""" % {"deployment_target": DEPLOYMENT_TARGET}

    common_release = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = %(deployment_target)s;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
	""" % {"deployment_target": DEPLOYMENT_TARGET}

    target_common = """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = SiteVantage/Resources/Info.plist;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				IPHONEOS_DEPLOYMENT_TARGET = %(deployment_target)s;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = %(bundle_id)s;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
	""" % {"deployment_target": DEPLOYMENT_TARGET, "bundle_id": BUNDLE_ID}

    emit("/* Begin XCBuildConfiguration section */")

    emit(f"\t\t{project_debug_config_id} /* Debug */ = {{")
    emit("\t\t\tisa = XCBuildConfiguration;")
    emit("\t\t\tbuildSettings = {")
    for line in common_debug.strip("\n").split("\n"):
        emit(line)
    emit("\t\t\t};")
    emit("\t\t\tname = Debug;")
    emit("\t\t};")

    emit(f"\t\t{project_release_config_id} /* Release */ = {{")
    emit("\t\t\tisa = XCBuildConfiguration;")
    emit("\t\t\tbuildSettings = {")
    for line in common_release.strip("\n").split("\n"):
        emit(line)
    emit("\t\t\t};")
    emit("\t\t\tname = Release;")
    emit("\t\t};")

    emit(f"\t\t{target_debug_config_id} /* Debug */ = {{")
    emit("\t\t\tisa = XCBuildConfiguration;")
    emit("\t\t\tbuildSettings = {")
    for line in target_common.strip("\n").split("\n"):
        emit(line)
    emit("\t\t\t};")
    emit("\t\t\tname = Debug;")
    emit("\t\t};")

    emit(f"\t\t{target_release_config_id} /* Release */ = {{")
    emit("\t\t\tisa = XCBuildConfiguration;")
    emit("\t\t\tbuildSettings = {")
    for line in target_common.strip("\n").split("\n"):
        emit(line)
    emit("\t\t\t};")
    emit("\t\t\tname = Release;")
    emit("\t\t};")

    emit("/* End XCBuildConfiguration section */")
    emit()

    # XCConfigurationList
    emit("/* Begin XCConfigurationList section */")
    emit(f"\t\t{project_config_list_id} /* Build configuration list for PBXProject \"{PRODUCT_NAME}\" */ = {{")
    emit("\t\t\tisa = XCConfigurationList;")
    emit("\t\t\tbuildConfigurations = (")
    emit(f"\t\t\t\t{project_debug_config_id} /* Debug */,")
    emit(f"\t\t\t\t{project_release_config_id} /* Release */,")
    emit("\t\t\t);")
    emit("\t\t\tdefaultConfigurationIsVisible = 0;")
    emit("\t\t\tdefaultConfigurationName = Release;")
    emit("\t\t};")

    emit(f"\t\t{target_config_list_id} /* Build configuration list for PBXNativeTarget \"{PRODUCT_NAME}\" */ = {{")
    emit("\t\t\tisa = XCConfigurationList;")
    emit("\t\t\tbuildConfigurations = (")
    emit(f"\t\t\t\t{target_debug_config_id} /* Debug */,")
    emit(f"\t\t\t\t{target_release_config_id} /* Release */,")
    emit("\t\t\t);")
    emit("\t\t\tdefaultConfigurationIsVisible = 0;")
    emit("\t\t\tdefaultConfigurationName = Release;")
    emit("\t\t};")
    emit("/* End XCConfigurationList section */")
    emit()

    emit("\t};")
    emit(f"\trootObject = {project_id} /* Project object */;")
    emit("}")
    emit("")

    output = "\n".join(lines)

    os.makedirs(PROJECT_DIR, exist_ok=True)
    out_path = os.path.join(PROJECT_DIR, "project.pbxproj")
    with open(out_path, "w") as f:
        f.write(output)

    print(f"Wrote {out_path}")
    print(f"  Swift files: {len(build_files_sources)}")
    print(f"  Resource files: {len(build_files_resources)}")
    print(f"  Total file refs: {len(file_refs)}")

    write_scheme(target_id)

    return {
        "target_id": target_id,
        "scheme_name": PRODUCT_NAME,
    }


def write_scheme(target_id):
    scheme_dir = os.path.join(PROJECT_DIR, "xcshareddata", "xcschemes")
    os.makedirs(scheme_dir, exist_ok=True)
    scheme_path = os.path.join(scheme_dir, f"{PRODUCT_NAME}.xcscheme")

    buildable_reference = f'''
      <BuildableReference
         BuildableIdentifier = "primary"
         BlueprintIdentifier = "{target_id}"
         BuildableName = "{PRODUCT_NAME}.app"
         BlueprintName = "{PRODUCT_NAME}"
         ReferencedContainer = "container:{PRODUCT_NAME}.xcodeproj">
      </BuildableReference>'''.rstrip("\n")

    content = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1510"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">{buildable_reference}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">{buildable_reference}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">{buildable_reference}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
    with open(scheme_path, "w") as f:
        f.write(content)
    print(f"Wrote {scheme_path}")


if __name__ == "__main__":
    main()
