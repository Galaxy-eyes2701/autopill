import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/implementations/local/app_database.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;


  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  // Validate giống trang đăng ký (Tối thiểu 6 ký tự, có thể tùy chỉnh regex thêm)
  bool _isPasswordValid(String password) {
    return password.length >= 6;
  }

  Future<void> _handleChangePassword() async {
    final oldPass = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    // 1. Reset các lỗi trước khi kiểm tra
    setState(() {
      _currentPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
    });

    bool hasError = false;

    // 2. Validate mật khẩu hiện tại
    if (oldPass.isEmpty) {
      _currentPasswordError = 'Vui lòng nhập mật khẩu hiện tại';
      hasError = true;
    }

    // 3. Validate mật khẩu mới
    if (newPass.isEmpty) {
      _newPasswordError = 'Vui lòng nhập mật khẩu mới';
      hasError = true;
    } else if (!_isPasswordValid(newPass)) {
      _newPasswordError = 'Mật khẩu phải có ít nhất 6 ký tự';
      hasError = true;
    } else if (oldPass == newPass) {
      _newPasswordError = 'Mật khẩu mới không được trùng mật khẩu hiện tại';
      hasError = true;
    }

    // 4. Validate xác nhận mật khẩu
    if (confirmPass.isEmpty) {
      _confirmPasswordError = 'Vui lòng xác nhận mật khẩu mới';
      hasError = true;
    } else if (newPass != confirmPass) {
      _confirmPasswordError = 'Mật khẩu xác nhận không khớp';
      hasError = true;
    }
    if (hasError) {
      setState(() {});
      return;
    }
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');

      if (userEmail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Không tìm thấy phiên đăng nhập!'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      bool isSuccess = await AppDatabase.instance
          .changePassword(userEmail, oldPass, newPass);

      if (!mounted) return;

      if (isSuccess) {
        // Đổi thành công
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Đổi mật khẩu thành công!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        // Mật khẩu cũ nhập sai -> Báo lỗi ngay dưới ô nhập mật khẩu cũ
        setState(() {
          _currentPasswordError = 'Mật khẩu hiện tại không chính xác';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã xảy ra lỗi, vui lòng thử lại!'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: Text('Đổi mật khẩu',
            style: GoogleFonts.lexend(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildPasswordField(
              label: 'Mật khẩu hiện tại',
              controller: _currentPasswordController,
              isObscured: _obscureCurrent,
              errorText: _currentPasswordError,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 20),
            _buildPasswordField(
              label: 'Mật khẩu mới',
              controller: _newPasswordController,
              isObscured: _obscureNew,
              errorText: _newPasswordError,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 20),
            _buildPasswordField(
              label: 'Xác nhận mật khẩu mới',
              controller: _confirmPasswordController,
              isObscured: _obscureConfirm,
              errorText: _confirmPasswordError,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF137FEC),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _handleChangePassword,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('CẬP NHẬT MẬT KHẨU',
                        style: GoogleFonts.lexend(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isObscured,
    required VoidCallback onToggle,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                GoogleFonts.lexend(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isObscured,
          onChanged: (value) {
            if (errorText != null) {
              setState(() {
                if (controller == _currentPasswordController)
                  _currentPasswordError = null;
                if (controller == _newPasswordController)
                  _newPasswordError = null;
                if (controller == _confirmPasswordController)
                  _confirmPasswordError = null;
              });
            }
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            errorText: errorText,
            errorStyle: GoogleFonts.lexend(color: Colors.red),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            // Viền đỏ khi có lỗi
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5)),
            suffixIcon: IconButton(
              icon: Icon(
                isObscured ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}
