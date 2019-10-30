import 'package:jinja/jinja.dart';
import 'package:jinja/src/exceptions.dart';
import 'package:jinja/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('for', () {
    Environment env = Environment();

    test('simple', () {
      Template template =
          env.fromString('{% for item in seq %}{{ item }}{% endfor %}');
      expect(template.render(<String, Object>{'seq': range(10)}),
          equals('0123456789'));
    });

    test('else', () {
      Template template =
          env.fromString('{% for item in seq %}XXX{% else %}...{% endfor %}');
      expect(template.render(), equals('...'));
    });

    test('else scoping item', () {
      Template template = env
          .fromString('{% for item in [] %}{% else %}{{ item }}{% endfor %}');
      expect(template.render(<String, Object>{'item': 42}), equals('42'));
    });

    test('empty blocks', () {
      Template template =
          env.fromString('<{% for item in seq %}{% else %}{% endfor %}>');
      expect(template.render(), equals('<>'));
    });

    test('context vars', () {
      List<int> slist = <int>[42, 24];
      Template template;

      for (Iterable<int> seq in <Iterable<int>>[slist, slist.reversed]) {
        template = env.fromString('''{% for item in seq -%}
            {{ loop.index }}|{{ loop.index0 }}|{{ loop.revindex }}|{{
                loop.revindex0 }}|{{ loop.first }}|{{ loop.last }}|{{
               loop.length }}###{% endfor %}''');

        List<String> parts =
            template.render(<String, Object>{'seq': seq}).split('###');
        List<String> one = parts[0].split('|');
        List<String> two = parts[1].split('|');

        expect(one[0], equals('1'));
        expect(one[1], equals('0'));
        expect(one[2], equals('2'));
        expect(one[3], equals('1'));
        expect(one[4], equals('true'));
        expect(one[5], equals('false'));
        expect(one[6], equals('2'));

        expect(two[0], equals('2'));
        expect(two[1], equals('1'));
        expect(two[2], equals('1'));
        expect(two[3], equals('0'));
        expect(two[4], equals('false'));
        expect(two[5], equals('true'));
        expect(two[6], equals('2'));
      }
    });

    test('cycling', () {
      Template template = env.fromString('''{% for item in seq %}{{
            loop.cycle('<1>', '<2>') }}{% endfor %}{%
            for item in seq %}{{ loop.cycle(*through) }}{% endfor %}''');
      expect(
          template.render(<String, Object>{
            'seq': range(4),
            'through': <String>['<1>', '<2>']
          }),
          equals('<1><2>' * 4));
    });

    test('lookaround', () {
      Template template = env.fromString('''{% for item in seq -%}
            {{ loop.previtem|default('x') }}-{{ item }}-{{
            loop.nextitem|default('x') }}|
        {%- endfor %}''');
      expect(template.render(<String, Object>{'seq': range(4)}),
          equals('x-0-1|0-1-2|1-2-3|2-3-x|'));
    });

    test('changed', () {
      Template template = env.fromString('''{% for item in seq -%}
            {{ loop.changed(item) }},
        {%- endfor %}''');
      expect(
          template.render(<String, Object>{
            'seq': <int>[null, null, 1, 2, 2, 3, 4, 4, 4]
          }),
          equals('true,false,true,true,false,true,true,false,false,'));
    });

    test('scope', () {
      Template template =
          env.fromString('{% for item in seq %}{% endfor %}{{ item }}');
      expect(template.render(<String, Object>{'seq': range(10)}), equals(''));
    });

    test('varlen', () {
      Template template =
          env.fromString('{% for item in iter %}{{ item }}{% endfor %}');

      Iterable<int> inner() sync* {
        for (int i = 0; i < 5; i++) {
          yield i;
        }
      }

      expect(
          template.render(<String, Object>{'iter': inner()}), equals('01234'));
    });

    test('noniter', () {
      Template template =
          env.fromString('{% for item in none %}...{% endfor %}');
      expect(() => template.render(), throwsArgumentError);
    });

    // TODO: test recursive
    // TODO: test recursive lookaround
    // TODO: test recursive depth0
    // TODO: test recursive depth

    test('looploop', () {
      Template template = env.fromString('''{% for row in table %}
            {%- set rowloop = loop -%}
            {% for cell in row -%}
                [{{ rowloop.index }}|{{ loop.index }}]
            {%- endfor %}
        {%- endfor %}''');
      expect(
          template.render(<String, Object>{
            'table': <String>['ab', 'cd']
          }),
          '[1|1][1|2][2|1][2|2]');
    });

    test('reversed bug', () {
      Template template = env.fromString('{% for i in items %}{{ i }}'
          '{% if not loop.last %}'
          ',{% endif %}{% endfor %}');
      expect(
          template.render(<String, Object>{
            'items': <int>[3, 2, 1].reversed
          }),
          '1,2,3');
    });

    test('loop errors', () {
      Template template = env.fromString('''{% for item in [1] if loop.index
                                      == 0 %}...{% endfor %}''');
      expect(() => template.render(), throwsA(isA<UndefinedError>()));
    });

    test('loop filter', () {
      Template template = env.fromString('{% for item in range(10) if item '
          'is even %}[{{ item }}]{% endfor %}');
      expect(template.render(), '[0][2][4][6][8]');
      template = env.fromString('''
            {%- for item in range(10) if item is even %}[{{
                loop.index }}:{{ item }}]{% endfor %}''');
      expect(template.render(), '[1:0][2:2][3:4][4:6][5:8]');
    });

    // TODO: test loop unassignable

    test('scoped special var', () {
      Template template =
          env.fromString('{% for s in seq %}[{{ loop.first }}{% for c in s %}'
              '|{{ loop.first }}{% endfor %}]{% endfor %}');
      expect(
          template.render(<String, Object>{
            'seq': <String>['ab', 'cd']
          }),
          '[true|true|false][false|true|false]');
    });

    test('scoped loop var', () {
      Template template = env.fromString('{% for x in seq %}{{ loop.first }}'
          '{% for y in seq %}{% endfor %}{% endfor %}');
      Map<String, Object> data = <String, Object>{'seq': 'ab'};

      expect(template.render(data), 'truefalse');
      template = env.fromString('{% for x in seq %}{% for y in seq %}'
          '{{ loop.first }}{% endfor %}{% endfor %}');
      expect(template.render(data), 'truefalsetruefalse');
    });

    // TODO: test recursive empty loop iter
    // TODO: test call in loop
    // TODO: test scoping bug

    test('unpacking', () {
      Template template = env.fromString('{% for a, b, c in [[1, 2, 3]] %}'
          '{{ a }}|{{ b }}|{{ c }}{% endfor %}');
      expect(template.render(), '1|2|3');
    });

    test('intended scoping with set', () {
      Template template = env.fromString('{% for item in seq %}{{ x }}'
          '{% set x = item %}{{ x }}{% endfor %}');
      Map<String, Object> data = <String, Object>{
        'x': 0,
        'seq': <int>[1, 2, 3]
      };

      expect(template.render(data), '010203');
      template = env.fromString('{% set x = 9 %}{% for item in seq %}{{ x }}'
          '{% set x = item %}{{ x }}{% endfor %}');
      expect(template.render(data), '919293');
    });
  });
}
