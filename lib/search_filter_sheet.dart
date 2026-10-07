// lib/search_filter_sheet.dart
import 'package:flutter/material.dart';

import 'models/post_search_filters.dart';

/// Opens a bottom sheet for structured search (class, subject, area, and
/// optionally a fee range) and returns the chosen filters, or null if the
/// user dismissed it without applying.
Future<PostSearchFilters?> showSearchFilterSheet(
    BuildContext context, {
      required PostSearchFilters initial,
      bool includeFee = false,
    }) {
  return showModalBottomSheet<PostSearchFilters>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _SearchFilterSheet(initial: initial, includeFee: includeFee),
  );
}

class _SearchFilterSheet extends StatefulWidget {
  final PostSearchFilters initial;
  final bool includeFee;

  const _SearchFilterSheet({required this.initial, required this.includeFee});

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late final TextEditingController _classController =
  TextEditingController(text: widget.initial.className);
  late final TextEditingController _subjectController =
  TextEditingController(text: widget.initial.subject);
  late final TextEditingController _areaController =
  TextEditingController(text: widget.initial.area);
  late final TextEditingController _minFeeController =
  TextEditingController(text: widget.initial.minFee?.toStringAsFixed(0) ?? '');
  late final TextEditingController _maxFeeController =
  TextEditingController(text: widget.initial.maxFee?.toStringAsFixed(0) ?? '');

  String? _feeError;

  @override
  void dispose() {
    _classController.dispose();
    _subjectController.dispose();
    _areaController.dispose();
    _minFeeController.dispose();
    _maxFeeController.dispose();
    super.dispose();
  }

  void _clear() {
    _classController.clear();
    _subjectController.clear();
    _areaController.clear();
    _minFeeController.clear();
    _maxFeeController.clear();
    setState(() => _feeError = null);
  }

  void _apply() {
    double? minFee;
    double? maxFee;

    if (widget.includeFee) {
      if (_minFeeController.text.trim().isNotEmpty) {
        minFee = double.tryParse(_minFeeController.text.trim());
        if (minFee == null) {
          setState(() => _feeError = 'Enter a valid minimum fee');
          return;
        }
      }
      if (_maxFeeController.text.trim().isNotEmpty) {
        maxFee = double.tryParse(_maxFeeController.text.trim());
        if (maxFee == null) {
          setState(() => _feeError = 'Enter a valid maximum fee');
          return;
        }
      }
      if (minFee != null && maxFee != null && minFee > maxFee) {
        setState(() => _feeError = 'Minimum fee cannot be greater than maximum');
        return;
      }
    }

    Navigator.pop(
      context,
      PostSearchFilters(
        className: _classController.text.trim(),
        subject: _subjectController.text.trim(),
        area: _areaController.text.trim(),
        minFee: minFee,
        maxFee: maxFee,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Search Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(onPressed: _clear, child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _classController,
              decoration: const InputDecoration(
                labelText: 'Class',
                hintText: 'e.g. Class 9 - 10',
                prefixIcon: Icon(Icons.school_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Physics',
                prefixIcon: Icon(Icons.book_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _areaController,
              decoration: const InputDecoration(
                labelText: 'Area',
                hintText: 'e.g. Mirpur',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.includeFee) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minFeeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min Fee',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxFeeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Fee',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_feeError != null) ...[
                const SizedBox(height: 8),
                Text(_feeError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff1E88E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Apply Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
