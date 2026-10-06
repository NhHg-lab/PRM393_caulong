import 'package:flutter/material.dart';

import '../services/google_token_provider.dart';
import '../theme/app_theme.dart';

/// Hộp chọn tài khoản Google GIẢ (GoogleMode.mock). Trả về null nếu người
/// dùng đóng hộp mà không chọn.
Future<MockGoogleAccount?> showMockGooglePicker(BuildContext context) {
  return showModalBottomSheet<MockGoogleAccount>(
    context: context,
    showDragHandle: true,
    // Cho phép sheet cao hơn mặc định (9/16 màn hình) và cuộn trên máy nhỏ.
    isScrollControlled: true,
    builder: (context) => const _MockGooglePicker(),
  );
}

class _MockGooglePicker extends StatelessWidget {
  const _MockGooglePicker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      key: const Key('mock-google-sheet'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chọn tài khoản Google (DEMO)',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.limeSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.science_outlined, size: 18, color: AppColors.navy),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chế độ demo, không phải Google thật',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final account in MockGoogleAccount.demoAccounts)
              ListTile(
                key: Key('mock-google-account-${account.email}'),
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  child: Text(account.displayName.characters.first),
                ),
                title: Text(account.displayName),
                subtitle: Text(account.email),
                onTap: () => Navigator.pop(context, account),
              ),
          ],
        ),
      ),
    );
  }
}
