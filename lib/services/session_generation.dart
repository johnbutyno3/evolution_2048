/// Tracks ownership of asynchronous session-identity operations.
///
/// A completed Future is not automatically allowed to publish its result:
/// callers capture a generation before an await and must verify it is still
/// current before committing session identity.
class SessionGeneration {
  int _current = 0;

  int get current => _current;

  int begin() => ++_current;

  bool isCurrent(int generation) => generation == _current;
}
