// employees_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class AttendanceRecord {
  final String status; // 'Present', 'Absent', 'Half Day'
  final String note;

  AttendanceRecord({required this.status, required this.note});

  Map<String, dynamic> toJson() => {
        'status': status,
        'note': note,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        status: json['status'] ?? 'Present',
        note: json['note'] ?? '',
      );
}

class Employee {
  final int id;
  String name;
  String role;
  String paymentType; // 'Daily' or 'Monthly'
  double rate; // Daily wage or monthly salary
  Map<String, AttendanceRecord> attendance; // Key: "yyyy-MM-dd"
  List<String> paidMonths; // Key: "yyyy-MM"
  DateTime? joiningDate;

  Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.paymentType,
    required this.rate,
    Map<String, AttendanceRecord>? attendance,
    List<String>? paidMonths,
    this.joiningDate,
  })  : attendance = attendance ?? {},
        paidMonths = paidMonths ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'paymentType': paymentType,
        'rate': rate,
        'attendance': attendance.map((k, v) => MapEntry(k, v.toJson())),
        'paidMonths': paidMonths,
        'joiningDate': joiningDate?.toIso8601String(),
      };

  factory Employee.fromJson(Map<String, dynamic> json) {
    var rawAttendance = json['attendance'] as Map<String, dynamic>? ?? {};
    Map<String, AttendanceRecord> parsedAttendance = rawAttendance.map(
      (k, v) => MapEntry(
        k,
        AttendanceRecord.fromJson(v as Map<String, dynamic>),
      ),
    );

    List<String> parsedPaidMonths = [];
    if (json['paidMonths'] != null) {
      parsedPaidMonths = List<String>.from(json['paidMonths']);
    }

    return Employee(
      id: json['id'],
      name: json['name'],
      role: json['role'] ?? 'Worker',
      paymentType: json['paymentType'] ?? 'Daily',
      rate: (json['rate'] ?? 0.0).toDouble(),
      attendance: parsedAttendance,
      paidMonths: parsedPaidMonths,
      joiningDate: json['joiningDate'] != null
          ? DateTime.tryParse(json['joiningDate'])
          : null,
    );
  }
}

