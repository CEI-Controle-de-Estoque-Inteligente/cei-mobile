import 'package:cei_mobile/core/router/app_routes.dart';
import 'package:cei_mobile/data/models/dashboard_resumo.dart';
import 'package:cei_mobile/data/models/perfil.dart';
import 'package:cei_mobile/data/models/venda.dart';
import 'package:cei_mobile/data/repositories/assistente_service.dart';
import 'package:cei_mobile/features/dashboard/viewmodels/dashboard_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  group('RBAC - permissões por cargo', () {
    test('somente o gerente acessa a equipe e as vendas de todos', () {
      expect(Cargo.gerente.permite(Modulo.equipe), isTrue);
      expect(Cargo.gerente.permite(Modulo.vendasTodas), isTrue);
      for (final c in [Cargo.vendedor, Cargo.caixa, Cargo.estoquista]) {
        expect(c.permite(Modulo.equipe), isFalse, reason: c.label);
        expect(c.permite(Modulo.vendasTodas), isFalse, reason: c.label);
      }
    });

    test('estoquista edita estoque mas não vende; vendedor vende mas não edita', () {
      expect(Cargo.estoquista.permite(Modulo.estoqueEditar), isTrue);
      expect(Cargo.estoquista.permite(Modulo.vendas), isFalse);
      expect(Cargo.vendedor.permite(Modulo.vendas), isTrue);
      expect(Cargo.vendedor.permite(Modulo.estoqueEditar), isFalse);
      expect(Cargo.estoquista.permite(Modulo.estoqueExcluir), isFalse);
    });

    test('rotas exigem o módulo correto', () {
      expect(AppRoutes.moduloDe(AppRoutes.equipe), Modulo.equipe);
      expect(AppRoutes.moduloDe(AppRoutes.produtoNovo), Modulo.estoqueEditar);
      expect(AppRoutes.moduloDe(AppRoutes.produtoMovimentar('x')), Modulo.estoqueEditar);
      expect(AppRoutes.moduloDe(AppRoutes.produto('x')), Modulo.estoque);
      expect(AppRoutes.moduloDe(AppRoutes.vendaNova), Modulo.vendas);
      expect(AppRoutes.moduloDe(AppRoutes.perfil), isNull);
    });
  });

  group('Vendas', () {
    test('ticket médio = total / número de transações', () {
      Venda venda(double total) => Venda(
        id: '$total',
        produtoNome: 'x',
        quantidade: 1,
        precoUnitario: total,
        total: total,
        criadaEm: DateTime(2026),
      );
      final resumo = ResumoVendas.calcular([venda(10), venda(20), venda(30)]);
      expect(resumo.total, 60);
      expect(resumo.transacoes, 3);
      expect(resumo.ticketMedio, 20);
      expect(ResumoVendas.calcular([]).ticketMedio, 0);
    });

    test('período "7 dias" inclui hoje e os 6 dias anteriores', () {
      final i = IntervaloDatas.de(PeriodoVendas.semana, agora: DateTime(2026, 10, 26, 15));
      expect(i.inicio, DateTime(2026, 10, 20));
      expect(i.fim, DateTime(2026, 10, 27));
    });
  });

  test('variação do faturamento em relação a ontem', () {
    DashboardResumo resumo(double hoje, double ontem) => DashboardResumo(
      faturamentoHoje: hoje,
      faturamentoOntem: ontem,
      vendasHoje: 1,
      produtosAtivos: 1,
      itensEstoque: 1,
      itensCriticos: 0,
      vencendo15: 0,
      vencidos: 0,
    );
    expect(resumo(150, 100).variacaoFaturamento, 50);
    expect(resumo(50, 100).variacaoFaturamento, -50);
    expect(resumo(50, 0).variacaoFaturamento, isNull);
  });

  test('recomendações: desconto para quem vence e reposição para críticos', () {
    final amanha = DateTime.now().add(const Duration(days: 1));
    final recs = gerarRecomendacoes(
      criticos: [produtoFake(id: 'c', quantidade: 1, minimo: 10, maximo: 30)],
      vencendo: [produtoFake(id: 'v', validade: amanha)],
    );
    expect(recs.map((r) => r.tipo), [TipoRecomendacao.desconto, TipoRecomendacao.repor]);
    expect(recs.last.detalhe, contains('comprar 29 un.'));
  });

  group('Assistente - classificação das perguntas', () {
    test('entende as consultas da especificação', () {
      expect(AssistenteService.classificar('O que está faltando no estoque?'), IntencaoAssistente.faltando);
      expect(AssistenteService.classificar('Quais produtos vão vencer essa semana?'), IntencaoAssistente.vencendo);
      expect(AssistenteService.classificar('Qual foi o resumo de vendas de hoje?'), IntencaoAssistente.resumoVendas);
      expect(AssistenteService.classificar('Sugerir desconto para girar produto?'), IntencaoAssistente.desconto);
      expect(AssistenteService.classificar('O que devo comprar?'), IntencaoAssistente.compras);
      expect(AssistenteService.classificar('quanto tem de arroz?'), IntencaoAssistente.consultaProduto);
      expect(AssistenteService.classificar('bom dia'), IntencaoAssistente.ajuda);
    });

    test('normaliza acentos e maiúsculas', () {
      expect(AssistenteService.normalizar('PROMOÇÃO Válida'), 'promocao valida');
    });
  });

  test('sugestão de compra cobre 30 dias de giro + mínimo', () {
    const giro = GiroProduto(
      produtoId: 'p',
      nome: 'Leite',
      quantidade: 10,
      estoqueMinimo: 5,
      vendido: 60,
      mediaDiaria: 2,
      diasCobertura: 5,
    );
    expect(giro.sugestaoCompra, 55);
  });
}
