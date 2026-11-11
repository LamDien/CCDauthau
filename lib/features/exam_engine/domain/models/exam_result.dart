/// Typed result wrapper returned by `exam-engine` operations.
sealed class ExamResult<T> {
  const ExamResult();
}

final class ExamSuccess<T> extends ExamResult<T> {
  const ExamSuccess(this.data);
  final T data;
}

final class ExamError<T> extends ExamResult<T> {
  const ExamError(this.failure);
  final ExamFailure failure;
}

/// Typed failures produced during exam quota allocation or constrained selection.
sealed class ExamFailure {
  const ExamFailure(this.code, this.message);

  final String code;
  final String message;
}

final class InsufficientQuestionsFailure extends ExamFailure {
  const InsufficientQuestionsFailure(String message)
      : super('INSUFFICIENT_QUESTIONS', message);
}

final class InsufficientDistinctGroupsFailure extends ExamFailure {
  const InsufficientDistinctGroupsFailure(String message)
      : super('INSUFFICIENT_DISTINCT_POINT_GROUPS', message);
}

