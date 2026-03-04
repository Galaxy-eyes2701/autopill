import 'package:autopill/viewmodels/forgot_password_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AppColors {
  static const Color primary = Color(0xFF0F66BD);
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color textGray = Color(0xFF4E5E71);
  static const Color dark = Color(0xFF111418);
  static const Color border = Color(0xFFDBE0E6);
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;

  String? _validateEmail(String email) {
    if (email.isEmpty) return "Email không được để trống";
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return "Email không hợp lệ";
    return null;
  }

  void _handleForgotPassword() async {
    final email = _emailController.text.trim();
    setState(() => _emailError = _validateEmail(email));
    if (_emailError != null) return;

    final vm = context.read<ForgotPasswordViewModel>();
    await vm.forgotPassword(email);

    if (!mounted) return;

    if (vm.success) {
      _showSuccessDialog();
    } else {
      setState(() => _emailError = vm.errorMessage);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Text(
          'Mật khẩu mới đã được gửi vào Email. Vui lòng kiểm tra hòm thư và đăng nhập lại!',
          textAlign: TextAlign.center,
          style: GoogleFonts.lexend(fontSize: 16, height: 1.5),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('ĐÃ HIỂU',
                  style: GoogleFonts.lexend(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ForgotPasswordViewModel>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, color: AppColors.dark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Khôi phục mật khẩu',
            style: GoogleFonts.lexend(
                color: AppColors.dark,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset,
                  size: 80, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('Anh quên mật khẩu ư?',
                style: GoogleFonts.lexend(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark)),
            const SizedBox(height: 12),
            Text(
              'Đừng lo, hãy nhập email đã đăng ký. Hệ thống sẽ gửi một mật khẩu mới vào hòm thư ngay.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                  fontSize: 16, color: AppColors.textGray, height: 1.5),
            ),
            const SizedBox(height: 40),
            _buildEmailField(),
            const SizedBox(height: 32),
            _buildSubmitButton(vm.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Địa chỉ Email',
            style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.dark)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.lexend(),
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
          decoration: InputDecoration(
            hintText: 'example@gmail.com',
            errorText: _emailError,
            prefixIcon: Icon(Icons.email_outlined,
                color: _emailError != null ? Colors.red : Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        onTap: isLoading ? null : _handleForgotPassword,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 64,
          alignment: Alignment.center,
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text('GỬI MẬT KHẨU MỚI',
                  style: GoogleFonts.lexend(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
        ),
      ),
    );
  }
}
