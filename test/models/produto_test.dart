import 'package:cei_mobile/data/models/produto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  final hoje = DateTime(2026, 10, 26);

  group('StockStatus (mesma regra da coluna gerada no banco)', () {
    test('zerado ou até metade do mínimo é crítico', () {
      expect(StockStatus.calcular(quantidade: 0, minimo: 0), StockStatus.critico);
      expect(StockStatus.calcular(quantidade: 5, minimo: 10), StockStatus.critico);
    });

    test('até o mínimo é baixo, até 1,5x é atenção, acima é ok', () {
      expect(StockStatus.calcular(quantidade: 10, minimo: 10), StockStatus.baixo);
      expect(StockStatus.calcular(quantidade: 15, minimo: 10), StockStatus.atencao);
      expect(StockStatus.calcular(quantidade: 16, minimo: 10), StockStatus.ok);
    });
  });

  group('Validade', () {
    test('faixas de alerta 30 / 15 / 5 dias e vencido', () {
      expect(produtoFake(validade: hoje.add(const Duration(days: 40))).alertaValidade(hoje), isNull);
      expect(produtoFake(validade: hoje.add(const Duration(days: 30))).alertaValidade(hoje), AlertaValidade.medio);
      expect(produtoFake(validade: hoje.add(const Duration(days: 15))).alertaValidade(hoje), AlertaValidade.alto);
      expect(produtoFake(validade: hoje.add(const Duration(days: 5))).alertaValidade(hoje), AlertaValidade.critico);
      expect(produtoFake(validade: hoje.subtract(const Duration(days: 1))).alertaValidade(hoje), AlertaValidade.vencido);
    });

    test('sugere desconto só com menos de 7 dias e estoque disponível', () {
      expect(produtoFake(validade: hoje.add(const Duration(days: 7))).descontoSugerido(hoje: hoje), isNull);
      expect(produtoFake(validade: hoje.add(const Duration(days: 6))).descontoSugerido(hoje: hoje), 10);
      expect(produtoFake(validade: hoje.add(const Duration(days: 4))).descontoSugerido(hoje: hoje), 20);
      expect(produtoFake(validade: hoje.add(const Duration(days: 2))).descontoSugerido(hoje: hoje), 30);
      expect(produtoFake(validade: hoje.add(const Duration(days: 1))).descontoSugerido(hoje: hoje), 50);
      expect(produtoFake(quantidade: 0, validade: hoje.add(const Duration(days: 1))).descontoSugerido(hoje: hoje), isNull);
      expect(produtoFake(validade: hoje.subtract(const Duration(days: 1))).descontoSugerido(hoje: hoje), isNull);
    });
  });

  test('nível da barra usa a capacidade máxima e fica entre 0 e 1', () {
    expect(produtoFake(quantidade: 10, maximo: 20).nivel, 0.5);
    expect(produtoFake(quantidade: 50, maximo: 20).nivel, 1);
    expect(produtoFake(quantidade: 5, minimo: 5, maximo: 0).nivel, 0.5);
  });

  group('DTO', () {
    test('fromJson trata números como texto, nulos e datas', () {
      final p = Produto.fromJson({
        'id': 'p1',
        'empresa_id': 'e1',
        'nome': 'Arroz',
        'preco': '27.90',
        'quantidade': 3,
        'estoque_minimo': null,
        'estoque_maximo': 10,
        'validade': '2026-12-01',
        'categoria': null,
      });
      expect(p.preco, 27.9);
      expect(p.estoqueMinimo, 0);
      expect(p.validade, DateTime(2026, 12, 1));
      expect(p.categoria, isNull);
    });

    test('toMap/fromMap preservam os dados (banco local)', () {
      final original = produtoFake(validade: DateTime(2027, 1, 15));
      final copia = Produto.fromMap(original.toMap());
      expect(copia.id, original.id);
      expect(copia.validade, original.validade);
      expect(copia.quantidade, original.quantidade);
      expect(copia.ativo, isTrue);
    });

    test('toJson envia quantidade só no cadastro e data sem horário', () {
      final p = produtoFake(validade: DateTime(2027, 3, 9));
      expect(p.toJson().containsKey('quantidade'), isFalse);
      expect(p.toJson(incluirQuantidade: true)['quantidade'], 10);
      expect(p.toJson()['validade'], '2027-03-09');
    });
  });
}
