import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class LoginSubmitted extends AuthEvent {
  final String login;
  final String password;

  const LoginSubmitted({required this.login, required this.password});

  @override
  List<Object?> get props => [login, password];
}

class ParentRegisterSubmitted extends AuthEvent {
  final String name;
  final String phone;
  final String password;
  final String? email;

  const ParentRegisterSubmitted({
    required this.name,
    required this.phone,
    required this.password,
    this.email,
  });

  @override
  List<Object?> get props => [name, phone, password, email];
}

class ModeSwitchRequested extends AuthEvent {
  final String targetMode; // 'driver' or 'parent'

  const ModeSwitchRequested(this.targetMode);

  @override
  List<Object?> get props => [targetMode];
}

class LogoutRequested extends AuthEvent {}

class SessionExpired extends AuthEvent {
  final int generation;
  const SessionExpired(this.generation);
  @override
  List<Object?> get props => [generation];
}
