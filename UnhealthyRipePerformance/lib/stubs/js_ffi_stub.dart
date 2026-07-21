enum JSEvalFlag { global, module }

abstract class JSRef {
  int _refCount = 0;
  void dup() { _refCount++; }
  void free() { _refCount--; }
}
