/// Baseclass for all template errors.
abstract class TemplateError implements Exception {
  const TemplateError([this.message]);

  final String? message;

  @override
  String toString() {
    if (message case var message?) {
      return '$runtimeType: $message';
    }

    return '$runtimeType';
  }
}

/// Raised if a template does not exist.
class TemplateNotFound extends TemplateError {
  const TemplateNotFound({String? path, String? message})
      : super(message ?? path);
}

/// Like [TemplateNotFound] but raised if multiple templates are selected.
class TemplatesNotFound extends TemplateNotFound {
  TemplatesNotFound({List<Object?>? names, super.message});
}

/// Raised to tell the user that there is a problem with the template.
class TemplateSyntaxError extends TemplateError {
  const TemplateSyntaxError(super.message,
      {this.path, this.line, this.start, this.end, this.char});

  final String? path;

  final int? line;

  final int? start;

  final int? end;

  final String? char;

  @override
  String toString() {
    var result = runtimeType.toString();

    if (path case var path?) {
      if (result.contains(',')) {
        result += ', file: $path';
      }

      result += ' file: $path';
    }

    if (line case var line?) {
      if (result.contains(',')) {
        result += ', line: $line';
      } else {
        result += ' line: $line';
      }
    }

    if (start case var start?) {
      if (result.contains(',')) {
        result += ', start char: $start';
      } else {
        result += ' start char: $start';
      }
    }

    if (end case var end?) {
      if (result.contains(',')) {
        result += ', end char: $end';
      } else {
        result += ' end char: $end';
      }
    }

    if (message case var message?) {
      return '$result: $message';
    }

    return result;
  }
}

/// Like a template syntax error, but covers cases where something in the
/// template caused an error at parsing time that wasn't necessarily caused
/// by a syntax error.
///
/// However it's a direct subclass of [TemplateSyntaxError] and has the same
/// attributes.
class TemplateAssertionError extends TemplateError {
  const TemplateAssertionError([super.message]);
}

/// A generic runtime error in the template engine.
///
/// Under some situations Jinja may raise this exception.
class TemplateRuntimeError extends TemplateError {
  const TemplateRuntimeError([super.message]);
}

class TemplateContextVariableNotFoundError extends TemplateError {
  final String variableName;

  const TemplateContextVariableNotFoundError(super.message,
      {required this.variableName});
}
