import 'dart:collection' show HashMap;
import 'dart:math' show Random;

import 'package:meta/meta.dart' show internal;

import 'context.dart';
import 'defaults.dart' as defaults;
import 'exceptions.dart';
import 'lexer.dart';
import 'loaders.dart';
import 'nodes.dart';
import 'optimizer.dart';
import 'parser.dart';
import 'renderer.dart';
import 'visitor.dart';

/// Signature for the object attribute getter.
typedef FieldGetter = Object? Function(Object? object, String field);

enum PassArgument {
  context,
  environment,
}

/// Pass the [Context] as the first argument to the applied function when
/// called while rendering a template.
///
/// Can be used on functions, filters, and tests.
Function passContext(Function function) {
  Environment.passArguments[function] = PassArgument.context;
  return function;
}

/// Pass the [Environment] as the first argument to the applied function when
/// called while rendering a template.
///
/// Can be used on functions, filters, and tests.
Function passEnvironment(Function function) {
  Environment.passArguments[function] = PassArgument.environment;
  return function;
}

/// The core component of Jinja 2 is the Environment. It contains
/// important shared variables like configuration, filters, tests and others.
/// Instances of this class may be modified if they are not shared and if no
/// template was loaded so far.
class Environment {
  /// Cached [Lexer]'s
  @internal
  static final Expando<Lexer> lexers = Expando<Lexer>();

  /// [PassArgument] modifier for functions, filters and tests.
  @internal
  static final Expando<PassArgument> passArguments = Expando<PassArgument>();

  /// If `loader` is not `null`, templates will be loaded
  Environment(
      {this.commentStart = defaults.commentStart,
      this.commentEnd = defaults.commentEnd,
      this.variableStart = defaults.variableStart,
      this.variableEnd = defaults.variableEnd,
      this.blockStart = defaults.blockStart,
      this.blockEnd = defaults.blockEnd,
      this.lineCommentPrefix = defaults.lineCommentPrefix,
      this.lineStatementPrefix = defaults.lineStatementPrefix,
      this.leftStripBlocks = defaults.lStripBlocks,
      this.trimBlocks = defaults.trimBlocks,
      this.newLine = defaults.newLine,
      this.keepTrailingNewLine = defaults.keepTrailingNewLine,
      this.optimized = defaults.optimized,
      this.finalize = defaults.finalize,
      this.autoEscape = defaults.autoEscape,
      this.loader,
      this.autoReload = defaults.autoReload,
      Map<String, Object?>? globals,
      Map<String, Function>? filters,
      Map<String, Function>? tests,
      List<NodeVisitor>? modifiers,
      Map<String, Template>? templates,
      Random? random,
      this.fieldGetter = defaults.fieldGetter})
      : assert(checkFinalize(finalize)),
        wrappedFinalize = wrapFinalize(finalize),
        globals = HashMap<String, Object?>.of(defaults.globals),
        filters = HashMap<String, Function>.of(defaults.filters),
        tests = HashMap<String, Function>.of(defaults.tests),
        modifiers = List<NodeVisitor>.of(defaults.modifiers),
        templates = HashMap<String, Template>(),
        random = random ?? Random() {
    if (globals != null) {
      this.globals.addAll(globals);
    }

    if (filters != null) {
      this.filters.addAll(filters);
    }

    if (tests != null) {
      this.tests.addAll(tests);
    }

    if (modifiers != null) {
      this.modifiers.insertAll(0, modifiers);
    }

    if (templates != null) {
      this.templates.addAll(templates);
    }
  }

  /// The string marking the beginning of a comment.
  final String commentStart;

  /// The string marking the end of a comment.
  final String commentEnd;

  /// The string marking the beginning of a print statement.
  final String variableStart;

  /// The string marking the end of a print statement.
  final String variableEnd;

  /// The string marking the beginning of a block.
  final String blockStart;

  /// The string marking the end of a block
  final String blockEnd;

  /// If given and a string, this will be used as prefix for line based
  /// comments.
  final String? lineCommentPrefix;

  /// If given and a string, this will be used as prefix for line based
  /// statements.
  final String? lineStatementPrefix;

  /// If this is set to `true` leading spaces and tabs are stripped
  /// from the start of a line to a block.
  final bool leftStripBlocks;

  /// If this is set to `true` the first newline after a block is
  /// removed (block, not variable tag!).
  final bool trimBlocks;

  /// The sequence that starts a newline.
  ///
  /// Must be one of `'\r'`, `'\n'` or `'\r\n'`.
  final String newLine;

  /// Preserve the trailing newline when rendering templates.
  /// The default is `false`, which causes a single newline,
  /// if present, to be stripped from the end of the template.
  final bool keepTrailingNewLine;

  /// Should the optimizer be enabled?
  final bool optimized;

  /// A callable that can be used to process the result of a variable
  /// expression before it is output.
  ///
  /// For example one can convert `null` (`none`) implicitly into an empty
  /// string here.
  final Function finalize;

