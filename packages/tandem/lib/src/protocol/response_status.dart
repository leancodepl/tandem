/// The status code of an HTTP response, from 100 to 999. Outside that range,
/// a debug build fails an assert.
extension type const ResponseStatus(int code) {
  this
    : assert(
        code >= 100 && code <= 999,
        'An HTTP status code has three digits, not $code.',
      );

  static const ok = ResponseStatus(200);
}
