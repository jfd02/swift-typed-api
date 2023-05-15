# CreateAPI 0.x

## 0.2.0

### May 54, 2023

- [#160](https://github.com/CreateAPI/CreateAPI/pull/160) Update Get dependency to require 2.1.x or later by @mgrider
- [#172](https://github.com/CreateAPI/CreateAPI/pull/172) Support multipart/form-data as opt-in feature by @ainame
- [#181](https://github.com/CreateAPI/CreateAPI/pull/181) Fix bug where object schemas representing an `allOf` type with more than one schema but only one property were inferred as the wrong type by @liamnichols

**Full Changelog**: https://github.com/CreateAPI/CreateAPI/compare/0.1.1...0.2.0

## 0.1.1

### October 5, 2022

- [#148](https://github.com/CreateAPI/CreateAPI/pull/148) List `jellyfin-sdk-swift` as a project using CreateAPI by @LePips
- [#156](https://github.com/CreateAPI/CreateAPI/pull/156) Add Xcode 14 and Swift 5.7 to CI by @liamnichols
- [#158](https://github.com/CreateAPI/CreateAPI/pull/158) Fix issue with Discriminator type resolution that impacted the decoding of `oneOf` types in some conditions by @liamnichols
- [#159](https://github.com/CreateAPI/CreateAPI/pull/159) Improve error messages that are used when `oneOf` object decoding fails by @liamnichols

**Full Changelog**: https://github.com/CreateAPI/CreateAPI/compare/0.1.0...0.1.1

## 0.1.0

### August 16, 2022

### Enhancements

- [#69](https://github.com/CreateAPI/CreateAPI/issues/69) - Publish release to Homebrew.
- [#48](https://github.com/CreateAPI/CreateAPI/issues/48) - Support Swift Package Plugins.
- [#58](https://github.com/CreateAPI/CreateAPI/issues/58) - Improve readme, add usage documentation and contributing guides.
- [#47](https://github.com/CreateAPI/CreateAPI/issues/47) - Override any option in the configuration file from the command line using `--config-option`.
- [#85](https://github.com/CreateAPI/CreateAPI/issues/85) - Add custom package dependencies in generated package.
- [#114](https://github.com/CreateAPI/CreateAPI/issues/114) - Allow custom mapping between schema data types/formats and Swift types used in generation.
- [#125](https://github.com/CreateAPI/CreateAPI/pull/125) - Raise an error if the `--config` file doesn't exist instead of silently falling back to the default options.
- [#90](https://github.com/CreateAPI/CreateAPI/pull/90) - Produce warnings when configuration files contain unknown or deprecated options.
- [#76](https://github.com/CreateAPI/CreateAPI/pull/76) - Add `--version` option/command.
- [#71](https://github.com/CreateAPI/CreateAPI/issues/71) - Support excluding individual properties on entities.
- [#116](https://github.com/CreateAPI/CreateAPI/pull/116), [#141](https://github.com/CreateAPI/CreateAPI/pull/141) - Write extension source files into **Extensions** directory and improve their filenames.
- [#131](https://github.com/CreateAPI/CreateAPI/pull/131) - Raise an error if you use `--clean` when the `--output` directory also contains the schema or config file.
- [#138](https://github.com/CreateAPI/CreateAPI/pull/138) - Trim whitespace from the `fileHeaderComment`.
- [#140](https://github.com/CreateAPI/CreateAPI/pull/140) - Run path generation in parallel.

### Breaking Changes

- [#83](https://github.com/CreateAPI/CreateAPI/pull/83) - Generated packages and paths now depend on Get 1.0.2 or later. If you don't use Get, your `Request` type must expose an initializer that matches the [initializer defined in Get](https://github.com/kean/Get/blob/db5248ce985c703c5ea0030b7c4d3f908db304c9/Sources/Get/Request.swift#L27-L41).
- [#88](https://github.com/CreateAPI/CreateAPI/issues/88) - When generating a Swift Package, the **Package.swift** file and all other sources are written to the root of the `--output` directory instead of being nested inside a subdirectory.
- [#132](https://github.com/CreateAPI/CreateAPI/pull/132) Default output directory is now **./CreateAPI** when `--output` is not specified.
- [#112](https://github.com/CreateAPI/CreateAPI/issues/112) - The `rename.properties` option now understands property names as defined in the original schema and not after applying CreateAPI transformations (such as case conversion or swifty style booleans).
- [#125](https://github.com/CreateAPI/CreateAPI/pull/125) - The generator will now error if the path defined using `--config` did not contain a valid file (prior behaviour was to fallback to the default configuration).
- [#47](https://github.com/CreateAPI/CreateAPI/issues/47) - Command Line Argument options that alter the generate output have now been moved into the configuration file and the behaviour may have also been adjusted.
  - `--split` (`-s`) is now the default behavior. Use the `mergeSources` option to merge generated source files.
  - `--filename-template` has been replaced by the `entities.filenameTemplate` and `paths.filenameTemplate` options.
  - `--entityname-template` has been replaced by the `entities.nameTemplate` option.
  - `--generate` has been replaced by the `generate` option and now accepts `paths`, `entities`, `enums` and `package` to customize which components are generated.
  - `--package` and `--module` have been incorporated as part of the `generate` option (see above) for controlling the generated outputs and the module/package name is configured using the `module` option.
  - `--vendor` has been replaced by the `vendor` option.
- [#100](https://github.com/CreateAPI/CreateAPI/issues/100) - For `entities`, `isGeneratingStructs` and `isMakingClassesFinal` have merged into a single `defaultType` option (accepted values `struct`, `class` or `finalClass`).
  - `isGeneratingMutableClassProperties` and `isGeneratingMutableStructProperties` have been replaced by a single `mutableProperties` option. Specify `true`, `false`, `structs` or `classes` instead.
  - `entitiesGeneratedAsClasses` and `entitiesGeneratedAsStructs` have been replaced by a single `typeOverrides` option.
- [#98](https://github.com/CreateAPI/CreateAPI/issues/98) - `comments` options have been replaced with a single `commentOptions` property that accepts `false`, `true` or an array containing any of `[title, description, example, externalDocumentation, capitalized]`.
- [#97](https://github.com/CreateAPI/CreateAPI/issues/97) - `isReplacingCommonAcronyms`, `addedAcronyms` and `ignoredAcronyms` have been replaced with a single `acronyms` option.
- [#94](https://github.com/CreateAPI/CreateAPI/issues/94) - `isSwiftLintDisabled` has been removed. Use `fileHeaderComment` if you want to replicate this behavior.
- [#93](https://github.com/CreateAPI/CreateAPI/issues/93) - `isAdditionalPropertiesOnByDefault` has been removed with no replacement.
- [#92](https://github.com/CreateAPI/CreateAPI/issues/92) - Every generated `Request` now includes its `operationId` and the `isAddingOperationIds` option has now been removed.
- [#91](https://github.com/CreateAPI/CreateAPI/pull/91) - Fixed a spelling mistake in `overridenResponses` and `overridenBodyTypes`.
- [#63](https://github.com/CreateAPI/CreateAPI/issues/63) - `isInliningPropertiesFromReferencedSchemas` behavior is now enabled by default and the option has renamed to `inlineReferencedSchemas`.
- [#75](https://github.com/CreateAPI/CreateAPI/issues/75) - `isGeneratingCustomCodingKeys` behavior is now enabled by default and the option has been renamed to `optimizeCodingKeys`.
- [#66](https://github.com/CreateAPI/CreateAPI/issues/66) - `access` no longer accepts an open string. The value must be either `internal` or `public`.
- [#114](https://github.com/CreateAPI/CreateAPI/issues/114), [#145](https://github.com/CreateAPI/CreateAPI/pull/145) - `isUsingIntegersWithPredefinedCapacity` has been removed. You can now configure data type mappings to Swift types using the `dataTypes` option.
- [#134](https://github.com/CreateAPI/CreateAPI/pull/134) - `isGeneratingEnums` has been removed and is now configurable as part of the new `generate` option.
- [#89](https://github.com/CreateAPI/CreateAPI/issues/89) - Swifty style boolean properties in the configuration file have been renamed.
  - `isNaiveDateEnabled` **▸** `useNaiveDate`
  - `isPluralizationEnabled` **▸** `pluralizeProperties`
  - `isInliningTypealiases` **▸** `inlineTypealiases`
  - `isGeneratingSwiftyBooleanPropertyNames` **▸** `useSwiftyPropertyNames`
  - `isAddingDeprecations` **▸** `annotateDeprecations`
  - `entities`
    - `isStrippingParentNameInNestedObjects` **▸** `stripParentNameInNestedObjects`
    - `isAddingDefaultValues` **▸** `includeDefaultValues`
    - `isSortingPropertiesAlphabetically` **▸** `sortPropertiesAlphabetically`
    - `isGeneratingEncodeWithEncoder` **▸** `alwaysIncludeEncodableImplementation`
    - `isGeneratingInitWithDecoder` **▸** `alwaysIncludeDecodableImplementation`
    - `isGeneratingInitializers` **▸** `includeInitializer`
    - `isSkippingRedundantProtocols` **▸** `skipRedundantProtocols`
    - `isGeneratingIdentifiableConformance` **▸** `includeIdentifiableConformance`
  - `paths`
    - `isRemovingRedundantPaths` **▸** `removeRedundantPaths`
    - `isMakingOptionalPatchParametersDoubleOptional` **▸** `makeOptionalPatchParametersDoubleOptional`
    - `isInliningSimpleQueryParameters` **▸** `inlineSimpleQueryParameters`
    - `isInliningSimpleRequests` **▸** `inlineSimpleRequests`
    - `isGeneratingResponseHeaders` **▸** `includeResponseHeaders`
    - `isGeneratingCustomCodingKeys` **▸** `optimizeCodingKeys`
    - `isInliningPropertiesFromReferencedSchemas` **▸** `inlineReferencedSchemas`

Refer to the [Configuration Options](https://github.com/CreateAPI/CreateAPI/blob/main/Docs/ConfigOptions.md) documentation for more information.

### Internal

- [#79](https://github.com/CreateAPI/CreateAPI/pull/79) - Lint project using SwiftLint.
- [#81](https://github.com/CreateAPI/CreateAPI/pull/81) - Compile generated test snapshots on Linux as part of CI checks.
- [#117](https://github.com/CreateAPI/CreateAPI/pull/117) - Refactor file writing responsibility out of the `Generate` command.
- [#122](https://github.com/CreateAPI/CreateAPI/pull/122) - Cleanup tests with new `snapshot(spec:name:testCompilationOnLinux:arguments:configuration:)` method.
- [#120](https://github.com/CreateAPI/CreateAPI/pull/120) - Use [swift-configuration-parser](https://github.com/liamnichols/swift-configuration-parser) library.
- [#128](https://github.com/CreateAPI/CreateAPI/pull/128) - Refactor CreateAPITests structure and rewrite snapshotter.
- [#123](https://github.com/CreateAPI/CreateAPI/pull/123) - Automatically update AllPackages package when rerecording snapshots.
- [#129](https://github.com/CreateAPI/CreateAPI/pull/129) - Introduce 'Record Snapshots' scheme to simplify rerecording snapshots.

**Full Changelog**: https://github.com/CreateAPI/CreateAPI/compare/0.0.5...0.1.0

## 0.0.5

### July 30, 2022

* Support Linux by @liamnichols in [#43](https://github.com/CreateAPI/CreateAPI/pull/43)
* Update Makefile by @liamnichols in [#54](https://github.com/CreateAPI/CreateAPI/pull/54)
* Update generator code to point to https://github.com/kean/Get and not CreateAPI/Get by @liamnichols in [#51](https://github.com/CreateAPI/CreateAPI/pull/51)
* Remove main.swift and mark CreateAPI as @main type directly by @liamnichols in [#49](https://github.com/CreateAPI/CreateAPI/pull/49)
* Fix comment generation when using other kind of linebreaks by @liamnichols in [#46](https://github.com/CreateAPI/CreateAPI/pull/46)
* Support automatically generating `Identifiable` conformance on entities by @LePips in [#61](https://github.com/CreateAPI/CreateAPI/pull/61)
* Tests - Automatic Path Finding and Remove Environment Variables by @LePips in [#62](https://github.com/CreateAPI/CreateAPI/pull/62)
* Single source of truth for configuration options by @liamnichols in [#51](https://github.com/CreateAPI/CreateAPI/pull/52)
* Update README and use new CreateOptions module by @liamnichols in [#65](https://github.com/CreateAPI/CreateAPI/pull/65)
* Produce an artifactbundle when making releases  by @liamnichols in [#67](https://github.com/CreateAPI/CreateAPI/pull/67)

**Full Changelog**: https://github.com/CreateAPI/CreateAPI/compare/0.0.4...0.0.5

## 0.0.4

### June 10, 2022

* Discriminator Support by @PhilipTrauner in [#10](https://github.com/CreateAPI/CreateAPI/pull/10)
* Strip parent name of enum cases within nested objects by @PhilipTrauner in [#15](https://github.com/CreateAPI/CreateAPI/pull/15)
* Added options for mutable properties in classes and structs by @JanC in [#17](https://github.com/CreateAPI/CreateAPI/pull/17)
* Add entities name template by @imjn in [#14](https://github.com/CreateAPI/CreateAPI/pull/14)
* Added imports option for entities by @JanC in [#19](https://github.com/CreateAPI/CreateAPI/pull/19)
* Fix shouldGenerate check for entities.include option by @ainame in [#10](https://github.com/CreateAPI/CreateAPI/pull/20)
* Fix namespace when using operations style by @simorgh3196 in [#21](https://github.com/CreateAPI/CreateAPI/pull/21)
* Fix `String` type with `byte` format by @mattia in [#25](https://github.com/CreateAPI/CreateAPI/pull/25)
* Fixed fileHeader option to fileHeaderComment by @imjn in [#22](https://github.com/CreateAPI/CreateAPI/pull/22)
* Fixed test failures for string with byte format by @imjn in [#26](https://github.com/CreateAPI/CreateAPI/pull/26)
* Fix test failures in comparing Package.swift by @imjn in [#28](https://github.com/CreateAPI/CreateAPI/pull/28)
* Update repository links to github.com/CreateAPI/CreateAPI by @liamnichols in [#35](https://github.com/CreateAPI/CreateAPI/pull/35)
* Support multiple discriminator mappings to share one type by @imjn in [#36](https://github.com/CreateAPI/CreateAPI/pull/36)
* Update GitHub Workflow CI by @liamnichols in [#37](https://github.com/CreateAPI/CreateAPI/pull/37)
* Fix allOf decoding issue by @imjn in [#27](https://github.com/CreateAPI/CreateAPI/pull/27)
* Removed redundant space before struct and class declaration by @imjn in [#38](https://github.com/CreateAPI/CreateAPI/pull/38)
* Decode JSON input specs using `YAMLDecoder` by @liamnichols in [#34](https://github.com/CreateAPI/CreateAPI/pull/34)
* Treat single element allOf/oneOf/anyOf schemas as the nested schema by @liamnichols in [#39](https://github.com/CreateAPI/CreateAPI/pull/39)

**Full Changelog**: https://github.com/CreateAPI/CreateAPI/compare/0.0.2...0.0.4

## 0.0.2

### Jan 29, 2022

* Add support for installation by Mint by @simorgh3196 in [#1](https://github.com/CreateAPI/CreateAPI/pull/1)
* Fixed small typos in README.md by @imjn in [#2](https://github.com/CreateAPI/CreateAPI/pull/2)
* Fixed wrong example in readme yaml by @imjn in [#4](https://github.com/CreateAPI/CreateAPI/pull/4)
* Add Entities.include by @imjn in [#5](https://github.com/CreateAPI/CreateAPI/pull/5)
* Revert "Added entityPrefix and entitySuffix to GenerateOptions.Rename" by @imjn in [#8](https://github.com/CreateAPI/CreateAPI/pull/8)
* Added --clean to readme by @imjn in [#7](https://github.com/CreateAPI/CreateAPI/pull/7)
* Use builtin `UUID` type for `uuid` format in schemas by @PhilipTrauner in [#11](https://github.com/CreateAPI/CreateAPI/pull/11)
* Fix tests by @PhilipTrauner in [#13](https://github.com/CreateAPI/CreateAPI/pull/13)


**Full Changelog**: https://github.com/CreateAPI/CreateAPI/compare/0.0.1...0.0.2

## 0.0.1

### Jan 3, 2022

Initial pre-release
