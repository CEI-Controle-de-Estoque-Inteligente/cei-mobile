import 'package:flutter/material.dart';

/// Avatar com as iniciais do usuário.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.iniciais, this.radius = 22, this.nome});

  final String iniciais;
  final double radius;
  final String? nome;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: nome == null ? 'Avatar' : 'Avatar de $nome',
      excludeSemantics: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        child: Text(
          iniciais,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.75),
        ),
      ),
    );
  }
}
