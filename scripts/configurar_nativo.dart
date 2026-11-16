// Ajustes nativos que o `flutter create` não faz sozinho.
// Uso (na raiz do projeto):  dart run scripts/configurar_nativo.dart
// - Android: permissões de INTERNET (sem ela o APK release não acessa o
//   Supabase), estado da rede e câmera; nome "CEI" no celular.
// - iOS: texto de permissão da câmera.
import 'dart:io';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    var texto = manifest.readAsStringSync();
    const permissoes = [
      '<uses-permission android:name="android.permission.INTERNET"/>',
      '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>',
      '<uses-permission android:name="android.permission.CAMERA"/>',
    ];
    for (final p in permissoes) {
      if (!texto.contains(p)) {
        texto = texto.replaceFirst('<application', '$p\n    <application');
      }
    }
    texto = texto.replaceFirst('android:label="cei_mobile"', 'android:label="CEI"');
    manifest.writeAsStringSync(texto);
    stdout.writeln('AndroidManifest.xml atualizado.');
  } else {
    stdout.writeln('Pasta android/ não encontrada. Rode antes: flutter create .');
  }

  final plist = File('ios/Runner/Info.plist');
  if (plist.existsSync()) {
    final texto = plist.readAsStringSync();
    if (!texto.contains('NSCameraUsageDescription')) {
      plist.writeAsStringSync(
        texto.replaceFirst(
          '<dict>',
          '<dict>\n\t<key>NSCameraUsageDescription</key>\n'
              '\t<string>Usada para ler códigos de barras dos produtos.</string>',
        ),
      );
      stdout.writeln('Info.plist atualizado.');
    }
  }
}
