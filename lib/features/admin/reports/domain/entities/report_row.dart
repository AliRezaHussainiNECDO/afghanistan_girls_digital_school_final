import 'package:equatable/equatable.dart';

/// طبق بخش ۱۵.۳ سند.
class ReportRow extends Equatable {
  final String label;
  final String value;
  const ReportRow({required this.label, required this.value});
  @override
  List<Object?> get props => [label];
}
