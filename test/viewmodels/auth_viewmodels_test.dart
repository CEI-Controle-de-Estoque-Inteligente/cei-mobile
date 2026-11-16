import 'package:cei_mobile/core/errors/app_exception.dart';
import 'package:cei_mobile/data/local/preferences_service.dart';
import 'package:cei_mobile/features/auth/viewmodels/login_viewmodel.dart';
import 'package:cei_mobile/features/auth/viewmodels/session_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  late PreferencesService prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
  });

  group('LoginViewModel', () {
    test('expõe mensagem amigável quando as credenciais são inválidas', () async {
      final repo = FakeAuthRepository(erroLogin: const AuthAppException('E-mail ou senha incorretos.'));
      final vm = LoginViewModel(repo);

      final ok = await vm.submit(email: 'a@b.com', password: '12345678');

      expect(ok, isFalse);
      expect(vm.errorMessage, 'E-mail ou senha incorretos.');
      expect(vm.isLoading, isFalse);
    });

    test('login válido retorna sucesso', () async {
      final vm = LoginViewModel(FakeAuthRepository(perfil: perfilFake()));
      expect(await vm.submit(email: 'a@b.com', password: '12345678'), isTrue);
      expect(vm.errorMessage, isNull);
    });
  });

  group('SessionViewModel', () {
    test('sem sessão salva inicia deslogado', () {
      final session = SessionViewModel(FakeAuthRepository(), prefs)..start();
      expect(session.status, SessionStatus.deslogado);
      session.dispose();
    });

    test('após login carrega o perfil e aplica permissões do cargo', () async {
      final repo = FakeAuthRepository(perfil: perfilFake());
      final session = SessionViewModel(repo, prefs)..start();

      await repo.entrar(email: 'maria@cei.com', senha: '12345678');
      await pumpEventQueue();

      expect(session.status, SessionStatus.logado);
      expect(session.perfil?.nome, 'Maria Souza');
      expect(prefs.readPerfilCache()?['id'], 'u1');
      session.dispose();
    });

    test('usuário desativado pelo gerente é deslogado com aviso', () async {
      final repo = FakeAuthRepository(perfil: perfilFake(ativo: false));
      final session = SessionViewModel(repo, prefs)..start();

      await repo.entrar(email: 'maria@cei.com', senha: '12345678');
      await pumpEventQueue();

      expect(session.status, SessionStatus.deslogado);
      expect(session.consumirAviso(), contains('desativado'));
      session.dispose();
    });

    test('logout limpa os dados locais e o cache do perfil', () async {
      var limpou = false;
      final repo = FakeAuthRepository(perfil: perfilFake());
      final session = SessionViewModel(repo, prefs, limparDadosLocais: () async => limpou = true)..start();
      await repo.entrar(email: 'maria@cei.com', senha: '12345678');
      await pumpEventQueue();

      await session.sair();

      expect(limpou, isTrue);
      expect(prefs.readPerfilCache(), isNull);
      expect(session.status, SessionStatus.deslogado);
      session.dispose();
    });
  });
}
