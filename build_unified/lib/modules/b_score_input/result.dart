/// Result type for handling operations that can succeed or fail.
///
/// This sealed class represents the outcome of an operation that may fail
/// in expected ways. It's modeled after Rust's Result<T, E> and Kotlin's Result.
sealed class Result<T, E> {
  const Result();

  /// Creates a successful result.
  factory Result.success(T value) => Success<T, E>(value);

  /// Creates a failure result.
  factory Result.failure(E error) => Failure<T, E>(error);

  /// Returns true if this is a Success.
  bool get isSuccess => this is Success<T, E>;

  /// Returns true if this is a Failure.
  bool get isFailure => this is Failure<T, E>;

  /// Gets the success value, or null if this is a Failure.
  T? get valueOrNull => switch (this) {
    Success<T, E>(:final value) => value,
    Failure<T, E>() => null,
  };

  /// Gets the error, or null if this is a Success.
  E? get errorOrNull => switch (this) {
    Success<T, E>() => null,
    Failure<T, E>(:final error) => error,
  };

  /// Maps the success value to another type.
  Result<R, E> map<R>(R Function(T) fn) => switch (this) {
    Success<T, E>(:final value) => Success<R, E>(fn(value)),
    Failure<T, E>(:final error) => Failure<R, E>(error),
  };

  /// Maps the error to another type.
  Result<T, R> mapError<R>(R Function(E) fn) => switch (this) {
    Success<T, E>(:final value) => Success<T, R>(value),
    Failure<T, E>(:final error) => Failure<T, R>(fn(error)),
  };

  /// Executes fn if this is a Success.
  Result<R, E> flatMap<R>(Result<R, E> Function(T) fn) => switch (this) {
    Success<T, E>(:final value) => fn(value),
    Failure<T, E>(:final error) => Failure<R, E>(error),
  };

  /// Gets the value or throws if this is a Failure.
  T getOrThrow() => switch (this) {
    Success<T, E>(:final value) => value,
    Failure<T, E>(:final error) => throw error is Exception ? error : Exception(error.toString()),
  };

  /// Gets the value or returns a default if this is a Failure.
  T getOrElse(T Function(E) defaultFn) => switch (this) {
    Success<T, E>(:final value) => value,
    Failure<T, E>(:final error) => defaultFn(error),
  };

  /// Executes fn if this is a Failure.
  void onFailure(void Function(E) fn) {
    if (this is Failure<T, E>) {
      fn((this as Failure<T, E>).error);
    }
  }

  /// Executes fn if this is a Success.
  void onSuccess(void Function(T) fn) {
    if (this is Success<T, E>) {
      fn((this as Success<T, E>).value);
    }
  }
}

/// Represents a successful result containing a value.
final class Success<T, E> extends Result<T, E> {
  /// The successful value.
  final T value;

  const Success(this.value);

  @override
  String toString() => 'Success($value)';
}

/// Represents a failed result containing an error.
final class Failure<T, E> extends Result<T, E> {
  /// The error value.
  final E error;

  const Failure(this.error);

  @override
  String toString() => 'Failure($error)';
}
