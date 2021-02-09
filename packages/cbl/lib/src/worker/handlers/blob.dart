import 'dart:ffi';

import '../../bindings/bindings.dart';
import '../../errors.dart';
import '../../ffi_utils.dart';
import '../handlers.dart';
import '../worker.dart';
import 'shared.dart';

late final _readStreamBindings = CBLBindings.instance.blobs.readStream;

class OpenBlobReadStream extends ObjectRequest {
  OpenBlobReadStream(int address) : super(address);
}

int openBlobReadStream(OpenBlobReadStream request) => _readStreamBindings
    .openContentStream(request.pointer.cast(), globalError)
    .checkResultAndError()
    .address;

class ReadFromBlobReadStream extends ObjectRequest {
  ReadFromBlobReadStream(int address, this._bufferAddress, this.bufferSize)
      : super(address);

  final int _bufferAddress;

  final int bufferSize;

  Pointer<Uint8> get bufferPointer => _bufferAddress.toPointer.cast();
}

int readFromBlobReadStream(ReadFromBlobReadStream request) {
  final bytesRead = _readStreamBindings.read(
    request.pointer.cast(),
    request.bufferPointer,
    request.bufferSize,
    globalError,
  );

  if (bytesRead == -1) {
    checkError();
  }

  return bytesRead;
}

class CloseBlobReadStream extends ObjectRequest {
  CloseBlobReadStream(int address) : super(address);
}

void closeBlobReadStream(CloseBlobReadStream request) =>
    _readStreamBindings.close(request.pointer.cast());

late final _writeStreamBindings = CBLBindings.instance.blobs.writeStream;

class OpenBlobWriteStream extends ObjectRequest {
  OpenBlobWriteStream(int address) : super(address);
}

int openBlobWriteStream(OpenBlobWriteStream request) => _writeStreamBindings
    .makeNew(request.pointer.cast(), globalError)
    .checkResultAndError()
    .address;

class WriteToBlobWriteStream extends ObjectRequest {
  WriteToBlobWriteStream(int address, this._chunkAddress, this.chunkSize)
      : super(address);

  final int _chunkAddress;

  final int chunkSize;

  Pointer<Uint8> get chunkPointer => Pointer.fromAddress(_chunkAddress);
}

void writeToBlobWriteStream(WriteToBlobWriteStream request) =>
    _writeStreamBindings
        .write(
          request.pointer.cast(),
          request.chunkPointer,
          request.chunkSize,
          globalError,
        )
        .toBool
        .checkResultAndError();

class CloseBlobWriteStream extends ObjectRequest {
  CloseBlobWriteStream(int address) : super(address);
}

void closeBlobWriteStream(CloseBlobWriteStream request) =>
    _writeStreamBindings.close(request.pointer.cast());

class CreateBlobWithWriteStream extends ObjectRequest {
  CreateBlobWithWriteStream(int address, this.contentType) : super(address);

  final String? contentType;
}

int createBlobWithWriteStream(CreateBlobWithWriteStream request) =>
    _writeStreamBindings
        .createBlobWithStream(
          (request.contentType?.asUtf8Scoped).orNullptr,
          request.pointer.cast(),
        )
        .address;

void addBlobHandlersToRouter(RequestRouter router) {
  router.addHandler(openBlobReadStream);
  router.addHandler(readFromBlobReadStream);
  router.addHandler(closeBlobReadStream);
  router.addHandler(openBlobWriteStream);
  router.addHandler(writeToBlobWriteStream);
  router.addHandler(closeBlobWriteStream);
  router.addHandler(createBlobWithWriteStream);
}
