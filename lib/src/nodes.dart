import 'dart:math' as math;

import 'package:jinja/src/visitor.dart';

part 'nodes/expressions.dart';
part 'nodes/statements.dart';

typedef NodeVisitor = void Function(Node node);

abstract class Node {
  const Node();

  List<Node> get childrens {
    return const <Node>[];
  }

  R accept<C, R>(Visitor<C, R> visitor, C context);

  Iterable<T> findAll<T extends Node>() sync* {
    for (var child in childrens) {
      if (child is T) {
        yield child;
      }

      yield* child.findAll<T>();
    }
  }

  T findOne<T extends Node>() {
    var all = findAll<T>();
    return all.first;
  }

  void visitChildrens(NodeVisitor visitor) {
    childrens.forEach(visitor);
  }
}

class Output extends Node {
  Output(this.nodes);

  List<Node> nodes;

  @override
  List<Node> get childrens {
    return nodes;
  }

  @override
  R accept<C, R>(Visitor<C, R> visitor, C context) {
    return visitor.visitOutput(this, context);
  }

  @override
  String toString() {
    return 'Output(${nodes.join(', ')})';
  }

  static Node orSingle(List<Node> nodes) {
    switch (nodes.length) {
      case 0:
        return Data();
      case 1:
        return nodes[0];
      default:
        return Output(nodes);
    }
  }
}

class Data extends Node {
  Data([this.data = '']);

  String data;

  bool get isLeaf {
    return trimmed.isEmpty;
  }

  String get literal {
    return "'${data.replaceAll("'", r"\'").replaceAll('\r\n', r'\n').replaceAll('\n', r'\n')}'";
  }

  String get trimmed {
    return data.trim();
  }

  @override
  R accept<C, R>(Visitor<C, R> visitor, C context) {
    return visitor.visitData(this, context);
  }

  @override
  String toString() {
    return 'Data($literal)';
  }
}

class Template extends Node {
  Template(this.nodes) : blocks = <Block>[] {
    blocks.addAll(findAll<Block>());

    // TODO: remove/update
    if (nodes.isNotEmpty && nodes.first is Extends) {
      nodes.length = 1;
    }
  }

  final List<Node> nodes;

  final List<Block> blocks;

  @override
  List<Node> get childrens {
    return nodes;
  }

  @override
  R accept<C, R>(Visitor<C, R> visitor, C context) {
    return visitor.visitTemplate(this, context);
  }

  @override
  String toString() {
    return 'Template()';
  }
}
