# Dart LSIF indexer

Visit https://lsif.dev/ to learn about LSIF.

## Installation

Required tools:

- [Dart SDK](https://dart.dev/get-dart)

## Indexing your repository

Install dependencies:

```
pub get
```

Run lsif-dart:

```
git clone https://github.com/sourcegraph/lsif-dart
cd lsif-dart
pub get
pub run crossdart --input <path to dir containing pubspec.yaml and lib/>
```

## Historical notes

lsif-dart builds off of [crossdart](https://github.com/astashov/crossdart) for language analysis and adds an LSIF output mode.
