#!/usr/bin/env python3
"""Generates SiteVantage.xcodeproj/project.pbxproj by walking the SiteVantage/
and SiteVantageTests/ source trees. Written as a script (rather than
hand-authored) because a project this size has hundreds of interlocking
UUID references and a generator is far less error-prone than typing them by
hand -- especially since this environment has no Xcode to open/repair the
project in.

Classic (non-synchronized-group) PBXGroup/PBXFileReference/PBXBuildFile
structure, objectVersion 56 (Xcode 14/15 era format; modern Xcode versions
open and build older-format projects without issue).

Produces two targets:
  - SiteVantage (app)
  - SiteVantageTests (XCTest unit test bundle, hosted by the app target,
    depends on it, and is added to the shared scheme's TestAction)
"""

import hashlib
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_SOURCE_ROOT = os.path.join(REPO_ROOT, "SiteVantage")
TESTS_SOURCE_ROOT = os.path.join(REPO_ROOT, "SiteVantageTests")
PROJECT_DIR = os.path.join(REPO_ROOT, "SiteVantage.xcodeproj")

PRODUCT_NAME = "SiteVantage"
TESTS_PRODUCT_NAME = "SiteVantageTests"
BUNDLE_ID = "com.sitevantage.SiteVantage"
TESTS_BUNDLE_ID = "com.sitevantage.SiteVantageTests"
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
    """A directory node in a source tree, becoming a PBXGroup."""

    def __init__(self, name, rel_path):
        self.name = name
        self.rel_path = rel_path  # relative to that tree's source root
        self.children = {}  # name -> Node
        self.files = []  # filenames directly in this directory
        self.group_id = new_id(f"group:{name}:{rel_path}")


def build_tree(source_root, root_name):
    root = Node(root_name, "")
    for dirpath, dirnames, filenames in os.walk(source_root):
        dirnames.sort()
        rel_dir = os.path.relpath(dirpath, source_root)
        rel_dir = "" if rel_dir == "." else rel_dir

        # Assets.xcassets is represented as a single opaque file reference,
        # not walked into.
        if "Assets.xcassets" in rel_dir.split(os.sep):
            continue

        node = root
        if rel_dir:
            for part in rel_dir.split(os.sep):
                node = node.children.setdefault(
                    part, Node(part, os.path.join(node.rel_path, part) if node.rel_path else part)
                )

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


class SourceTreeResult:
    def __init__(self):
        self.file_refs = []  # (id, name, rel_path, file_type)
        self.build_files_sources = []  # (build_file_id, file_id, filename)
        self.build_files_resources = []


def collect(root):
    result = SourceTreeResult()

    def walk(node):
        for filename in node.files:
            rel = os.path.join(node.rel_path, filename) if node.rel_path else filename
            file_id = new_id(f"file:{root.name}:{rel}")
            ftype = file_type_for(filename)
            result.file_refs.append((file_id, filename, rel, ftype))
            if filename.endswith(".swift"):
                bf_id = new_id(f"buildfile:{root.name}:{rel}")
                result.build_files_sources.append((bf_id, file_id, filename))
            elif filename == "Assets.xcassets":
                bf_id = new_id(f"buildfile:{root.name}:{rel}")
                result.build_files_resources.append((bf_id, file_id, filename))
            # Info.plist: file reference only, no build phase membership.
        for child_name in sorted(node.children.keys()):
            walk(node.children[child_name])

    walk(root)
    return result