  @internal
  final Object? Function(Context context, Object? value) wrappedFinalize;

  /// If set to `true` the XML/HTML autoescaping feature is enabled by
  /// default.
  final bool autoEscape;

  /// The template loader for this environment.
  final Loader? loader;

  /// Some loaders load templates from locations where the template
  /// sources may change (ie: file system or database).
  ///
  /// If `autoReload` is set to `true` (default) every time a template is
  /// requested the loader checks if the source changed and if yes, it
  /// will reload the template. For higher performance it's possible to
  /// disable that.
  final bool autoReload;

  /// A map of variables that are available in every template loaded by
  /// the environment.
  final Map<String, Object?> globals;

  /// A map of filters that are available in every template loaded by
  /// the environment.
  final Map<String, Function> filters;

  /// A map of tests that are available in every template loaded by
  /// the environment.
  final Map<String, Function> tests;

  /// A list of template modifiers.
  final List<NodeVisitor> modifiers;

  /// A map of parsed templates loaded by the environment.
  final Map<String, Template> templates;

  /// [Random] generator used by some filters.
  final Random random;

  /// Function called by [getAttribute] to get object attribute.
  ///
  /// Default function throws [NoSuchMethodError].
  final FieldGetter fieldGetter;

  @override
  int get hashCode {
    return Object.hash(
        blockStart,
        blockEnd,
        variableStart,
        variableEnd,
        commentStart,
        commentEnd,
        lineStatementPrefix,
        lineCommentPrefix,
        trimBlocks,
        leftStripBlocks);
  }

  /// The lexer for this environment.
  Lexer get lexer {
    return lexers[this] ??= Lexer(this);
  }

  @override
  bool operator ==(Object? other) {
    return other is Environment &&
        blockStart == other.blockStart &&
        blockEnd == other.blockEnd &&
        variableStart == other.variableStart &&
        variableEnd == other.variableEnd &&
        commentStart == other.commentStart &&
        commentEnd == other.commentEnd &&
        lineStatementPrefix == other.lineStatementPrefix &&
        lineCommentPrefix == other.lineCommentPrefix &&
        trimBlocks == other.trimBlocks &&
        leftStripBlocks == other.leftStripBlocks;
  }

  /// Get an attribute of an object.
  Object? getAttribute(dynamic object, String attrbute) {
    return fieldGetter(object, attrbute);
  }

  /// Get an item of an object.
  Object? getItem(dynamic object, Object? key) {
    // TODO: dynamic invocation
    return object[key];
  }

  /// Common filter and test caller.
  @internal
  Object? callCommon(String name, List<Object?> positional,
      Map<Symbol, Object?> named, bool isFilter, Context? context) {
    var type = isFilter ? 'filter' : 'test';
    var map = isFilter ? filters : tests;
    var function = map[name];

    if (function == null) {
      throw TemplateRuntimeError('no $type named \'$name\'');
    }

    var pass = passArguments[function];

    if (pass == PassArgument.context) {
      if (context == null) {
        throw TemplateRuntimeError(
            'attempted to invoke context $type without context');
      }

      positional.insert(0, context);
    } else if (pass == PassArgument.environment) {
      positional.insert(0, this);
    }

    return Function.apply(function, positional, named);
  }

  /// If [name] not found throws [TemplateRuntimeError].
  Object? callFilter(String name, List<Object?> positional,
      [Map<Symbol, Object?> named = const <Symbol, Object?>{},
      Context? context]) {
    return callCommon(name, positional, named, true, context);
  }

  /// If [name] not found throws [TemplateRuntimeError].
  bool callTest(String name, List<Object?> positional,
      [Map<Symbol, Object?> named = const <Symbol, Object?>{},
      Context? context]) {
    return callCommon(name, positional, named, false, context) as bool;
  }

  /// Lex the given sourcecode and return a list of tokens.
  ///
  /// This can be useful for extension development and debugging templates.
  List<Token> lex(String source, {String? path}) {
    return lexer.tokenize(source, path: path);
  }

  /// Parse the list of tokens and return the AST nodes.
  ///
  /// This can be useful for debugging or to extract information from templates.
  List<Node> scan(List<Token> tokens, {String? path}) {
    return Parser(this, path: path).scan(tokens);
  }

  /// Parse the source code and return the AST nodes.
  ///
  /// This can be useful for debugging or to extract information from templates.
  List<Node> parse(String source, {String? path}) {
    var tokens = lex(source);
    return scan(tokens, path: path);
  }

  /// Load a template from a source string without using [loader].
  Template fromString(String source, {String? path}) {
    var nodes = Parser(this, path: path).parse(source);
    var template = Template.parsed(this, nodes, path: path);

    if (optimized) {
      template.accept(const Optimizer(), Context(this));
    }

    for (var modifier in modifiers) {
      modifier(template);
    }

    // Compiler.compile(template, this);
    return template;
  }

