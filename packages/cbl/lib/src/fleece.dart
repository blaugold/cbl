import 'dart:collection';
import 'dart:ffi';

import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';

import 'bindings/bindings.dart';
import 'errors.dart';
import 'ffi_utils.dart';

export 'bindings/fleece.dart' show ValueType, CopyFlag;

// === Doc =====================================================================

/// An [Doc] points to (and often owns) Fleece-encoded data and provides access
/// to its Fleece values.
class Doc {
  static late final _bindings = CBLBindings.instance.fleece.doc;

  /// Creates an [Doc] from JSON-encoded data.
  ///
  /// The data is first encoded into Fleece, and the Fleece data is kept by the
  /// doc.
  factory Doc.fromJson(String json) => runArena(() {
        final error = malloc<Uint8>();

        final docPointer = _bindings.fromJSON(scoped(Utf8.toUtf8(json)), error);
        if (docPointer == nullptr) {
          throw FleeceException(
            'Could not create Doc from json.',
            error.value.toFleeceErrorCode,
          );
        }

        return Doc._(docPointer);
      });

  Doc._(this._ref) {
    _bindings.bindToDartObject(this, _ref);
  }

  final Pointer<Void> _ref;

  /// Returns the root value in the [Doc], usually an [Dict].
  Value get root => Value.fromPointer(_bindings.getRoot(_ref));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Doc &&
          runtimeType == other.runtimeType &&
          _ref.address == other._ref.address;
}

// === Value ===================================================================

/// The core Fleece data type is Value: a reference to a value in Fleece-encoded
/// data. A Value can represent any JSON type (plus binary data).
///
/// - Scalar data types -- numbers, booleans, null, strings, data -- can be
///   accessed using individual functions of the form `as...`; these return the
///   scalar value, or a default zero/false/null value if the value is not of
///   that type.
/// - Collections -- arrays and dictionaries -- have their own subclasses: Array
///   and Dict. To coerce an Value to a collection type, call [asArray] or
///   [asDict]. If the value is not of that type, null is returned. (Array and
///   Dict are documented fully in their own sections.)
class Value {
  static late final _bindings = CBLBindings.instance.fleece.value;

  /// Creates a [Value] based on a pointer to the the native value.
  ///
  /// {@template fleece.Value.fromPointer}
  /// If a Value is backed by a [Doc], the native Doc will be kept in memory at
  /// least as long as this Value has not been garbage collected. This can be
  /// disabled by setting [bindToDoc] to `false`. A [Doc] will always keep
  /// it's native value alive during it's lifetime.
  ///
  /// Per default a Value will __not__ update the ref count of the native value
  /// according to it's lifetime. When [bindToValue] is `true` the native
  /// value's ref count will be increment during construction and decremented
  /// during destruction. In case the native value has an initial ref count of
  /// 1, [retain] can be set to `false` to ensure the ref count goes to 0 when
  /// the Value is destroyed.
  ///
  /// Only mutable values can be ref counted.
  /// {@endtemplate}
  Value.fromPointer(
    this.ref, {
    bool? bindToValue,
    bool? retain,
    bool? bindToDoc,
  }) {
    assert(
      retain == null || bindToValue == true,
      'retain can only be used when bindToValue is true',
    );

    if (bindToValue ?? false) {
      _bindings.bindToDartObject(this, ref, (retain ?? true).toInt);
    }

    if (bindToDoc ?? true) {
      _bindings.bindDocToDartObject(this, ref);
    }
  }

  /// Pointer to the value in memory.
  final Pointer<Void> ref;

  /// Looks up the Doc containing the Value, or null if the Value was created
  /// without a Doc.
  Doc? get doc {
    final pointer = _bindings.findDoc(ref);
    return pointer == nullptr ? null : Doc._(pointer);
  }

  /// Returns the data type of an arbitrary Value.
  ValueType get type => _bindings.getType(ref).toFleeceValueType;

  /// Whether this value represents an `undefined` value.
  bool get isUndefined => type == ValueType.undefined;

  /// Whether this value represents null.
  bool get isNull => type == ValueType.Null;

  /// Returns true if the value is non-null and represents an integer.
  bool get isInteger => _bindings.isInteger(ref).toBool;

  /// Returns true if the value is non-null and represents a 64-bit
  /// floating-point number.
  bool get isDouble => _bindings.isDouble(ref).toBool;

  /// Returns a value coerced to boolean. This will be true unless the value is
  /// undefined, null, false, or zero.
  bool get asBool => _bindings.asBool(ref).toBool;

