import 'package:flutter/material.dart';

enum WorkType {
  fertilization('fertilization', '施肥', Color(0xFFB85C00), Icons.grass),
  tillage('tillage', '耕うん', Color(0xFF7A4525), Icons.agriculture),
  pesticide('pesticide', '農薬', Color(0xFF5A2D82), Icons.science),
  harvest('harvest', '収穫', Color(0xFFB8860B), Icons.eco),
  other('other', 'その他', Color(0xFF6B7E68), Icons.more_horiz);

  const WorkType(this.value, this.label, this.color, this.icon);

  final String value;
  final String label;
  final Color color;
  final IconData icon;

  static WorkType fromValue(String value) {
    return WorkType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => WorkType.other,
    );
  }
}

class WorkLogEntry {
  const WorkLogEntry({
    required this.workType,
    required this.workDate,
    this.title,
    this.detail,
    this.amountValue,
    this.amountUnit,
    this.scope = 'whole',
  });

  final String workType;
  final String workDate;
  final String? title;
  final String? detail;
  final double? amountValue;
  final String? amountUnit;
  final String scope;

  Map<String, dynamic> toJson() {
    return {
      'work_type': workType,
      'work_date': workDate,
      if (title != null && title!.isNotEmpty) 'title': title,
      if (detail != null && detail!.isNotEmpty) 'detail': detail,
      if (amountValue != null) 'amount_value': amountValue,
      if (amountUnit != null && amountUnit!.isNotEmpty)
        'amount_unit': amountUnit,
      'scope': scope,
    };
  }

  factory WorkLogEntry.fromJson(Map<String, dynamic> json) {
    return WorkLogEntry(
      workType: json['work_type'] as String,
      workDate: json['work_date'] as String,
      title: json['title'] as String?,
      detail: json['detail'] as String?,
      amountValue: (json['amount_value'] as num?)?.toDouble(),
      amountUnit: json['amount_unit'] as String?,
      scope: (json['scope'] as String?) ?? 'whole',
    );
  }
}

const titlePresets = <WorkType, List<String>>{
  WorkType.fertilization: ['NK化成', '石灰窒素', '有機肥料', '苦土石灰', '堆肥'],
  WorkType.tillage: ['深起こし', '浅起こし', 'ロータリー', 'トラクター'],
  WorkType.pesticide: ['除草剤', '殺虫剤', '殺菌剤'],
  WorkType.harvest: ['収穫'],
  WorkType.other: [],
};

const unitPresets = ['kg', 'L', '袋', 'cm', 'mm'];