  /// Returns a list of templates for this environment.
  ///
  /// This requires that the loader supports the loader's
  /// [Loader.listTemplates] method.
  List<String> listTemplates() {
    var loader = this.loader;

    if (loader == null) {
      throw StateError('no loader for this environment specified');
    }

    return loader.listTemplates();
  }

  /// Load a template by name with [loader] and return a
  /// [Template]. If the template does not exist a [TemplateNotFound]
  /// exception is thrown.
  Template getTemplate(String template) {
    var loader = this.loader;

    if (loader == null) {
      // or assertion error?
      throw TemplateRuntimeError('no loader for this environment specified');
    }

    if (autoReload) {
      return templates[template] = loader.load(this, template);
    }

    return templates[template] ??= loader.load(this, template);
  }

  @internal
  static bool checkFinalize(Function finalize) {
    return finalize is Object? Function(Context, Object?) ||
        finalize is Object? Function(Environment, Object?) ||
        finalize is Object? Function(Object?);
  }

  @internal
  static Object? Function(Context, Object?) wrapFinalize(Function finalize) {
    if (finalize is Object? Function(Context, Object?)) {
      return finalize;
    }

    if (finalize is Object? Function(Environment, Object?)) {
      return (Context context, Object? value) {
        return finalize(context.environment, value);
      };
    }

    if (finalize is Object? Function(Object?)) {
      return (Context context, Object? value) {
        return finalize(value);
      };
    }

    throw TemplateAssertionError();
  }
}

/// The central `Template` object. This class represents a compiled template
/// and is used to evaluate it.
///
/// Normally the template is generated from `Environment` but
/// it also has a constructor that makes it possible to create a template
/// instance directly using the constructor. It takes the same arguments as
/// the environment constructor but it's not possible to specify a loader.
class Template extends Node {
  factory Template(String source,
      {String? path,
      Environment? environment,
      String blockStart = defaults.blockStart,
      String blockEnd = defaults.blockEnd,
      String variableStatr = defaults.variableStart,
      String variableEnd = defaults.variableEnd,
      String commentStart = defaults.commentStart,
      String commentEnd = defaults.commentEnd,
      String? lineCommentPrefix = defaults.lineCommentPrefix,
      String? lineStatementPrefix = defaults.lineStatementPrefix,
      bool trimBlocks = defaults.trimBlocks,
      bool leftStripBlocks = defaults.lStripBlocks,
      String newLine = defaults.newLine,
      bool keepTrailingNewLine = defaults.keepTrailingNewLine,
      bool optimized = defaults.optimized,
      Function finalize = defaults.finalize,
      bool autoEscape = defaults.autoEscape,
      Map<String, Object?>? globals,
      Map<String, Function>? filters,
      Map<String, Function>? tests,
      List<NodeVisitor>? modifiers,
      Random? random,
      FieldGetter fieldGetter = defaults.fieldGetter}) {
    environment ??= Environment(
        commentStart: commentStart,
        commentEnd: commentEnd,
        variableStart: variableStatr,
        variableEnd: variableEnd,
        blockStart: blockStart,
        blockEnd: blockEnd,
        lineCommentPrefix: lineCommentPrefix,
        lineStatementPrefix: lineStatementPrefix,
        leftStripBlocks: leftStripBlocks,
        trimBlocks: trimBlocks,
        newLine: newLine,
        keepTrailingNewLine: keepTrailingNewLine,
        optimized: optimized,
        finalize: finalize,
        autoEscape: autoEscape,
        autoReload: false,
        globals: globals,
        filters: filters,
        tests: tests,
        modifiers: modifiers,
        random: random,
        fieldGetter: fieldGetter);

    return environment.fromString(source, path: path);
  }

  @internal
  Template.parsed(this.environment, this.nodes, {this.path})
      : blocks = <Block>[] {
    blocks.addAll(findAll<Block>());

    // TODO: remove/update
    if (nodes.isNotEmpty && nodes.first is Extends) {
      nodes.length = 1;
    }
  }

  /// The environment used to parse and render template.
  final Environment environment;

  /// Modified nodes.
  final List<Node> nodes;

  /// Modified blocks.
  final List<Block> blocks;

  /// The path to the template if it was loaded.
  final String? path;

  @override
  List<Node> get childrens {
    return nodes;
  }

  @override
  R accept<C, R>(Visitor<C, R> visitor, C context) {
    return visitor.visitTemplate(this, context);
  }

  /// It accepts the same arguments as [render].
  Iterable<String> generate([Map<String, Object?>? data]) {
    var context = RenderContext(environment, data: data);
    return accept(const IterableRenderer(), context);
  }

  /// If no arguments are given the context will be empty.
  String render([Map<String, Object?>? data]) {
    var buffer = StringBuffer();
    var context = StringSinkRenderContext(environment, buffer, data: data);
    accept(const StringSinkRenderer(), context);
    return buffer.toString();
  }

  @override
  String toString() {
    if (path == null) {
      return 'Template()';
    }

    return 'Template($path)';
  }
}
