import 'package:jinja/src/environment.dart';
import 'package:jinja/src/exceptions.dart';
import 'package:jinja/src/utils.dart';
import 'package:test/test.dart';

import 'environment.dart';

void main() {
  group('Parser', () {
    test('php syntax', () {
      var env = Environment(
          blockStart: '<?',
          blockEnd: '?>',
          variableStart: '<?=',
          variableEnd: '?>',
          commentStart: '<!--',
          commentEnd: '-->');
      var tmpl = env.fromString('<!-- I\'m a comment -->'
          '<? for item in seq -?>\n    <?= item ?>\n<?- endfor ?>');
      expect(tmpl.render({'seq': range(5)}), equals('01234'));
    });

    test('erb syntax', () {
      var env = Environment(
          blockStart: '<%',
          blockEnd: '%>',
          variableStart: '<%=',
          variableEnd: '%>',
          commentStart: '<%#',
          commentEnd: '%>');
      var tmpl = env.fromString('<%# I\'m a comment %>'
          '<% for item in seq -%>\n    <%= item %><%- endfor %>');
      expect(tmpl.render({'seq': range(5)}), equals('01234'));
    });

    test('comment syntax', () {
      var env = Environment(
          blockStart: '<!--',
          blockEnd: '-->',
          variableStart: '\${',
          variableEnd: '}',
          commentStart: '<!--#',
          commentEnd: '-->');
      var tmpl = env.fromString('<!--# I\'m a comment -->'
          '<!-- for item in seq --->    \${item}<!--- endfor -->');
      expect(tmpl.render({'seq': range(5)}), equals('01234'));
    });

    test('balancing', () {
      var tmpl = env.fromString('''{{{'foo':'bar'}['foo']}}''');
      expect(tmpl.render(), equals('bar'));
    });

    test('error messages', () {
      void assertError(String source, String expekted) {
        expect(
            () => env.fromString(source),
            throwsA(predicate<TemplateSyntaxError>(
                (error) => error.message == expekted)));
      }

      assertError(
          '{% for item in seq %}...{% endif %}',
          'Encountered unknown tag \'endif\'. Jinja was looking '
              'for the following tags: \'endfor\' or \'else\'. The '
              'innermost block that needs to be closed is \'for\'.');
      assertError(
          '{% if foo %}{% for item in seq %}...{% endfor %}{% endfor %}',
          'Encountered unknown tag \'endfor\'. Jinja was looking for '
              'the following tags: \'elif\' or \'else\' or \'endif\'. The '
              'innermost block that needs to be closed is \'if\'.');
      assertError(
          '{% if foo %}',
          'Unexpected end of template. Jinja was looking for the '
              'following tags: \'elif\' or \'else\' or \'endif\'. The '
              'innermost block that needs to be closed is \'if\'.');
      assertError(
          '{% for item in seq %}',
          'Unexpected end of template. Jinja was looking for the '
              'following tags: \'endfor\' or \'else\'. The innermost block '
              'that needs to be closed is \'for\'.');
      assertError('{% block foo-bar-baz %}', 'use an underscore instead');
      assertError(
          '{% unknown_tag %}', 'Encountered unknown tag \'unknown_tag\'.');
    });
  });
}