def main():
    app_root = build_tree(APP_SOURCE_ROOT, "SiteVantage")
    app = collect(app_root)

    tests_root = build_tree(TESTS_SOURCE_ROOT, "SiteVantageTests")
    tests = collect(tests_root)

    app_product_ref_id = new_id("product:SiteVantage.app")
    tests_product_ref_id = new_id("product:SiteVantageTests.xctest")
    project_id = new_id("project")
    app_target_id = new_id("target:SiteVantage")
    tests_target_id = new_id("target:SiteVantageTests")
    main_group_id = new_id("group:main")
    products_group_id = new_id("group:products")

    app_sources_phase_id = new_id("phase:app:sources")
    app_resources_phase_id = new_id("phase:app:resources")
    app_frameworks_phase_id = new_id("phase:app:frameworks")
    tests_sources_phase_id = new_id("phase:tests:sources")
    tests_resources_phase_id = new_id("phase:tests:resources")
    tests_frameworks_phase_id = new_id("phase:tests:frameworks")

    project_debug_config_id = new_id("config:project:debug")
    project_release_config_id = new_id("config:project:release")
    app_debug_config_id = new_id("config:app:debug")
    app_release_config_id = new_id("config:app:release")
    tests_debug_config_id = new_id("config:tests:debug")
    tests_release_config_id = new_id("config:tests:release")
    project_config_list_id = new_id("configlist:project")
    app_config_list_id = new_id("configlist:app")
    tests_config_list_id = new_id("configlist:tests")

    target_dependency_id = new_id("targetdependency:tests-on-app")
    container_proxy_id = new_id("containerproxy:tests-on-app")

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
    for bf_id, file_id, filename in app.build_files_sources:
        emit(f"\t\t{bf_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};")
    for bf_id, file_id, filename in app.build_files_resources:
        emit(f"\t\t{bf_id} /* {filename} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};")
    for bf_id, file_id, filename in tests.build_files_sources:
        emit(f"\t\t{bf_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};")
    for bf_id, file_id, filename in tests.build_files_resources:
        emit(f"\t\t{bf_id} /* {filename} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};")
    emit("/* End PBXBuildFile section */")
    emit()

    # PBXContainerItemProxy
    emit("/* Begin PBXContainerItemProxy section */")
    emit(f"\t\t{container_proxy_id} /* PBXContainerItemProxy */ = {{")
    emit("\t\t\tisa = PBXContainerItemProxy;")
    emit(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
    emit("\t\t\tproxyType = 1;")
    emit(f"\t\t\tremoteGlobalIDString = {app_target_id};")
    emit(f"\t\t\tremoteInfo = {PRODUCT_NAME};")
    emit("\t\t};")
    emit("/* End PBXContainerItemProxy section */")
    emit()

    # PBXFileReference
    emit("/* Begin PBXFileReference section */")
    emit(f"\t\t{app_product_ref_id} /* {PRODUCT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PRODUCT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    emit(f"\t\t{tests_product_ref_id} /* {TESTS_PRODUCT_NAME}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {TESTS_PRODUCT_NAME}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for file_id, filename, rel, ftype in app.file_refs:
        emit(f"\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {filename}; sourceTree = \"<group>\"; }};")
    for file_id, filename, rel, ftype in tests.file_refs:
        emit(f"\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {filename}; sourceTree = \"<group>\"; }};")
    emit("/* End PBXFileReference section */")
    emit()

    # PBXFrameworksBuildPhase
    emit("/* Begin PBXFrameworksBuildPhase section */")
    for phase_id, label in [(app_frameworks_phase_id, PRODUCT_NAME), (tests_frameworks_phase_id, TESTS_PRODUCT_NAME)]:
        emit(f"\t\t{phase_id} /* Frameworks */ = {{")
        emit("\t\t\tisa = PBXFrameworksBuildPhase;")
        emit("\t\t\tbuildActionMask = 2147483647;")
        emit("\t\t\tfiles = (")
        emit("\t\t\t);")
        emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        emit("\t\t};")
    emit("/* End PBXFrameworksBuildPhase section */")
    emit()

    # PBXGroup section
    emit("/* Begin PBXGroup section */")

    def emit_group(node, collected):
        emit(f"\t\t{node.group_id} = {{")
        emit("\t\t\tisa = PBXGroup;")
        emit("\t\t\tchildren = (")
        for filename in node.files:
            rel = os.path.join(node.rel_path, filename) if node.rel_path else filename
            match = next(f for f in collected.file_refs if f[2] == rel)
            emit(f"\t\t\t\t{match[0]} /* {filename} */,")
        for child_name in sorted(node.children.keys()):
            child = node.children[child_name]
            emit(f"\t\t\t\t{child.group_id} /* {child_name} */,")
        emit("\t\t\t);")
        # Every node's `path` matches its real folder name; nested paths
        # compose naturally since sourceTree is "<group>" (relative to the
        # parent group's resolved directory) all the way down.
        emit(f"\t\t\tpath = {node.name};")
        emit("\t\t\tsourceTree = \"<group>\";")
        emit("\t\t};")
        for child_name in sorted(node.children.keys()):
            emit_group(node.children[child_name], collected)

    emit_group(app_root, app)
    emit_group(tests_root, tests)

    # Products group
    emit(f"\t\t{products_group_id} /* Products */ = {{")
    emit("\t\t\tisa = PBXGroup;")
    emit("\t\t\tchildren = (")
    emit(f"\t\t\t\t{app_product_ref_id} /* {PRODUCT_NAME}.app */,")
    emit(f"\t\t\t\t{tests_product_ref_id} /* {TESTS_PRODUCT_NAME}.xctest */,")
    emit("\t\t\t);")
    emit("\t\t\tname = Products;")
    emit("\t\t\tsourceTree = \"<group>\";")
    emit("\t\t};")

    # Main group (top-level of the project navigator)
    emit(f"\t\t{main_group_id} = {{")
    emit("\t\t\tisa = PBXGroup;")
    emit("\t\t\tchildren = (")
    emit(f"\t\t\t\t{app_root.group_id} /* {PRODUCT_NAME} */,")
    emit(f"\t\t\t\t{tests_root.group_id} /* {TESTS_PRODUCT_NAME} */,")
    emit(f"\t\t\t\t{products_group_id} /* Products */,")
    emit("\t\t\t);")
    emit("\t\t\tsourceTree = \"<group>\";")
    emit("\t\t};")
    emit("/* End PBXGroup section */")
    emit()

    # PBXNativeTarget
    emit("/* Begin PBXNativeTarget section */")
    emit(f"\t\t{app_target_id} /* {PRODUCT_NAME} */ = {{")
    emit("\t\t\tisa = PBXNativeTarget;")
    emit(f"\t\t\tbuildConfigurationList = {app_config_list_id} /* Build configuration list for PBXNativeTarget \"{PRODUCT_NAME}\" */;")
    emit("\t\t\tbuildPhases = (")
    emit(f"\t\t\t\t{app_sources_phase_id} /* Sources */,")
    emit(f"\t\t\t\t{app_frameworks_phase_id} /* Frameworks */,")
    emit(f"\t\t\t\t{app_resources_phase_id} /* Resources */,")
    emit("\t\t\t);")
    emit("\t\t\tbuildRules = (")
    emit("\t\t\t);")
    emit("\t\t\tdependencies = (")
    emit("\t\t\t);")
    emit(f"\t\t\tname = {PRODUCT_NAME};")
    emit("\t\t\tproductName = " + PRODUCT_NAME + ";")
    emit(f"\t\t\tproductReference = {app_product_ref_id} /* {PRODUCT_NAME}.app */;")
    emit("\t\t\tproductType = \"com.apple.product-type.application\";")
    emit("\t\t};")

    emit(f"\t\t{tests_target_id} /* {TESTS_PRODUCT_NAME} */ = {{")
    emit("\t\t\tisa = PBXNativeTarget;")
    emit(f"\t\t\tbuildConfigurationList = {tests_config_list_id} /* Build configuration list for PBXNativeTarget \"{TESTS_PRODUCT_NAME}\" */;")
    emit("\t\t\tbuildPhases = (")
    emit(f"\t\t\t\t{tests_sources_phase_id} /* Sources */,")
    emit(f"\t\t\t\t{tests_frameworks_phase_id} /* Frameworks */,")
    emit(f"\t\t\t\t{tests_resources_phase_id} /* Resources */,")
    emit("\t\t\t);")
    emit("\t\t\tbuildRules = (")
    emit("\t\t\t);")
    emit("\t\t\tdependencies = (")
    emit(f"\t\t\t\t{target_dependency_id} /* PBXTargetDependency */,")
    emit("\t\t\t);")
    emit(f"\t\t\tname = {TESTS_PRODUCT_NAME};")
    emit("\t\t\tproductName = " + TESTS_PRODUCT_NAME + ";")
    emit(f"\t\t\tproductReference = {tests_product_ref_id} /* {TESTS_PRODUCT_NAME}.xctest */;")
    emit("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
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
    emit(f"\t\t\t\t\t{app_target_id} = {{")
    emit("\t\t\t\t\t\tCreatedOnToolsVersion = 15.1;")
    emit("\t\t\t\t\t};")
    emit(f"\t\t\t\t\t{tests_target_id} = {{")
    emit("\t\t\t\t\t\tCreatedOnToolsVersion = 15.1;")
    emit(f"\t\t\t\t\t\tTestTargetID = {app_target_id};")
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
    emit(f"\t\t\t\t{app_target_id} /* {PRODUCT_NAME} */,")
    emit(f"\t\t\t\t{tests_target_id} /* {TESTS_PRODUCT_NAME} */,")
    emit("\t\t\t);")
    emit("\t\t};")
    emit("/* End PBXProject section */")
    emit()

    # PBXResourcesBuildPhase
    emit("/* Begin PBXResourcesBuildPhase section */")
    emit(f"\t\t{app_resources_phase_id} /* Resources */ = {{")
    emit("\t\t\tisa = PBXResourcesBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    for bf_id, file_id, filename in app.build_files_resources:
        emit(f"\t\t\t\t{bf_id} /* {filename} in Resources */,")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
    emit(f"\t\t{tests_resources_phase_id} /* Resources */ = {{")
    emit("\t\t\tisa = PBXResourcesBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    for bf_id, file_id, filename in tests.build_files_resources:
        emit(f"\t\t\t\t{bf_id} /* {filename} in Resources */,")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
    emit("/* End PBXResourcesBuildPhase section */")
    emit()

    # PBXSourcesBuildPhase
    emit("/* Begin PBXSourcesBuildPhase section */")
    emit(f"\t\t{app_sources_phase_id} /* Sources */ = {{")
    emit("\t\t\tisa = PBXSourcesBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    for bf_id, file_id, filename in app.build_files_sources:
        emit(f"\t\t\t\t{bf_id} /* {filename} in Sources */,")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
    emit(f"\t\t{tests_sources_phase_id} /* Sources */ = {{")
    emit("\t\t\tisa = PBXSourcesBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    for bf_id, file_id, filename in tests.build_files_sources:
        emit(f"\t\t\t\t{bf_id} /* {filename} in Sources */,")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
    emit("/* End PBXSourcesBuildPhase section */")
    emit()

    # PBXTargetDependency
    emit("/* Begin PBXTargetDependency section */")
    emit(f"\t\t{target_dependency_id} /* PBXTargetDependency */ = {{")
    emit("\t\t\tisa = PBXTargetDependency;")
    emit(f"\t\t\ttarget = {app_target_id} /* {PRODUCT_NAME} */;")
    emit(f"\t\t\ttargetProxy = {container_proxy_id} /* PBXContainerItemProxy */;")
    emit("\t\t};")
    emit("/* End PBXTargetDependency section */")
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

    app_target_common = """
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

    tests_target_common = """
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = %(deployment_target)s;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@loader_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = %(bundle_id)s;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/%(app_product_name)s.app/%(app_product_name)s";
	""" % {
        "deployment_target": DEPLOYMENT_TARGET,
        "bundle_id": TESTS_BUNDLE_ID,
        "app_product_name": PRODUCT_NAME,
    }

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

    emit(f"\t\t{app_debug_config_id} /* Debug */ = {{")
    emit("\t\t\tisa = XCBuildConfiguration;")
    emit("\t\t\tbuildSettings = {")
    for line in app_target_common.strip("\n").split("\n"):
        emit(line)
    emit("\t\t\t};")
    emit("\t\t\tname = Debug;")
    emit("\t\t};")

    emit(f"\t\t{app_release_config_id} /* Release */ = {{")
    emit("\t\t\tisa = XCBuildConfiguration;")
    emit("\t\t\tbuildSettings = {")
    for line in app_target_common.strip("\n").split("\n"):
        emit(line)
    emit("\t\t\t};")
    emit("\t\t\tname = Release;")
    emit("\t\t};")

    emit(f"\t\t{tests_debug_config_id} /* Debug */ = {{")
    emit("\t\t\tisa = XCBuildConfiguration;")
    emit("\t\t\tbuildSettings = {")
    for line in tests_target_common.strip("\n").split("\n"):
        emit(line)
    emit("\t\t\t};")
    emit("\t\t\tname = Debug;")
    emit("\t\t};")

    emit(f"\t\t{tests_release_config_id} /* Release */ = {{")
    emit("\t\t\tisa = XCBuildConfiguration;")
    emit("\t\t\tbuildSettings = {")
    for line in tests_target_common.strip("\n").split("\n"):
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

    emit(f"\t\t{app_config_list_id} /* Build configuration list for PBXNativeTarget \"{PRODUCT_NAME}\" */ = {{")
    emit("\t\t\tisa = XCConfigurationList;")
    emit("\t\t\tbuildConfigurations = (")
    emit(f"\t\t\t\t{app_debug_config_id} /* Debug */,")
    emit(f"\t\t\t\t{app_release_config_id} /* Release */,")
    emit("\t\t\t);")
    emit("\t\t\tdefaultConfigurationIsVisible = 0;")
    emit("\t\t\tdefaultConfigurationName = Release;")
    emit("\t\t};")

    emit(f"\t\t{tests_config_list_id} /* Build configuration list for PBXNativeTarget \"{TESTS_PRODUCT_NAME}\" */ = {{")
    emit("\t\t\tisa = XCConfigurationList;")
    emit("\t\t\tbuildConfigurations = (")
    emit(f"\t\t\t\t{tests_debug_config_id} /* Debug */,")
    emit(f"\t\t\t\t{tests_release_config_id} /* Release */,")
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
    print(f"  App Swift files: {len(app.build_files_sources)}")
    print(f"  App resource files: {len(app.build_files_resources)}")
    print(f"  Test Swift files: {len(tests.build_files_sources)}")

    write_scheme(app_target_id, tests_target_id)


def write_scheme(app_target_id, tests_target_id):
    scheme_dir = os.path.join(PROJECT_DIR, "xcshareddata", "xcschemes")
    os.makedirs(scheme_dir, exist_ok=True)
    scheme_path = os.path.join(scheme_dir, f"{PRODUCT_NAME}.xcscheme")

    app_buildable_reference = f'''
      <BuildableReference
         BuildableIdentifier = "primary"
         BlueprintIdentifier = "{app_target_id}"
         BuildableName = "{PRODUCT_NAME}.app"
         BlueprintName = "{PRODUCT_NAME}"
         ReferencedContainer = "container:{PRODUCT_NAME}.xcodeproj">
      </BuildableReference>'''.rstrip("\n")

    tests_buildable_reference = f'''
      <BuildableReference
         BuildableIdentifier = "primary"
         BlueprintIdentifier = "{tests_target_id}"
         BuildableName = "{TESTS_PRODUCT_NAME}.xctest"
         BlueprintName = "{TESTS_PRODUCT_NAME}"
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
            buildForAnalyzing = "YES">{app_buildable_reference}
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "NO"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "YES">{tests_buildable_reference}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">{tests_buildable_reference}
         </TestableReference>
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
         runnableDebuggingMode = "0">{app_buildable_reference}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">{app_buildable_reference}
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
