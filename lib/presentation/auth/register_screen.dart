import 'package:autopill/viewmodels/auth/register_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/dtos/auth/register_request_dto.dart';

class AppColors {
  static const Color primary = Color(0xFF0F66BD);
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color textGray = Color(0xFF4E5E71);
  static const Color dark = Color(0xFF111418);
  static const Color border = Color(0xFFDBE0E6);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isObscure = true;
  bool _isConfirmObscure = true;
  bool _agreeToTerms = false;

  DateTime? _selectedDate;

  String? _nameError;
  String? _emailError;
  String? _passError;
  String? _confirmPassError;
  String? _dobError;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _validateEmailLocal(String email) {
    if (email.isEmpty) return "Email không được để trống";
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return "Email không hợp lệ";
    return null;
  }

  String? _validatePasswordLocal(String password) {
    if (password.isEmpty) return "Mật khẩu không được để trống";
    if (password.length < 6) return "Mật khẩu phải có ít nhất 6 ký tự";
    if (!RegExp(r'(?=.*[a-z])').hasMatch(password))
      return "Phải chứa ít nhất 1 chữ cái thường";
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(password))
      return "Phải chứa ít nhất 1 chữ cái hoa";
    if (!RegExp(r'(?=.*\d)').hasMatch(password))
      return "Phải chứa ít nhất 1 số";
    return null;
  }

  void _showCupertinoDatePicker() {
    final vm = context.read<RegisterViewModel>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext builder) {
        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 10),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Xong',
                        style: GoogleFonts.lexend(
                            fontSize: 18,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _selectedDate ?? DateTime(2000, 1, 1),
                    minimumDate: DateTime(1900),
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: (DateTime newDate) {
                      setState(() {
                        _selectedDate = newDate;
                        _dobError = vm.validateDob(newDate);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleRegister() async {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty
          ? "Họ tên không được để trống"
          : null;
      _emailError = _validateEmailLocal(_emailController.text.trim());
      _passError = _validatePasswordLocal(_passwordController.text);
      _confirmPassError = _confirmPasswordController.text.isEmpty
          ? "Vui lòng xác nhận lại mật khẩu"
          : (_passwordController.text != _confirmPasswordController.text
              ? "Mật khẩu không khớp"
              : null);
      if (_selectedDate == null) _dobError = "Vui lòng chọn ngày sinh";
    });

    if (_nameError != null ||
        _emailError != null ||
        _passError != null ||
        _confirmPassError != null ||
        _dobError != null) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng đồng ý với điều khoản")));
      return;
    }

    final vm = context.read<RegisterViewModel>();
    final request = RegisterRequestDto(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      dob: _selectedDate?.toIso8601String(),
    );

    await vm.register(request);

    if (!mounted) return;

    if (vm.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Đăng ký thành công!"), backgroundColor: Colors.green));
      Navigator.pop(context);
    } else {
      setState(() => _emailError = vm.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegisterViewModel>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: AppColors.dark, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: Text('Đăng Ký Tài Khoản',
            style: GoogleFonts.lexend(
                color: AppColors.dark,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            _buildRequiredLabel('Họ và tên'), // Dùng hàm mới có dấu *
            _buildTextField(
              controller: _nameController,
              hint: 'Nguyễn Văn A',
              icon: Icons.person_outline,
              errorText: _nameError,
              onChanged: (val) {
                setState(() => _nameError =
                    val.trim().isEmpty ? "Họ tên không được để trống" : null);
              },
            ),
            const SizedBox(height: 16),
            _buildRequiredLabel('Ngày sinh'), // Thêm label Ngày sinh
            _buildBirthDateSection(),
            if (_dobError != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: Text(_dobError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12))),
            const SizedBox(height: 16),
            _buildRequiredLabel('Email'),
            _buildTextField(
              controller: _emailController,
              hint: 'example@gmail.com',
              icon: Icons.email_outlined,
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
              onChanged: (val) {
                setState(() => _emailError = _validateEmailLocal(val.trim()));
              },
            ),
            const SizedBox(height: 16),
            _buildRequiredLabel('Mật khẩu'),
            _buildPasswordField(
              controller: _passwordController,
              hint: 'Chữ hoa, thường, số, >=6 ký tự',
              isObscure: _isObscure,
              errorText: _passError,
              onToggle: () => setState(() => _isObscure = !_isObscure),
              onChanged: (val) {
                setState(() {
                  _passError = _validatePasswordLocal(val);
                  if (_confirmPasswordController.text.isNotEmpty) {
                    _confirmPassError = val != _confirmPasswordController.text
                        ? "Mật khẩu không khớp"
                        : null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            _buildRequiredLabel('Xác nhận mật khẩu'),
            _buildPasswordField(
              controller: _confirmPasswordController,
              hint: 'Nhập lại mật khẩu',
              isObscure: _isConfirmObscure,
              errorText: _confirmPassError,
              onToggle: () =>
                  setState(() => _isConfirmObscure = !_isConfirmObscure),
              onChanged: (val) {
                setState(() => _confirmPassError =
                    val != _passwordController.text
                        ? "Mật khẩu không khớp"
                        : null);
              },
            ),
            const SizedBox(height: 24),
            _buildTermsCheckbox(),
            const SizedBox(height: 32),
            _buildRegisterButton(vm.isLoading),
            const SizedBox(height: 24),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  // Hàm tạo Label mới tích hợp dấu * đỏ cho các trường bắt buộc
  Widget _buildRequiredLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(
            text: text,
            style: GoogleFonts.lexend(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    String? errorText,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        prefixIcon:
            Icon(icon, color: errorText != null ? Colors.red : Colors.grey),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2)),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool isObscure,
    required VoidCallback onToggle,
    String? errorText,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        prefixIcon: Icon(Icons.lock_outline,
            color: errorText != null ? Colors.red : Colors.grey),
        suffixIcon: IconButton(
            icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility,
                color: errorText != null ? Colors.red : Colors.grey),
            onPressed: onToggle),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2)),
      ),
    );
  }

  Widget _buildRegisterButton(bool isLoading) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isLoading ? null : _handleRegister,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text('Tạo tài khoản',
                  style: GoogleFonts.lexend(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildBirthDateSection() {
    return GestureDetector(
      onTap: _showCupertinoDatePicker,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _dobError != null ? Colors.red : AppColors.border,
                width: 1)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                _selectedDate == null
                    ? "Chọn ngày sinh"
                    : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                style: GoogleFonts.lexend(
                    fontSize: 16,
                    color:
                        _selectedDate == null ? Colors.black54 : Colors.black)),
            Icon(Icons.calendar_today,
                color: _dobError != null ? Colors.red : AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() => Row(children: [
        Checkbox(
            value: _agreeToTerms,
            onChanged: (v) => setState(() => _agreeToTerms = v!)),
        const Expanded(child: Text("Tôi đồng ý với điều khoản sử dụng")),
      ]);

  Widget _buildLoginLink() => Center(
        child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Đã có tài khoản? Đăng nhập ngay")),
      );
}