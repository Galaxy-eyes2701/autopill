import 'package:autopill/viewmodels/login/login_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../main_screen.dart';
import '../../di.dart';

class AppColors {
  static const Color primary = Color(0xFF0F66BD);
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color textGray = Color(0xFF4E5E71);
  static const Color dark = Color(0xFF111418);
  static const Color border = Color(0xFFDBE0E6);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isObscure = true;
  String? _emailError;
  String? _passwordError;

  String? _validateEmail(String email) {
    if (email.isEmpty) return "Email không được để trống";
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return "Email không hợp lệ";
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return "Mật khẩu không được để trống";
    return null;
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = _validateEmail(email);
      _passwordError = _validatePassword(password);
    });
    if (_emailError != null || _passwordError != null) return;

    final vm = context.read<LoginViewModel>();
    final success = await vm.login(email, password);

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _emailError = vm.errorMessage;
        _passwordError = vm.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.medication_liquid,
                      size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text('AutoPill',
                    style: GoogleFonts.lexend(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Quản lý sức khỏe mỗi ngày',
                    style: GoogleFonts.lexend(
                        fontSize: 16, color: AppColors.textGray)),
              ),
              const SizedBox(height: 48),
              _buildLabel('Email'),
              _buildTextField(
                controller: _emailController,
                hint: 'Nhập email của bạn',
                icon: Icons.email_outlined,
                errorText: _emailError,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
              ),
              const SizedBox(height: 20),
              _buildLabel('Mật khẩu'),
              _buildPasswordField(),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider(
                          create: (_) => buildForgotPassword(),
                          child: const ForgotPasswordScreen(),
                        ),
                      ),
                    );
                  },
                  child: Text('Quên mật khẩu?',
                      style: GoogleFonts.lexend(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
              _buildLoginButton(vm.isLoading),
              const SizedBox(height: 32),
              _buildRegisterLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.dark)),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
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

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _isObscure,
      onChanged: (_) {
        if (_passwordError != null) setState(() => _passwordError = null);
      },
      decoration: InputDecoration(
        hintText: 'Nhập mật khẩu',
        errorText: _passwordError,
        prefixIcon: Icon(Icons.lock_outline,
            color: _passwordError != null ? Colors.red : Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility,
              color: _passwordError != null ? Colors.red : Colors.grey),
          onPressed: () => setState(() => _isObscure = !_isObscure),
        ),
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

  Widget _buildLoginButton(bool isLoading) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        onTap: isLoading ? null : _handleLogin,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 64,
          alignment: Alignment.center,
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text('ĐĂNG NHẬP',
                  style: GoogleFonts.lexend(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Chưa có tài khoản? ',
            style: GoogleFonts.lexend(color: AppColors.textGray)),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => buildRegister(),
                  child: const RegisterScreen(),
                ),
              ),
            );
          },
          child: Text('Đăng ký ngay',
              style: GoogleFonts.lexend(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline)),
        ),
      ],
    );
  }
}