  /// Returns a value coerced to an integer. True and false are returned as 1
  /// and 0, and floating-point numbers are rounded. All other types are
  /// returned as 0.
  int get asInt => _bindings.asInt(ref);

  /// Returns a value coerced to a 64-bit floating point number. True and false
  /// are returned as 1.0 and 0.0, and integers are converted to float. All
  /// other types are returned as 0.0.
  double get asDouble => _bindings.asDouble(ref);

  /// Returns the exact contents of a string value, or null for all other types.
  String get asString {
    _bindings.asString(ref, globalSlice);
    return globalSlice.ref.toUtf8();
  }

  /// If a Value represents an array, returns it as a [Array], else null.
  Array? get asArray => type == ValueType.array ? Array.fromPointer(ref) : null;

  /// If a Value represents a dictionary, returns it as a [Dict], else null.
  Dict? get asDict => type == ValueType.dict ? Dict.fromPointer(ref) : null;

  /// Returns a string representation of any scalar value. Data values are
  /// returned in raw form. Arrays and dictionaries don't have a representation
  /// and will return null.
  String? get scalarToString {
    _bindings.scalarToString(ref, globalSlice);
    return globalSlice.ref.buf == nullptr ? null : globalSlice.ref.toUtf8();
  }

  /// Encodes a Fleece value as JSON (or a JSON fragment.) Any Data values will
  /// become base64-encoded JSON strings.
  String toJson({
    bool json5 = false,
    bool canonical = true,
  }) {
    _bindings.toJson(ref, json5.toInt, canonical.toInt, globalSlice);
    return globalSlice.toUtf8AndFree();
  }

