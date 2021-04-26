[![CI](https://github.com/cofu-app/cbl-dart/actions/workflows/ci.yaml/badge.svg)](https://github.com/cofu-app/cbl-dart/actions/workflows/ci.yaml)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

# cbl-dart

This is the mono-repository for the `cbl-dart` project, wich implements Couchbase Lite for Dart.

## Dart packages

All Dart code is organized in several [packages].

| Package                         | Description                                                     | Pub                                                                               | Internal     |
| ------------------------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------ |
| [cbl]                           | The Dart API for Couchbase Lite                                 | [![](https://badgen.net/pub/v/cbl)](https://pub.dev/packages/cbl)                 |              |
| [cbl_data]                      | Utilities for data mapping and querying                         | [![](https://badgen.net/pub/v/cbl_data)](https://pub.dev/packages/cbl_data)       |              |
| [cbl_e2e_tests]                 | E2E tests                                                       |                                                                                   |              |
| [cbl_e2e_tests_standalone_dart] | Run E2E tests with standalone Dart                              |                                                                                   |              |
| [cbl_ffi]                       | FFI bindings for `libCouchbaseLiteC` and `libCouchbaseLiteDart` | [![](https://badgen.net/pub/v/cbl_ffi)](https://pub.dev/packages/cbl_ffi)         | :red_circle: |
| [cbl_flutter]                   | Packaging of binary libraries with Flutter apps                 | [![](https://badgen.net/pub/v/cbl_flutter)](https://pub.dev/packages/cbl_flutter) |              |
| [cbl_native]                    | Binary library distribution                                     | [![](https://badgen.net/pub/v/cbl_native)](https://pub.dev/packages/cbl_native)   | :red_circle: |

## Native libraries

Two native libraries are required to enable Couchbase Lite for Dart.

| Library                | Description                                                                     |
| ---------------------- | ------------------------------------------------------------------------------- |
| libCouchbaseLiteC      | Couchbase Lite implementation behind a C API (vendored from [couchbase-lite-C]) |
| [libCouchbaseLiteDart] | Compatibility layer to allow Dart code to use the Couchbase Lite C API          |

[packages]: https://github.com/cofu-app/cbl-dart/tree/main/packages
[cbl]: https://github.com/cofu-app/cbl-dart/tree/main/packages/cbl
[cbl_data]: https://github.com/cofu-app/cbl-dart/tree/main/packages/cbl_data
[cbl_e2e_tests]: https://github.com/cofu-app/cbl-dart/tree/main/packages/cbl_e2e_tests
[cbl_e2e_tests_standalone_dart]: https://github.com/cofu-app/cbl-dart/tree/main/packages/cbl_e2e_tests_standalone_dart
[cbl_ffi]: https://github.com/cofu-app/cbl-dart/tree/main/packages/cbl_ffi
[cbl_flutter]: https://github.com/cofu-app/cbl-dart/tree/main/packages/cbl_flutter
[cbl_native]: https://github.com/cofu-app/cbl-dart/tree/main/packages/cbl_native
[native]: https://github.com/cofu-app/cbl-dart/tree/main/native
[libcouchbaselitedart]: https://github.com/cofu-app/cbl-dart/tree/main/native/cbl-dart
[couchbase-lite-c]: https://github.com/couchbaselabs/couchbase-lite-C