// ─── Main Employees Page Widget ──────────────────────────────────────────────

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  List<Employee> _employees = [];
  bool _loading = true;
  Employee? _selectedEmployee;

  // Calendar State
  DateTime? _selectedDate;
  DateTime? _selectedPeriodStart;
  DateTime? _selectedPeriodEnd;

  // Controllers for Add/Edit Employee form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  String _selectedPaymentType = 'Daily';

  // Controller for Attendance Note
  final TextEditingController _noteController = TextEditingController();
  String _selectedStatus = 'Present';

  String _calculateTenure(DateTime joiningDate) {
    final now = DateTime.now();
    if (now.isBefore(joiningDate)) {
      return 'Joined in future';
    }

    int years = now.year - joiningDate.year;
    int months = now.month - joiningDate.month;
    int days = now.day - joiningDate.day;

    if (days < 0) {
      months -= 1;
      // get days in previous month
      final prevMonth = DateTime(now.year, now.month, 0);
      days += prevMonth.day;
    }

    if (months < 0) {
      years -= 1;
      months += 12;
    }

    List<String> parts = [];
    if (years > 0) {
      parts.add('$years ${years == 1 ? "yr" : "yrs"}');
    }
    if (months > 0) {
      parts.add('$months ${months == 1 ? "mo" : "mos"}');
    }
    if (days > 0 || parts.isEmpty) {
      parts.add('$days ${days == 1 ? "day" : "days"}');
    }

    return parts.join(', ');
  }

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _rateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Load employees from SharedPreferences
  Future<void> _loadEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('employees_list');
    if (data != null) {
      try {
        final List decoded = json.decode(data);
        setState(() {
          _employees = decoded.map((e) => Employee.fromJson(e)).toList();
          _loading = false;
        });
      } catch (e) {
        debugPrint('Error loading employees: $e');
        setState(() => _loading = false);
      }
    } else {
      setState(() => _loading = false);
    }
  }

  // Save employees to SharedPreferences
  Future<void> _saveEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = json.encode(_employees.map((e) => e.toJson()).toList());
    await prefs.setString('employees_list', data);
    setState(() {});
  }

  // Helper for dialog fields reset
  void _clearForm() {
    _nameController.clear();
    _roleController.clear();
    _rateController.clear();
    _selectedPaymentType = 'Daily';
  }

  // Show dialog to Add or Edit Employee
  void _openEmployeeForm({Employee? existing}) {
    DateTime? tempJoiningDate;
    if (existing != null) {
      _nameController.text = existing.name;
      _roleController.text = existing.role;
      _rateController.text = existing.rate.toString();
      _selectedPaymentType = existing.paymentType;
      tempJoiningDate = existing.joiningDate;
    } else {
      _clearForm();
      tempJoiningDate = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                existing == null ? 'Add New Employee' : 'Edit Employee Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Employee Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _roleController,
                      decoration: const InputDecoration(
                        labelText: 'Role (e.g. Designer, Helper)',
                        prefixIcon: Icon(Icons.work),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPaymentType,
                      decoration: const InputDecoration(
                        labelText: 'Payment Frequency',
                        prefixIcon: Icon(Icons.payment),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      items: ['Daily', 'Monthly'].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            _selectedPaymentType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _rateController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _selectedPaymentType == 'Daily'
                            ? 'Daily Wage (₹)'
                            : 'Monthly Salary (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tempJoiningDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            tempJoiningDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Joining Date',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        child: Text(
                          tempJoiningDate == null
                              ? 'Select Date'
                              : DateFormat('dd MMM yyyy').format(tempJoiningDate!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _clearForm();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    final role = _roleController.text.trim();
                    final rate = double.tryParse(_rateController.text) ?? 0.0;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter name')),
                      );
                      return;
                    }

                    setState(() {
                      if (existing != null) {
                        existing.name = name;
                        existing.role = role.isEmpty ? 'Worker' : role;
                        existing.paymentType = _selectedPaymentType;
                        existing.rate = rate;
                        existing.joiningDate = tempJoiningDate;
                        if (_selectedEmployee?.id == existing.id) {
                          final periods = _getBillingPeriods(existing);
                          final currentPeriodIndex = _getCurrentPeriodIndex(periods);
                          _selectedPeriodStart = periods[currentPeriodIndex]['startDate'];
                          _selectedPeriodEnd = periods[currentPeriodIndex]['endDate'];
                        }
                      } else {
                        _employees.add(
                          Employee(
                            id: DateTime.now().millisecondsSinceEpoch,
                            name: name,
                            role: role.isEmpty ? 'Worker' : role,
                            paymentType: _selectedPaymentType,
                            rate: rate,
                            joiningDate: tempJoiningDate,
                          ),
                        );
                      }
                    });

                    _saveEmployees();
                    _clearForm();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.blue.shade800
                        : const Color(0xFF1d6f96),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(existing == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delete Employee Confirmation
  Future<void> _deleteEmployee(Employee emp) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee?'),
        content: Text(
          'Are you sure you want to permanently delete employee "${emp.name}"? This will delete all their attendance records and history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _employees.removeWhere((e) => e.id == emp.id);
        if (_selectedEmployee?.id == emp.id) {
          _selectedEmployee = null;
        }
      });
      _saveEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Employee "${emp.name}" removed.')),
        );
      }
    }
  }

  // Days in month calculator
  int _daysInMonth(DateTime date) {
    var firstDayOfNextMonth = DateTime(date.year, date.month + 1, 1);
    var lastDayOfThisMonth =
        firstDayOfNextMonth.subtract(const Duration(days: 1));
    return lastDayOfThisMonth.day;
  }

  // Calculate stats for payroll
  Map<String, dynamic> _calculatePayrollStats(
      Employee emp, DateTime startDate, DateTime endDate) {
    bool notJoinedYet = false;
    final joiningDate = emp.joiningDate;
    if (joiningDate != null) {
      if (startDate.isBefore(joiningDate)) {
        notJoinedYet = true;
      }
    }

    double presentCount = 0.0;
    int halfDayCount = 0;
    int absentCount = 0;

    if (!notJoinedYet) {
      emp.attendance.forEach((dateStr, record) {
        try {
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final rYear = int.parse(parts[0]);
            final rMonth = int.parse(parts[1]);
            final rDay = int.parse(parts[2]);
            final recordDate = DateTime(rYear, rMonth, rDay);
            
            if ((recordDate.isAfter(startDate) || recordDate.isAtSameMomentAs(startDate)) &&
                (recordDate.isBefore(endDate) || recordDate.isAtSameMomentAs(endDate))) {
              if (record.status == 'Present') {
                presentCount += 1.0;
              } else if (record.status == 'Half Day') {
                presentCount += 0.5;
                halfDayCount++;
              } else if (record.status == 'Absent') {
                absentCount++;
              }
            }
          }
        } catch (_) {}
      });
    }

    final totalDaysInPeriod = endDate.difference(startDate).inDays + 1;

    double calculatedSalary = 0.0;
    if (!notJoinedYet) {
      if (emp.paymentType == 'Daily') {
        calculatedSalary = presentCount * emp.rate;
      } else {
        // Monthly Salary: Rate * (presentCount / total days in the period)
        calculatedSalary = (presentCount / totalDaysInPeriod) * emp.rate;
      }
    }

    final monthKey = DateFormat('yyyy-MM').format(startDate);
    bool isPaid = emp.paidMonths.contains(monthKey);

    return {
      'present': presentCount,
      'halfDay': halfDayCount,
      'absent': absentCount,
      'daysInMonth': totalDaysInPeriod,
      'salary': calculatedSalary,
      'isPaid': isPaid,
      'monthKey': monthKey,
      'startDate': startDate,
      'endDate': endDate,
      'notJoinedYet': notJoinedYet,
    };
  }

  // Generate billing periods starting from employee's joining date to now + 3 months
  List<Map<String, dynamic>> _getBillingPeriods(Employee emp) {
    final List<Map<String, dynamic>> periods = [];
    final joinDate = emp.joiningDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    
    final now = DateTime.now();
    final startYear = joinDate.year;
    final startMonth = joinDate.month;
    
    final currentYear = now.year;
    final currentMonth = now.month;
    
    // We want to generate periods up to 3 months in the future to allow planning/looking ahead
    int totalPeriods = (currentYear - startYear) * 12 + (currentMonth - startMonth) + 3;
    if (totalPeriods < 3) {
      totalPeriods = 3;
    }
    
    for (int i = 0; i < totalPeriods; i++) {
      final startDay = joinDate.day;
      
      int pMonth = startMonth + i;
      int pYear = startYear;
      while (pMonth > 12) {
        pMonth -= 12;
        pYear += 1;
      }
      
      // Calculate startDate for period i
      final daysInPMonth = _daysInMonth(DateTime(pYear, pMonth));
      final actualStartDay = startDay > daysInPMonth ? daysInPMonth : startDay;
      final startDate = DateTime(pYear, pMonth, actualStartDay);
      
      // Calculate next month cycle startDate to find endDate of period i
      int nextPMonth = pMonth + 1;
      int nextPYear = pYear;
      if (nextPMonth > 12) {
        nextPMonth = 1;
        nextPYear += 1;
      }
      final daysInNextPMonth = _daysInMonth(DateTime(nextPYear, nextPMonth));
      final actualNextStartDay = startDay > daysInNextPMonth ? daysInNextPMonth : startDay;
      final nextStartDate = DateTime(nextPYear, nextPMonth, actualNextStartDay);
      final endDate = nextStartDate.subtract(const Duration(days: 1));
      
      periods.add({
        'startDate': startDate,
        'endDate': endDate,
        'label': "${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}",
      });
    }
    
    return periods.reversed.toList();
  }

  // Find index of the billing period that contains today
  int _getCurrentPeriodIndex(List<Map<String, dynamic>> periods) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (int i = 0; i < periods.length; i++) {
      final start = periods[i]['startDate'] as DateTime;
      final end = periods[i]['endDate'] as DateTime;
      if ((today.isAfter(start) || today.isAtSameMomentAs(start)) &&
          (today.isBefore(end) || today.isAtSameMomentAs(end))) {
        return i;
      }
    }
    return 0; // fallback to the newest period
  }

  // Toggle salary paid/unpaid status
  void _togglePaidStatus(Employee emp, String monthKey) {
    setState(() {
      if (emp.paidMonths.contains(monthKey)) {
        emp.paidMonths.remove(monthKey);
      } else {
        emp.paidMonths.add(monthKey);
      }
    });
    _saveEmployees();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_selectedEmployee != null) {
      return _buildEmployeeDetailsView(_selectedEmployee!);
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                  itemCount: _employees.length,
                  itemBuilder: (context, idx) {
                    final emp = _employees[idx];
                    return Card(
                      elevation: isDark ? 1 : 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _selectedEmployee = emp;
                            final periods = _getBillingPeriods(emp);
                            final currentPeriodIndex = _getCurrentPeriodIndex(periods);
                            _selectedPeriodStart = periods[currentPeriodIndex]['startDate'];
                            _selectedPeriodEnd = periods[currentPeriodIndex]['endDate'];
                            _selectedDate = DateTime.now();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Avatar circle with initial letter
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: isDark
                                    ? const Color(0xFF1d6f96).withValues(alpha: 0.3)
                                    : const Color(0xFFEEF2FF),
                                child: Text(
                                  emp.name.isNotEmpty
                                      ? emp.name[0].toUpperCase()
                                      : 'E',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.blue.shade300
                                        : const Color(0xFF1d6f96),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Employee information details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      emp.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.work,
                                          size: 13,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          emp.role,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      emp.paymentType == 'Daily'
                                          ? 'Daily Wage: ₹${emp.rate.toStringAsFixed(0)}'
                                          : 'Monthly Salary: ₹${emp.rate.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.blue.shade300
                                            : const Color(0xFF1d6f96),
                                      ),
                                    ),
                                    if (emp.joiningDate != null) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 11,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Joined: ${DateFormat('dd MMM yyyy').format(emp.joiningDate!)} (${_calculateTenure(emp.joiningDate!)})',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Action buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () =>
                                        _openEmployeeForm(existing: emp),
                                    tooltip: 'Edit Details',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteEmployee(emp),
                                    tooltip: 'Remove Employee',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEmployeeForm(),
        backgroundColor: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
        icon: Icon(
          Icons.person_add,
          color: isDark ? const Color(0xFF121212) : Colors.white,
        ),
        label: Text(
          'Add Employee',
          style: TextStyle(
            color: isDark ? const Color(0xFF121212) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.badge_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No employees added yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "+ Add Employee" to create record',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Selected Employee Detailed Screen View ─────────────────────────────────

  Widget _buildEmployeeDetailsView(Employee emp) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payroll = _calculatePayrollStats(emp, _selectedPeriodStart ?? DateTime.now(), _selectedPeriodEnd ?? DateTime.now());

    // Selected date details (status, note)
    String selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    AttendanceRecord? activeRecord = emp.attendance[selectedDateStr];

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(emp.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedEmployee = null;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _openEmployeeForm(existing: emp),
            tooltip: 'Edit details',
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee Quick Info Summary Card
              _buildEmployeeSummaryHeader(emp),
              const SizedBox(height: 12),

              // Calendar Card & Navigation
              _buildCalendarCard(emp),
              const SizedBox(height: 12),

              // Attendance Setter Panel
              _buildAttendanceSetterCard(emp, selectedDateStr, activeRecord),
              const SizedBox(height: 12),

              // Salary & Payroll Calculation Card
              _buildSalaryCalculationCard(emp, payroll),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeSummaryHeader(Employee emp) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isDark
                  ? const Color(0xFF1d6f96).withValues(alpha: 0.3)
                  : const Color(0xFFEEF2FF),
              child: Text(
                emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Role: ${emp.role}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  if (emp.joiningDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Joined: ${DateFormat('dd MMM yyyy').format(emp.joiningDate!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Tenure: ${_calculateTenure(emp.joiningDate!)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1d6f96).withValues(alpha: 0.2)
                    : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                emp.paymentType == 'Daily'
                    ? '₹${emp.rate.toStringAsFixed(0)} / Day'
                    : '₹${emp.rate.toStringAsFixed(0)} / Month',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Beautiful calendar widget using GridView
  Widget _buildCalendarCard(Employee emp) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startDate = _selectedPeriodStart ?? DateTime.now();
    final endDate = _selectedPeriodEnd ?? DateTime.now();
    final formattedPeriod = "${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}";

    // Weekday headers
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Math for calendar cells
    int startingWeekday = startDate.weekday; // 1 (Mon) - 7 (Sun)
    int offset = startingWeekday - 1; // Empty days preceding period
    int totalDays = endDate.difference(startDate).inDays + 1;
    int totalCells = offset + totalDays;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Calendar Month Navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    final periods = _getBillingPeriods(emp);
                    int currentIndex = periods.indexWhere((p) => p['startDate'] == _selectedPeriodStart);
                    if (currentIndex != -1 && currentIndex < periods.length - 1) {
                      setState(() {
                        _selectedPeriodStart = periods[currentIndex + 1]['startDate'];
                        _selectedPeriodEnd = periods[currentIndex + 1]['endDate'];
                      });
                    }
                  },
                ),
                Text(
                  formattedPeriod,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    final periods = _getBillingPeriods(emp);
                    int currentIndex = periods.indexWhere((p) => p['startDate'] == _selectedPeriodStart);
                    if (currentIndex != -1 && currentIndex > 0) {
                      setState(() {
                        _selectedPeriodStart = periods[currentIndex - 1]['startDate'];
                        _selectedPeriodEnd = periods[currentIndex - 1]['endDate'];
                      });
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            // Days of the week row
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: weekdays.map((w) {
                return Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            // Calendar grid of days
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                if (index < offset) {
                  return const SizedBox.shrink(); // Empty cells
                }

                int dayOffset = index - offset;
                DateTime cellDate = startDate.add(Duration(days: dayOffset));
                String cellDateStr = DateFormat('yyyy-MM-dd').format(cellDate);
                AttendanceRecord? record = emp.attendance[cellDateStr];

                bool isSelected = _selectedDate != null &&
                    _selectedDate!.year == cellDate.year &&
                    _selectedDate!.month == cellDate.month &&
                    _selectedDate!.day == cellDate.day;

                // Color coding logic
                Color cellColor = Colors.transparent;
                Color textColor = isDark ? Colors.white : Colors.black87;
                Border? border;

                if (record != null) {
                  if (record.status == 'Present') {
                    cellColor = isDark
                        ? Colors.green.shade900.withValues(alpha: 0.6)
                        : Colors.green.shade100;
                    textColor = isDark ? Colors.green.shade200 : Colors.green.shade800;
                  } else if (record.status == 'Half Day') {
                    cellColor = isDark
                        ? Colors.orange.shade900.withValues(alpha: 0.6)
                        : Colors.orange.shade100;
                    textColor = isDark ? Colors.orange.shade200 : Colors.orange.shade800;
                  } else if (record.status == 'Absent') {
                    cellColor = isDark
                        ? Colors.red.shade900.withValues(alpha: 0.6)
                        : Colors.red.shade100;
                    textColor = isDark ? Colors.red.shade200 : Colors.red.shade800;
                  }
                }

                if (isSelected) {
                  border = Border.all(
                    color: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                    width: 2,
                  );
                }

                // If cell date matches today
                final today = DateTime.now();
                bool isToday = cellDate.year == today.year &&
                    cellDate.month == today.month &&
                    cellDate.day == today.day;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = cellDate;
                      if (record != null) {
                        _selectedStatus = record.status;
                        _noteController.text = record.note;
                      } else {
                        _selectedStatus = 'Present';
                        _noteController.clear();
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellColor,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(10),
                      border: border ??
                          (isToday
                              ? Border.all(
                                  color: Colors.grey.shade400,
                                  width: 1,
                                )
                              : null),
                    ),
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            cellDate.day == 1 || cellDate.isAtSameMomentAs(startDate)
                                ? "${cellDate.day} ${DateFormat('MMM').format(cellDate)}"
                                : cellDate.day.toString(),
                            style: TextStyle(
                              fontSize: cellDate.day == 1 || cellDate.isAtSameMomentAs(startDate) ? 10 : 13,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: textColor,
                            ),
                          ),
                        ),
                        // Small indicator dot if there is a note
                        if (record != null && record.note.isNotEmpty)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.blue.shade200 : const Color(0xFF1d6f96),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Inline attendance updater below the calendar
  Widget _buildAttendanceSetterCard(
    Employee emp,
    String selectedDateStr,
    AttendanceRecord? activeRecord,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate =
        DateFormat('EEEE, d MMMM yyyy').format(_selectedDate!);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // Status selection segmented control/buttons
            const Text(
              'Attendance Status:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusSelectionButton('Present', Colors.green, isDark),
                const SizedBox(width: 8),
                _buildStatusSelectionButton('Half Day', Colors.orange, isDark),
                const SizedBox(width: 8),
                _buildStatusSelectionButton('Absent', Colors.red, isDark),
              ],
            ),
            const SizedBox(height: 12),
            // Custom note input field
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Daily Notes / Remarks (e.g. Overtime details)',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (activeRecord != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        emp.attendance.remove(selectedDateStr);
                        _selectedStatus = 'Present';
                        _noteController.clear();
                      });
                      _saveEmployees();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Attendance cleared.')),
                      );
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Clear Day'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      emp.attendance[selectedDateStr] = AttendanceRecord(
                        status: _selectedStatus,
                        note: _noteController.text.trim(),
                      );
                    });
                    _saveEmployees();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Recorded "$_selectedStatus" for ${DateFormat('d MMM').format(_selectedDate!)}.',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.blue.shade800
                        : const Color(0xFF1d6f96),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Save Record'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelectionButton(
    String status,
    MaterialColor color,
    bool isDark,
  ) {
    bool isSelected = _selectedStatus == status;
    Color activeBg = isDark
        ? color.shade900.withValues(alpha: 0.6)
        : color.shade50;
    Color activeText = isDark ? color.shade200 : color.shade800;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStatus = status;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? activeText
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? activeText
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
          ),
        ),
      ),
    );
  }

  // Salary Calculator card widgets
  Widget _buildSalaryCalculationCard(Employee emp, Map<String, dynamic> stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double present = stats['present'];
    int halfDay = stats['halfDay'];
    int absent = stats['absent'];
    int daysInMonth = stats['daysInMonth'];
    double salary = stats['salary'];
    bool isPaid = stats['isPaid'];
    String monthKey = stats['monthKey'];
    DateTime startDate = stats['startDate'] ?? DateTime.now();
    DateTime endDate = stats['endDate'] ?? DateTime.now();
    bool notJoinedYet = stats['notJoinedYet'] == true;

    String formattedPeriod = "${DateFormat('d MMM yyyy').format(startDate)} - ${DateFormat('d MMM yyyy').format(endDate)}";

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row with Paid Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payroll calculation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        formattedPeriod,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notJoinedYet)
                  GestureDetector(
                    onTap: () => _togglePaidStatus(emp, monthKey),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? (isDark
                                ? Colors.green.shade900.withValues(alpha: 0.3)
                                : Colors.green.shade50)
                            : (isDark
                                ? Colors.amber.shade900.withValues(alpha: 0.3)
                                : Colors.amber.shade50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPaid
                              ? (isDark ? Colors.green.shade500 : Colors.green)
                              : (isDark ? Colors.amber.shade500 : Colors.amber),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaid
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            size: 14,
                            color: isPaid
                                ? (isDark ? Colors.green.shade200 : Colors.green.shade800)
                                : (isDark ? Colors.amber.shade200 : Colors.amber.shade800),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPaid ? 'PAID' : 'UNPAID',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPaid
                                  ? (isDark ? Colors.green.shade200 : Colors.green.shade800)
                                  : (isDark ? Colors.amber.shade200 : Colors.amber.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            if (notJoinedYet)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Employee had not joined yet during this period.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ),
              )
            else ...[
              // Attendance Summary Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Presents', present.toString(), Colors.green),
                  _buildStatItem('Half Days', halfDay.toString(), Colors.orange),
                  _buildStatItem('Absents', absent.toString(), Colors.red),
                ],
              ),
              const Divider(height: 20),
              // Salary calculation details
              const Text(
                'Salary Calculation Formula:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.paymentType == 'Daily'
                          ? 'Formula: Presents × Daily Rate'
                          : 'Formula: Base Salary × (Presents / Days in Period)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      emp.paymentType == 'Daily'
                          ? 'Breakdown: $present presents × ₹${emp.rate.toStringAsFixed(0)}'
                          : 'Breakdown: ₹${emp.rate.toStringAsFixed(0)} × ($present / $daysInMonth days)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Grand Total Payout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Calculated Salary:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${salary.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action button to record payment toggle
              ElevatedButton.icon(
                onPressed: () => _togglePaidStatus(emp, monthKey),
                icon: Icon(
                  isPaid ? Icons.undo : Icons.payment,
                  size: 16,
                ),
                label: Text(
                  isPaid
                      ? 'Mark Period as Unpaid'
                      : 'Record Salary Payment (Mark Paid)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPaid
                      ? Colors.grey
                      : (isDark ? Colors.blue.shade800 : const Color(0xFF1d6f96)),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, MaterialColor color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
