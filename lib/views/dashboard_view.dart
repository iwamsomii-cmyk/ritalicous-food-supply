import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/analysis_service.dart';
import 'app_shell.dart';

class DashboardView extends StatelessWidget {
  final DashboardData? data;
  final List<Sale> sales;
  final List<Expense> expenses;
  final List<Inventory> inventory;
  const DashboardView({super.key, required this.data, required this.sales, required this.expenses, required this.inventory});

  // Distinct color per bar so each number-chip on the axis and each legend
  // dot clearly ties back to the right bar, even when several bars are close
  // in height.
  static const List<Color> _barColors = [
    Color(0xFF205080),
    Color(0xFF2E9E7A),
    Color(0xFFE0A62B),
    Color(0xFFB0453B),
    Color(0xFF6C5DAC),
    Color(0xFF3AA6C2),
  ];

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Center(child: CircularProgressIndicator());
    final d = data!;
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Image.asset('assets/ritalicous_logo.png', height: 90, fit: BoxFit.contain),
          const SizedBox(height: 14),
          // Metric cards laid out horizontally (scrollable strip) instead of
          // stacked one under the other.
          SizedBox(
            height: 112,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _metric('TOTAL REVENUE', d.revenue),
                _metric('OPENING STOCK', d.openingStock),
                _metric('CLOSING STOCK', d.closingStock),
                _metric('TOTAL EXPENSES', d.expenses),
                _metric('1. NET PROFIT', d.netProfit),
                _metric('2. TEMPORARY NET PROFIT', d.temporaryNetProfit, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _section('Financial Metric', Column(children: [
            _row('Total Revenue (Mapato)', d.revenue),
            _row('Opening Stock (Mzigo wa Mwanzo)', d.openingStock),
            _row('Closing Stock (Mzigo wa Mwisho)', d.closingStock),
            _row('Total Expenses (Matumizi)', d.expenses),
            _row('1. Net Profit (Simple)', d.netProfit),
            _row('2. Temporary Net Profit', d.temporaryNetProfit),
          ])),
          const SizedBox(height: 18),
          const Text(
            'TREND & PERCENTAGE ANALYSIS (UCHANTUANIKAJI KWA ASILIAMIA %)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF205080)),
          ),
          const SizedBox(height: 10),
          // Each chart now gets its own full-width row so labels and slices
          // have room to breathe, instead of squeezing bar + pie side by side.
          _chartCard(
            'Financial Metric',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BarChart(
                    BarChartData(
                      barGroups: d.financialMetrics.entries.toList().asMap().entries.map((e) {
                        return BarChartGroupData(x: e.key, barRods: [
                          BarChartRodData(
                            toY: e.value.value,
                            width: 26,
                            color: _barColors[e.key % _barColors.length],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ]);
                      }).toList(),
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50)),
                        bottomTitles: AxisTitles(
                          // Each bar only gets a small numbered "chip" here so
                          // labels never touch or wrap into each other; the
                          // full name for each number is shown in the legend
                          // below the chart instead.
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (v, m) => Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: v.toInt() < d.financialMetrics.length
                                      ? _barColors[v.toInt() % _barColors.length]
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  v.toInt() < d.financialMetrics.length ? '${v.toInt() + 1}' : '',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Legend: number + color swatch + full metric name, wrapping
                // cleanly onto new lines instead of squeezing under the bars.
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: d.financialMetrics.keys.toList().asMap().entries.map((e) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: _barColors[e.key % _barColors.length], shape: BoxShape.circle),
                          child: Text('${e.key + 1}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(width: 5),
                        Text(e.value, style: const TextStyle(fontSize: 11)),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
            height: 400,
          ),
          const SizedBox(height: 16),
          _chartCard(
            'Expense Category',
            PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 34,
                sections: d.expensesByCategory.entries.map((e) {
                  return PieChartSectionData(
                    value: e.value,
                    title: e.key,
                    radius: 100,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
            height: 360,
          ),
          const SizedBox(height: 18),
          _section(
            'Comment Analysis',
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              child: Text(AnalysisService.advice(d), style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, double value, {bool isLast = false}) => Container(
        width: 195,
        margin: EdgeInsets.only(right: isLast ? 0 : 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFD8E5F4), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(money(value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF174A7E))),
          ],
        ),
      );

  Widget _section(String title, Widget child) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFF205080),
              child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            child,
          ],
        ),
      );

  Widget _row(String a, double b) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(children: [
          Expanded(child: Text(a)),
          Text(money(b), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _chartCard(String title, Widget chart, {double height = 300}) => Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(children: [
          Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          const SizedBox(height: 14),
          Expanded(child: chart),
        ]),
      );
}
