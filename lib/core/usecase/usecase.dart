import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../errors/failures.dart';

/// کلاس پایهٔ مشترک برای تمام UseCase ها (طبق بخش ۲۴.۴ سند: core/usecase/).
///
/// هر UseCase یک عملیات واحد را orchestrate می‌کند (مثلاً LoginUseCase،
/// GetGradeMapUseCase) و هیچ منطق UI در آن نیست — فقط فراخوانی Repository.
abstract class UseCase<TResult, Params> {
  Future<Either<Failure, TResult>> call(Params params);
}

/// برای UseCase هایی که ورودی ندارند (مثلاً GetCurrentUserUseCase).
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
