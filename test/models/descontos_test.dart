import 'package:cei_mobile/data/models/empresa.dart';
import 'package:cei_mobile/data/models/produto.dart';
import 'package:cei_mobile/data/models/tabela_descontos.dart';
import 'package:cei_mobile/features/dashboard/viewmodels/dashboard_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  final hoje = DateTime(2026, 11, 17);
  DateTime em(int dias) => hoje.add(Duration(days: dias));

  group('TabelaDescontos', () {
    const tabela = TabelaDescontos(ate1Dia: 40, ate3Dias: 25, ate5Dias: 15, ate6Dias: 0);

    test('escolhe a faixa pelos dias até vencer', () {
      expect(tabela.percentualPara(0), 40);
      expect(tabela.percentualPara(1), 40);
      expect(tabela.percentualPara(3), 25);
      expect(tabela.percentualPara(5), 15);
    });

    test('faixa zerada, vencido ou 7+ dias não sugere', () {
      expect(tabela.percentualPara(6), isNull);
      expect(tabela.percentualPara(7), isNull);
      expect(tabela.percentualPara(-1), isNull);
    });

    test('lê as colunas da empresa e usa o padrão quando faltam', () {
      final empresa = Empresa.fromJson({'id': 'e1', 'nome': 'Loja', 'desconto_1d': 35});
      expect(empresa.descontos.ate1Dia, 35);
      expect(empresa.descontos.ate3Dias, TabelaDescontos.padrao.ate3Dias);
      expect(Empresa.fromJson(empresa.toJson()).descontos, empresa.descontos);
    });
  });

  group('Produto com promoção', () {
    test('sugestão segue a tabela do gerente', () {
      const tabela = TabelaDescontos(ate1Dia: 40, ate3Dias: 25, ate5Dias: 15, ate6Dias: 5);
      expect(produtoFake(validade: em(2)).descontoSugerido(tabela: tabela, hoje: hoje), 25);
      expect(produtoFake(validade: em(6)).descontoSugerido(tabela: tabela, hoje: hoje), 5);
    });

    test('produto já em promoção não recebe nova sugestão', () {
      expect(produtoFake(validade: em(1), promocao: 30).descontoSugerido(hoje: hoje), isNull);
    });

    test('venda usa o preço promocional', () {
      final p = produtoFake(preco: 19.90, promocao: 30);
      expect(p.emPromocao, isTrue);
      expect(p.precoVenda, 13.93);
      expect(produtoFake(preco: 19.90).precoVenda, 19.90);
    });

    test('preço com desconto arredonda em centavos como o banco', () {
      expect(produtoFake(preco: 5.49).precoComDesconto(30), 3.84);
      expect(produtoFake(preco: 10).precoComDesconto(25), 7.5);
    });

    test('promoção vem do Supabase e vai para o banco local', () {
      final p = Produto.fromJson({
        'id': 'p1',
        'empresa_id': 'e1',
        'nome': 'Leite',
        'preco': 5.49,
        'quantidade': 10,
        'estoque_minimo': 2,
        'estoque_maximo': 20,
        'promocao_percentual': 30,
        'preco_promocional': '3.84',
      });
      expect(p.precoVenda, 3.84);
      final local = Produto.fromMap(p.toMap());
      expect(local.promocaoPercentual, 30);
      expect(local.precoPromocional, 3.84);
      expect(p.toJson().containsKey('preco_promocional'), isFalse, reason: 'promoção só muda pela RPC');
    });
  });

  test('recomendações não sugerem desconto para quem já está em promoção', () {
    final amanha = DateTime.now().add(const Duration(days: 1));
    final recs = gerarRecomendacoes(
      criticos: const [],
      vencendo: [
        produtoFake(id: 'promo', validade: amanha, promocao: 20),
        produtoFake(id: 'sem', validade: amanha),
      ],
      tabela: const TabelaDescontos(ate1Dia: 35, ate3Dias: 20, ate5Dias: 10, ate6Dias: 5),
    );
    expect(recs.map((r) => r.produtoId), ['sem']);
    expect(recs.single.titulo, contains('35%'));
  });
}
