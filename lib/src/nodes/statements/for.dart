import '../../context.dart';
import '../../runtime.dart';
import '../core.dart';

class ForStatement extends Statement {
  ForStatement(this.targets, this.iterable, this.body, {this.orElse})
      : _targetsLen = targets.length;

  final List<String> targets;
  final Expression iterable;
  final Node body;
  final Node orElse;

  final int _targetsLen;

  void unpack(Map<String, Object> data, Object current) {
    if (current is Iterable<Object>) {
      List<Object> list = current.toList();

      if (list.length < _targetsLen) {
        throw ArgumentError('not enough values to unpack '
            '(expected $_targetsLen, got ${list.length})');
      }

      if (list.length > _targetsLen) {
        throw ArgumentError(
            'too many values to unpack (expected $_targetsLen)');
      }

      for (int i = 0; i < _targetsLen; i++) {
        data[targets[i]] = list[i];
      }
    }
  }

  Map<String, Object> getDataForContext(
      List<Object> values, int i, Undefined undefined) {
    final Object current = values[i];
    Object prev = undefined;
    Object next = undefined;

    if (i > 0) {
      prev = values[i - 1];
    }

    if (i < values.length - 1) {
      next = values[i + 1];
    }

    bool changed(Object item) {
      if (i == 0) {
        return true;
      }

      if (item == values[i - 1]) {
        return false;
      }

      return true;
    }

    final Map<String, Object> data = <String, Object>{
      'loop': LoopContext(i, values.length, prev, next, changed),
    };

    if (targets.length == 1) {
      data[targets[0]] = current;
    } else {
      unpack(data, current);
    }

    return data;
  }

  void render(List<Object> list, Context context, StringSink outSink) {
    for (int i = 0; i < list.length; i++) {
      final Map<String, Object> data =
          getDataForContext(list, i, context.environment.undefined);
      context.apply(data, (Context context) {
        body.accept(outSink, context);
      });
    }
  }

  void loopIterable(
      Iterable<Object> values, Context context, StringSink outSink) {
    final List<Object> list = values.toList();
    render(list, context, outSink);
  }

  void loopMap(Map<Object, Object> dict, Context context, StringSink outSink) {
    final List<List<Object>> list = dict.entries
        .map<List<Object>>((MapEntry<Object, Object> entry) =>
            <Object>[entry.key, entry.value])
        .toList();
    render(list, context, outSink);
  }

  void loopString(String value, Context context, StringSink outSink) {
    final List<String> list = value.split('');
    render(list, context, outSink);
  }

  @override
  void accept(StringSink outSink, Context context) {
    final Object iterable = this.iterable.resolve(context);

    if (iterable == null) {
      // TODO: сравнить сообщение ошибки
      throw ArgumentError.notNull('iterable');
    }

    if (iterable is Iterable<Object> && iterable.isNotEmpty) {
      loopIterable(iterable, context, outSink);
    } else if (iterable is Map<Object, Object> && iterable.isNotEmpty) {
      loopMap(iterable, context, outSink);
    } else if (iterable is String && iterable.isNotEmpty) {
      loopString(iterable, context, outSink);
    } else {
      orElse?.accept(outSink, context);
    }
  }

  @override
  String toDebugString([int level = 0]) {
    final StringBuffer buffer = StringBuffer(' ' * level);
    buffer.writeln(
        'for ' + targets.join(', ') + ' in ' + iterable.toDebugString());
    buffer.write(body.toDebugString(level + 1));

    if (orElse != null) {
      buffer.writeln();
      buffer.write(' ' * level);
      buffer.writeln('else');
      buffer.write(orElse.toDebugString(level + 1));
    }

    return buffer.toString();
  }

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('For($targets, $iterable, $body}');

    if (orElse != null) {
      buffer.write(', orElse: $orElse');
    }

    buffer.write(')');
    return buffer.toString();
  }
}

class ForStatementWithFilter extends ForStatement {
  ForStatementWithFilter(
    List<String> targets,
    Expression iterable,
    Node body,
    this.filter, {
    Node orElse,
  }) : super(targets, iterable, body, orElse: orElse);

  final Expression filter;

  Map<String, Object> getDataForFilter(List<Object> values, int i) {
    final Object current = values[i];
    final Map<String, Object> data = <String, Object>{};

    if (targets.length == 1) {
      if (current is MapEntry<Object, Object>) {
        data[targets.first] = <Object>[current.key, current.value];
      } else {
        data[targets.first] = current;
      }
    } else {
      unpack(data, current);
    }

    return data;
  }

  List<Object> filterValues(Iterable<Object> values, Context context) {
    final List<Object> list = values.toList();
    final List<Object> filteredList = <Object>[];

    for (int i = 0; i < list.length; i++) {
      final Map<String, Object> data = getDataForFilter(list, i);

      context.apply(data, (Context context) {
        if (toBool(filter.resolve(context))) filteredList.add(list[i]);
      });
    }

    return filteredList;
  }

  @override
  void loopIterable(
      Iterable<Object> values, Context context, StringSink outSink) {
    final List<Object> list = filterValues(values, context);
    render(list, context, outSink);
  }

  @override
  void loopMap(Map<Object, Object> dict, Context context, StringSink outSink) {
    final List<Object> list = filterValues(
        dict.entries.map<Object>((MapEntry<Object, Object> entry) =>
            <Object>[entry.key, entry.value]),
        context);
    render(list, context, outSink);
  }

  @override
  void loopString(String value, Context context, StringSink outSink) {
    final List<Object> list = filterValues(value.split(''), context);
    render(list, context, outSink);
  }

  @override
  String toDebugString([int level = 0]) {
    final StringBuffer buffer = StringBuffer(' ' * level);
    buffer
        .write('for ' + targets.join(', ') + ' in ' + iterable.toDebugString());

    if (filter != null) {
      buffer.writeln(' if ' + filter.toDebugString());
    } else {
      buffer.writeln();
    }

    buffer.write(body.toDebugString(level + 1));

    if (orElse != null) {
      buffer.writeln();
      buffer.write(' ' * level);
      buffer.writeln('else');
      buffer.write(orElse.toDebugString(level + 1));
    }

    return buffer.toString();
  }

  @override
  String toString() {
    final StringBuffer buffer =
        StringBuffer('ForWithFilter($targets, $iterable, $body, $filter}');

    if (orElse != null) {
      buffer.write(', orElse: $orElse');
    }

    buffer.write(')');
    return buffer.toString();
  }
}
