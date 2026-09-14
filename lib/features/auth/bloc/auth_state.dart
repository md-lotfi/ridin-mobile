import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final Map<String, dynamic> user;
  final String activeMode; // 'driver' or 'parent'

  const Authenticated({required this.user, required this.activeMode});

  @override
  List<Object?> get props => [user, activeMode];
}

class Unauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String error;

  const AuthFailure(this.error);

  @override
  List<Object?> get props => [error];
}