  Object? toObject() {
    switch (type) {
      case ValueType.undefined:
        throw UnsupportedError(
          'ValueType.undefined has no equivalent Dart type',
        );
      case ValueType.Null:
        return null;
      case ValueType.boolean:
        return asBool;
      case ValueType.number:
        return isInteger ? asInt : asDouble;
      case ValueType.string:
        return asString;
      case ValueType.array:
        return asArray!.toObject();
      case ValueType.dict:
        return asDict!.toObject();
      case ValueType.data:
        throw UnimplementedError('TODO: Fleece data');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Value &&
          runtimeType == other.runtimeType &&
          _bindings.isEqual(ref, other.ref).toBool;

  @override
  int get hashCode {
    switch (type) {
      case ValueType.undefined:
      case ValueType.Null:
        return super.hashCode;
      case ValueType.boolean:
        return super.hashCode ^ asBool.hashCode;
      case ValueType.number:
        return super.hashCode ^ asInt.hashCode;
      case ValueType.string:
        return super.hashCode ^ asString.hashCode;
      case ValueType.data:
        // TODO: update when ValueType.data is implemented
        return super.hashCode;
      case ValueType.array:
        return super.hashCode ^ asArray.hashCode;
      case ValueType.dict:
        return super.hashCode ^ asDict.hashCode;
    }
  }

  @override
  String toString() {
    switch (type) {
      case ValueType.undefined:
        return 'undefined';
      case ValueType.Null:
      case ValueType.boolean:
      case ValueType.number:
        return scalarToString!;
      case ValueType.string:
        return '"${scalarToString!}"';
      case ValueType.array:
        return asArray.toString();
      case ValueType.dict:
        return asDict.toString();
      case ValueType.data:
        return '<DATA>';
    }
  }
}

// === Array ===================================================================

/// A Fleece array.
class Array extends Value with ListMixin<Value> {
  static late final _bindings = CBLBindings.instance.fleece.array;

  /// Creates an [Array] based on a pointer to the the native value.
  ///
  /// {@macro fleece.Value.fromPointer}
  Array.fromPointer(
    Pointer<Void> ref, {
    bool? bindToValue,
    bool? retain,
    bool? bindToDoc,
  }) : super.fromPointer(
          ref,
          bindToValue: bindToValue,
          retain: retain,
          bindToDoc: bindToDoc,
        );

  @override
  int get length => _bindings.count(ref);

  @override
  set length(int length) => throw _immutableValueException();

  @override
  bool get isEmpty => _bindings.isEmpty(ref).toBool;

  @override
  Value get first => this[0];

  @override
  Value get last => this[length - 1];

  /// If the array is mutable, returns it cast to [MutableArray], else null.
  MutableArray? get asMutable {
    final pointer = _bindings.asMutable(ref);
    return pointer == nullptr ? null : MutableArray.fromPointer(pointer);
  }

  @override
  List<Object?> toObject() => map((element) => element.toObject()).toList();

  @override
  Value operator [](int index) => Value.fromPointer(_bindings.get(ref, index));

  @override
  void operator []=(int index, Object? value) =>
      throw _immutableValueException();

  @override
  int get hashCode => fold(0, (hashCode, value) => hashCode ^ value.hashCode);
}

class MutableArray extends Array {
  static late final _bindings = CBLBindings.instance.fleece.mutableArray;

  /// Creates a [MutableArray] based on a pointer to the the native value.
  ///
  /// {@macro fleece.Value.fromPointer}
  MutableArray.fromPointer(
    Pointer<Void> value, {
    bool? bindToValue = true,
    bool? retain,
  }) : super.fromPointer(
          value,
          bindToValue: bindToValue,
          retain: retain,
          bindToDoc: false,
        );

  /// Creates a new empty [MutableArray].
  factory MutableArray([Iterable<Object?>? from]) {
    final result = MutableArray.fromPointer(_bindings.makeNew(), retain: false);

    if (from != null) {
      result.addAll(from);
    }

    return result;
  }

  /// Creates a new [MutableArray] that's a copy of the source [Array].
  ///
  /// Copying an immutable Array is very cheap (only one small allocation)
  /// unless the [CopyFlag.copyImmutables] is set.
  ///
  /// Copying a mutable Array is cheap if it's a shallow copy, but if
  /// [CopyFlag.deepCopy] is true, nested mutable Arrays and [Dict]s are also
  /// copied, recursively; if [CopyFlag.copyImmutables] is also set, immutable
  /// values are also copied.
  factory MutableArray.mutableCopy(
    Array source, {
    Set<CopyFlag> flags = const {},
  }) =>
      MutableArray.fromPointer(
        _bindings.mutableCopy(source.ref, flags.toCFlags()),
        retain: false,
      );

  /// If the Array was created by [MutableArray.mutableCopy], returns the original
  /// source Array.
  Array? get source {
    final pointer = _bindings.getSource(ref);
    return pointer == nullptr ? null : Array.fromPointer(pointer);
  }

  /// Returns true if the [Array] has been changed from the source it was copied
  /// from.
  bool get isChanged => _bindings.isChanged(ref).toBool;

  @override
  set length(int length) => _bindings.resize(ref, length);

  @override
  set first(Object? value) {
    this[0] = value;
  }

  @override
  set last(Object? value) {
    this[length - 1] = value;
  }

  @override
  void operator []=(int index, Object? value) {
    RangeError.checkValidIndex(index, this);
    final slot = _bindings.set(ref, index);
    _setSlotValue(slot, value);
  }

  @override
  void add(Object? element) {
    final slot = _bindings.append(ref);
    _setSlotValue(slot, element);
  }

  @override
  void addAll(Iterable<Object?> iterable) {
    var i = length;
    for (final element in iterable) {
      assert(length == i || (throw ConcurrentModificationError(this)));
      add(element);
      i++;
    }
  }

  @override
  void removeRange(int start, int end) {
    RangeError.checkValidRange(start, end, length);
    _bindings.remove(ref, start, end - start);
  }

  /// Inserts a contiguous range of JSON `null` values into the array.
  ///
  /// [start] is the zero-based index of the first value to be inserted.
  /// [count] is the number of items to insert.
  void insertNulls(int start, int count) {
    RangeError.checkValidIndex(start, this, 'start');
    _bindings.insert(ref, start, count);
  }

  /// Convenience function for getting an dict-valued property in mutable form.
  ///
  /// - If the value for the [index] is not a dict, returns null.
  /// - If the value is a mutable dict, returns it.
  /// - If the value is an immutable dict, this function makes a mutable copy,
  ///   assigns the copy as the property value, and returns the copy.
  MutableDict? mutableDict(int index) {
    final pointer = _bindings.getMutableDict(ref, index);
    return pointer == nullptr ? null : MutableDict.fromPointer(pointer);
  }

  /// Convenience function for getting a array-valued property in mutable form.
  ///
  /// - If the value for the [index] is not an array, returns null.
  /// - If the value is a mutable array, returns it.
  /// - If the value is an immutable array, this function makes a mutable copy,
  ///   assigns the copy as the property value, and returns the copy.
  MutableArray? mutableArray(int index) {
    final pointer = _bindings.getMutableArray(ref, index);
    return pointer == nullptr ? null : MutableArray.fromPointer(pointer);
  }
}

// === Dict ====================================================================

/// A Fleece dictionary.
class Dict extends Value with MapMixin<String, Value> {
  static late final _bindings = CBLBindings.instance.fleece.dict;

  /// Creates a [Dict] based on a pointer to the the native value.
  ///
  /// {@macro fleece.Value.fromPointer}
  Dict.fromPointer(
    Pointer<Void> value, {
    bool? bindToValue,
    bool? retain,
    bool? bindToDoc,
  }) : super.fromPointer(
          value,
          bindToValue: bindToValue,
          retain: retain,
          bindToDoc: bindToDoc,
        );

  /// Returns the number of items in a dictionary.
  @override
  int get length => _bindings.count(ref);

  /// Returns true if a dictionary is empty. Depending on the dictionary's
  /// representation, this can be faster than `count == 0`.
  @override
  bool get isEmpty => _bindings.isEmpty(ref).toBool;

  @override
  bool get isNotEmpty => !isEmpty;

  /// If the dictionary is mutable, returns it cast to [MutableDict], else null.
  MutableDict? get asMutable {
    final pointer = _bindings.asMutable(ref);
    return pointer == nullptr ? null : MutableDict.fromPointer(pointer);
  }

  @override
  late final Iterable<String> keys = _DictKeyIterable(this);

  @override
  Value operator [](Object? key) => runArena(() {
        assert(key is String, 'Dict key must be a non-null String');
        final keyPointer = scoped(Utf8.toUtf8(key as String));
        return Value.fromPointer(_bindings.get(ref, keyPointer));
      });

  @override
  void operator []=(String key, Object? value) =>
      throw _immutableValueException();

  @override
  void clear() => throw _immutableValueException();

  @override
  Value? remove(Object? key) => throw _immutableValueException();

  @override
  int get hashCode => entries.fold(0, (hashCode, entry) {
        return hashCode ^ entry.key.hashCode ^ entry.value.hashCode;
      });

  @override
  Map<String, Object?> toObject() =>
      Map.fromEntries(entries.map((e) => MapEntry(e.key, e.value.toObject())));
}

/// Iterable which iterates over the keys of a [Dict].
class _DictKeyIterable extends Iterable<String> {
  _DictKeyIterable(this.dict);

  final Dict dict;

  @override
  Iterator<String> get iterator => _DictKeyIterator(dict);
}

/// Iterator which iterates over the keys of a [Dict].
class _DictKeyIterator extends Iterator<String> {
  static late final _bindings = CBLBindings.instance.fleece.dictIterator;

  _DictKeyIterator(this.dict);

  final Dict dict;

  Pointer<DictIterator>? iterator;

  @override
  late String current;

  @override
  bool moveNext() {
    bool updateCurrent() {
      final it = iterator!.ref;
      final slice = it.keyString.ref;

      // Get value to check if iterator has entry available.
      final value = _bindings.getValue(it.iterator);
      if (value == nullptr) return false;

      // Update current with keyString
      _bindings.getKeyString(it.iterator, it.keyString);
      current = slice.toUtf8();
      return true;
    }

    if (iterator == null) {
      iterator = _bindings.begin(this, dict.ref);
      return updateCurrent();
    } else {
      if (!_bindings.next(iterator!.ref.iterator).toBool) return false;
      return updateCurrent();
    }
  }
}

/// A mutable Fleece [Dict].
class MutableDict extends Dict {
  static late final _bindings = CBLBindings.instance.fleece.mutableDict;

  /// Creates a [MutableDict] based on a pointer to the the native value.
  ///
  /// {@macro fleece.Value.fromPointer}
  MutableDict.fromPointer(
    Pointer<Void> value, {
    bool? bindToValue = true,
    bool? retain,
  }) : super.fromPointer(
          value,
          bindToValue: bindToValue,
          retain: retain,
          bindToDoc: false,
        );

  /// Creates a new empty [MutableDict].
  factory MutableDict([Map<String, Object?>? from]) {
    final result = MutableDict.fromPointer(_bindings.makeNew(), retain: false);

    if (from != null) {
      result.addAll(from);
    }

    return result;
  }

  /// Creates a new [MutableDict] that's a copy of the source [Dict].
  ///
  /// Copying an immutable [Dict] is very cheap (only one small allocation.) The
  /// [CopyFlag.deepCopy] is ignored.
  ///
  /// Copying a [MutableDict] is cheap if it's a shallow copy, but if [flags]
  /// contains [CopyFlag.deepCopy], nested mutable Dicts and [Array]s are also
  /// copied, recursively.
  factory MutableDict.mutableCopy(
    Dict source, {
    Set<CopyFlag> flags = const {},
  }) =>
      MutableDict.fromPointer(
        _bindings.mutableCopy(source.ref, flags.toCFlags()),
        retain: false,
      );

  /// If the Dict was created by [MutableDict.mutableCopy], returns the original
  /// source Dict.
  Dict? get source {
    final pointer = _bindings.getSource(ref);
    return pointer == nullptr ? null : Dict.fromPointer(pointer);
  }

  /// Returns true if the Dict has been changed from the source it was copied
  /// from.
  bool get isChanged => _bindings.isChanged(ref).toBool;

  @override
  void operator []=(String key, Object? value) => runArena(() {
        final slot = _bindings.set(ref, scoped(Utf8.toUtf8(key)));
        _setSlotValue(slot, value);
      });

  @override
  void addAll(Map<String, Object?> other) {
    for (final key in other.keys) {
      this[key] = other[key];
    }
  }

  @override
  void clear() => _bindings.removeAll(ref);

  @override
  Value? remove(Object? key) => runArena(() {
        assert(key is String);
        final value = this[key];

        _bindings.remove(ref, scoped(Utf8.toUtf8(key as String)));

        return value;
      });

  /// Convenience function for getting an dict-valued property in mutable form.
  ///
  /// - If the value for the key is not an dict, returns null.
  /// - If the value is a mutable dict, returns it.
  /// - If the value is an immutable dict, this function makes a mutable copy,
  ///   assigns the copy as the property value, and returns the copy.
  MutableDict? mutableDict(String key) => runArena(() {
        final pointer = _bindings.getMutableDict(ref, scoped(Utf8.toUtf8(key)));
        return pointer == nullptr ? null : MutableDict.fromPointer(pointer);
      });

  /// Convenience function for getting a array-valued property in mutable form.
  ///
  /// - If the value for the key is not a array, returns null.
  /// - If the value is a mutable array, returns it.
  /// - If the value is an immutable array, this function makes a mutable copy,
  ///   assigns the copy as the property value, and returns the copy.
  MutableArray? mutableArray(String key) => runArena(() {
        final pointer =
            _bindings.getMutableArray(ref, scoped(Utf8.toUtf8(key)));
        return pointer == nullptr ? null : MutableArray.fromPointer(pointer);
      });
}

// === SlotSetter ==============================================================

abstract class SlotSetter {
  static final _instances = <SlotSetter>[_DefaultSlotSetter()];

  static void register(SlotSetter setter) {
    if (!_instances.contains(setter)) {
      _instances.add(setter);
    }
  }

  static SlotSetter _findForValue(Object? value) {
    final setter = _instances.firstWhereOrNull((it) => it.canSetValue(value));

    if (setter == null) {
      throw ArgumentError.value(
        value,
        'value',
        'value is not compatible with Fleece',
      );
    }

    return setter;
  }

  bool canSetValue(Object? value);

  void setSlotValue(Pointer<FLSlot> slot, Object? value);
}

class _DefaultSlotSetter implements SlotSetter {
  late final _slotBindings = CBLBindings.instance.fleece.slot;

  @override
  bool canSetValue(Object? value) =>
      value == null ||
      value is bool ||
      value is int ||
      value is double ||
      value is String ||
      value is Iterable ||
      value is Map ||
      value is Value;

  @override
  void setSlotValue(Pointer<FLSlot> slot, Object? value) {
    value = _recursivelyConvertCollectionsToFleece(value);

    if (value == null) {
      _slotBindings.setNull(slot);
    } else if (value is bool) {
      _slotBindings.setBool(slot, value.toInt);
    } else if (value is int) {
      _slotBindings.setInt(slot, value);
    } else if (value is double) {
      _slotBindings.setDouble(slot, value);
    } else if (value is String) {
      runArena(() {
        _slotBindings.setString(slot, scoped(Utf8.toUtf8(value as String)));
      });
    } else if (value is Value) {
      _slotBindings.setValue(slot, value.ref);
    }
  }

  static Object? _recursivelyConvertCollectionsToFleece(Object? value) {
    if (value is Map && value is! Dict) {
      return MutableDict()..addAll(value.cast());
    } else if (value is Iterable && value is! Array) {
      return MutableArray()..addAll(value);
    } else {
      return value;
    }
  }
}

void _setSlotValue(Pointer<FLSlot> slot, Object? value) {
  SlotSetter._findForValue(value).setSlotValue(slot, value);
}

// === Misc ====================================================================

Object _immutableValueException() =>
    UnsupportedError('You cannot mutate an immutable Value.');
