import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';
import '../modules/module_pages.dart';
import '../modules/platform_pages.dart';
import '../modules/prayer_growth_pages.dart';
import '../modules/privacy_security_screen.dart';
import 'believer_journey_screen.dart';
import 'life_workspace_screen.dart';

class AccountPortal extends StatefulWidget {
  const AccountPortal({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
    required this.onAuthChanged,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final ValueChanged<AuthResult?> onAuthChanged;
  final Future<void> Function() onDataChanged;

  @override
  State<AccountPortal> createState() => _AccountPortalState();
}

class _AccountPortalState extends State<AccountPortal> {
  final _loginPhone = TextEditingController();
  final _loginPassword = TextEditingController();
  final _signupName = TextEditingController();
  final _signupUsername = TextEditingController();
  final _signupPhone = TextEditingController();
  final _signupPassword = TextEditingController();
  final _signupConfirmPassword = TextEditingController();
  final _signupOtp = TextEditingController();
  bool _busy = false;
  bool _signupMode = false;
  bool _otpRequested = false;
  bool _otpVerified = false;
  bool? _usernameAvailable;
  Timer? _usernameDebounce;
  String _usernameStatus = '';
  String _status = '';
  String _signupGender = '';

  bool get _english => widget.language == AppLanguage.english;

  @override
  void initState() {
    super.initState();
    _syncSession();
    _signupUsername.addListener(_scheduleUsernameCheck);
  }

  @override
  void didUpdateWidget(covariant AccountPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.token != widget.session?.token) {
      _syncSession();
    }
  }

  void _syncSession() {
    final user = widget.session?.user;
    if (user != null) {
      _loginPhone.text = user.phoneNumber;
      _signupPhone.text = user.phoneNumber;
      _signupName.text = user.fullName;
      _signupUsername.text = user.username;
    } else {
      _loginPassword.clear();
      _signupUsername.clear();
      _usernameAvailable = null;
      _usernameStatus = '';
      _signupPassword.clear();
      _signupConfirmPassword.clear();
      _signupOtp.clear();
      _otpRequested = false;
      _otpVerified = false;
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _loginPhone.dispose();
    _loginPassword.dispose();
    _signupName.dispose();
    _signupUsername.dispose();
    _signupPhone.dispose();
    _signupPassword.dispose();
    _signupConfirmPassword.dispose();
    _signupOtp.dispose();
    super.dispose();
  }


  void _scheduleUsernameCheck() {
    final username = _signupUsername.text.trim().toLowerCase();
    _usernameDebounce?.cancel();
    if (username.isEmpty) {
      setState(() {
        _usernameAvailable = null;
        _usernameStatus = '';
      });
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
      setState(() {
        _usernameAvailable = false;
        _usernameStatus = _english
            ? 'Use 3-24 letters, numbers, or underscores.'
            : '3-24 ፊደሎች፣ ቁጥሮች ወይም _ ብቻ።';
      });
      return;
    }
    setState(() {
      _usernameAvailable = null;
      _usernameStatus = _english ? 'Checking username...' : 'የተጠቃሚ ስም በመፈተሽ ላይ...';
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final result = await widget.apiClient.checkUsernameAvailability(username);
        if (!mounted || _signupUsername.text.trim().toLowerCase() != username) {
          return;
        }
        final available = result['available'] == true;
        setState(() {
          _usernameAvailable = available;
          _usernameStatus = available
              ? (_english ? 'Username is available.' : 'የተጠቃሚ ስሙ ክፍት ነው።')
              : (_english ? 'Username is taken.' : 'የተጠቃሚ ስሙ ተይዟል።');
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _usernameAvailable = null;
          _usernameStatus = _english
              ? 'Could not check username now.'
              : 'አሁን የተጠቃሚ ስም መፈተሽ አልተቻለም።';
        });
      }
    });
  }

  Future<void> _authenticate(Future<AuthResult> Function() action,
      {void Function(AuthResult)? onSuccess}) async {
    setState(() {
      _busy = true;
      _status = _english ? 'Connecting securely...' : 'በደህና በመገናኘት ላይ...';
    });
    try {
      final result = await action();
      if (!mounted) return;
      widget.onAuthChanged(result);
      await widget.onDataChanged();
      if (!mounted) return;
      onSuccess?.call(result);
      setState(() =>
          _status = _english ? 'Signed in successfully.' : 'በተሳካ ሁኔታ ገብተዋል።');
    } catch (error) {
      if (!mounted) return;
      setState(
          () => _status = error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestOtp() async {
    setState(() => _busy = true);
    try {
      final phone = _signupPhone.text.trim();
      if (phone.isEmpty) {
        setState(
            () => _status = AppStrings.of(widget.language, 'phone_number'));
        return;
      }
      await widget.apiClient.requestOtp(phone);
      if (!mounted) return;
      setState(() {
        _otpRequested = true;
        _status = _english
            ? 'Verification code sent. It expires in 10 minutes.'
            : 'የማረጋገጫ ኮድ ተልኳል። በ10 ደቂቃ ውስጥ ያበቃል።';
      });
    } catch (error) {
      if (mounted) setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _busy = true);
    try {
      final phone = _signupPhone.text.trim();
      final code = _signupOtp.text.trim();
      if (phone.isEmpty || code.isEmpty) {
        setState(() => _status = _english
            ? 'Enter the phone and OTP code.'
            : 'ስልኩን እና OTP ኮዱን ያስገቡ።');
        return;
      }
      await widget.apiClient.verifyOtp(phone, code);
      if (!mounted) return;
      setState(() {
        _otpVerified = true;
        _status = _english ? 'Phone verified.' : 'ስልክ ተረጋግጧል።';
      });
    } catch (error) {
      if (mounted) setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        _AccountHero(session: session, english: _english),
        const SizedBox(height: 18),
        if (session == null) ...[
          _buildSignedOutPanel(context),
        ] else ...[
          _AccountActions(
            english: _english,
            onJourney: () => _open(BelieverJourneyScreen(
                apiClient: widget.apiClient,
                session: session,
                language: widget.language)),
            onConnected: () => _open(LifeWorkspaceScreen(
                language: widget.language,
                apiClient: widget.apiClient,
                session: session)),
            onProfile: () => _open(ProfileScreen(
              language: widget.language,
              apiClient: widget.apiClient,
              session: session,
              onAuthChanged: widget.onAuthChanged,
              onDataChanged: widget.onDataChanged,
            )),
            onMemberships: () => _open(ChurchMembershipManagementScreen(
              language: widget.language,
              apiClient: widget.apiClient,
              session: session,
              onDataChanged: widget.onDataChanged,
            )),
            onGrowth: () => _open(GrowthScreen(
                language: widget.language,
                apiClient: widget.apiClient,
                session: session)),
            onMarketplace: () => _open(MarketplaceScreen(
                language: widget.language,
                apiClient: widget.apiClient,
                session: session)),
            onNotifications: () => _open(NotificationsScreen(
                language: widget.language,
                apiClient: widget.apiClient,
                token: session.token,
                session: session)),
            onSignOut: () {
              unawaited(
                  widget.apiClient.logout(session.token).catchError((_) {}));
              widget.onAuthChanged(null);
              setState(() => _status = _english ? 'Signed out.' : 'ወጥተዋል።');
            },
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(_english ? 'Privacy & Security' : 'ግላዊነት እና ደህንነት'),
              subtitle: Text(_english
                  ? 'Account privacy, devices, blocked & muted'
                  : 'ግላዊነት፣ መሳሪያዎች፣ የታገዱና ጸጥ የተደረጉ'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(PrivacySecurityScreen(
                apiClient: widget.apiClient,
                token: session.token,
                language: widget.language,
              )),
            ),
          ),
        ],
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(_status),
          ),
        ],
      ],
    );
  }

  Widget _buildSignedOutPanel(BuildContext context) {
    final title = _signupMode
        ? (_english ? 'Create your account' : 'መለያ ፍጠር')
        : (_english ? 'Sign in to your account' : 'ወደ መለያዎ ይግቡ');
    final subtitle = _signupMode
        ? (_english
            ? 'New accounts require phone verification before registration.'
            : 'አዲስ መለያ ከመመዝገብ በፊት የስልክ ማረጋገጫ ያስፈልጋል።')
        : (_english
            ? 'Existing users sign in with phone number or username.'
            : 'ያለዎትን መለያ በስልክ ቁጥር ወይም በተጠቃሚ ስም ይግቡ።');
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: .10),
            blurRadius: 26,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.login_rounded),
                label: Text(_english ? 'Sign in' : 'ግባ'),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.person_add_alt_rounded),
                label: Text(_english ? 'Sign up' : 'ተመዝገብ'),
              ),
            ],
            selected: {_signupMode},
            onSelectionChanged: _busy
                ? null
                : (selection) {
                    setState(() {
                      _signupMode = selection.first;
                      _status = '';
                    });
                  },
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _signupMode ? _buildSignUpForm() : _buildSignInForm(),
          ),
        ]),
      ),
    );
  }

  Widget _buildSignInForm() {
    return Column(
      key: const ValueKey('signin-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginPhone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: _english ? 'Phone or username' : 'ስልክ ወይም የተጠቃሚ ስም',
            prefixIcon: const Icon(Icons.person_search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPassword,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppStrings.of(widget.language, 'password'),
            prefixIcon: const Icon(Icons.lock_outline_rounded),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : _forgotPassword,
            child: Text(_english ? 'Forgot password?' : 'የይለፍ ቃል ረሱ?'),
          ),
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: _busy ? null : _signIn,
          icon: const Icon(Icons.login_rounded),
          label: Text(
              _english ? 'Sign in' : AppStrings.of(widget.language, 'login')),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      key: const ValueKey('signup-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _signupName,
          decoration: InputDecoration(
            labelText: AppStrings.of(widget.language, 'full_name'),
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupUsername,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: _english ? 'Username' : 'የተጠቃሚ ስም',
            hintText: 'selam_abebe',
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            helperText: _usernameStatus.isEmpty ? null : _usernameStatus,
            suffixIcon: _usernameAvailable == null
                ? null
                : Icon(
                    _usernameAvailable!
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: _usernameAvailable!
                        ? AppTheme.evergreen
                        : Theme.of(context).colorScheme.error,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupPhone,
          onChanged: (_) => setState(() {
            _otpRequested = false;
            _otpVerified = false;
            _signupOtp.clear();
          }),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: AppStrings.of(widget.language, 'phone_number'),
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _signupOtp,
              enabled: _otpRequested,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _english ? 'OTP code' : 'የOTP ኮድ',
                suffixIcon: _otpVerified
                    ? const Icon(Icons.verified_rounded,
                        color: AppTheme.evergreen)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed:
                _busy ? null : (_otpRequested ? _verifyOtp : _requestOtp),
            child: Text(_otpRequested
                ? (_english ? 'Verify' : 'አረጋግጥ')
                : (_english ? 'Send OTP' : 'OTP ላክ')),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _signupPassword,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppStrings.of(widget.language, 'password'),
            prefixIcon: const Icon(Icons.lock_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _signupConfirmPassword,
          obscureText: true,
          decoration: InputDecoration(
            labelText: _english ? 'Confirm password' : 'የይለፍ ቃል ያረጋግጡ',
            prefixIcon: const Icon(Icons.lock_reset_rounded),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(_english ? 'Sex' : 'ጾታ',
              style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(height: 2),
        Text(
          _english
              ? 'Used for courtship matching. This cannot be changed later.'
              : 'ለጋብቻ ማዛመጃ ይውላል። በኋላ ሊቀየር አይችልም።',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(children: [
          for (final option in [('male', _english ? 'Male' : 'ወንድ'), ('female', _english ? 'Female' : 'ሴት')])
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: option.$1 == 'male' ? 8 : 0),
                child: ChoiceChip(
                  label: SizedBox(width: double.infinity, child: Text(option.$2, textAlign: TextAlign.center)),
                  selected: _signupGender == option.$1,
                  onSelected: (_) => setState(() => _signupGender = option.$1),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy || !_otpVerified || _signupGender.isEmpty ? null : _signUp,
          icon: const Icon(Icons.person_add_alt_rounded),
          label: Text(_english
              ? 'Create account'
              : AppStrings.of(widget.language, 'register')),
        ),
      ],
    );
  }


  Future<void> _forgotPassword() async {
    final phone = TextEditingController(text: _loginPhone.text.trim());
    final code = TextEditingController();
    final nextPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    bool otpSent = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_english ? 'Reset password' : 'የይለፍ ቃል ዳግም ያዘጋጁ'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: AppStrings.of(widget.language, 'phone_number'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  if (phone.text.trim().isEmpty) return;
                  await widget.apiClient.requestOtp(phone.text.trim());
                  setDialogState(() => otpSent = true);
                },
                icon: const Icon(Icons.sms_rounded),
                label: Text(otpSent
                    ? (_english ? 'OTP sent' : 'OTP ተልኳል')
                    : (_english ? 'Send OTP' : 'OTP ላክ')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: _english ? 'OTP code' : 'የOTP ኮድ'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nextPassword,
                obscureText: true,
                decoration: InputDecoration(labelText: _english ? 'New password' : 'አዲስ የይለፍ ቃል'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmPassword,
                obscureText: true,
                decoration: InputDecoration(labelText: _english ? 'Confirm password' : 'የይለፍ ቃል ያረጋግጡ'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_english ? 'Cancel' : 'ተወው')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(_english ? 'Reset' : 'ዳግም አዘጋጅ')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _status = _english ? 'Resetting password...' : 'የይለፍ ቃል በመቀየር ላይ...';
    });
    try {
      await widget.apiClient.resetPassword(
        phoneNumber: phone.text.trim(),
        otpCode: code.text.trim(),
        newPassword: nextPassword.text,
        confirmPassword: confirmPassword.text,
      );
      if (!mounted) return;
      setState(() => _status = _english
          ? 'Password reset. Sign in with the new password.'
          : 'የይለፍ ቃል ተቀይሯል። በአዲሱ ይግቡ።');
    } catch (error) {
      if (mounted) setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final phone = _loginPhone.text.trim();
    final password = _loginPassword.text;
    if (phone.isEmpty || password.isEmpty) {
      setState(() => _status = _english
          ? 'Enter your phone number or username and password.'
          : 'ስልክ ቁጥር እና የይለፍ ቃል ያስገቡ።');
      return;
    }
    await _authenticate(() => widget.apiClient.login(
          phoneNumber: phone,
          password: password,
        ));
  }

  Future<void> _signUp() async {
    final name = _signupName.text.trim();
    final username = _signupUsername.text.trim().toLowerCase();
    final phone = _signupPhone.text.trim();
    final password = _signupPassword.text;
    final confirmPassword = _signupConfirmPassword.text;
    if (name.isEmpty || username.isEmpty || phone.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _status = _english
          ? 'Enter your name, username, phone number, password, and confirmation.'
          : 'ስም፣ ስልክ ቁጥር እና የይለፍ ቃል ያስገቡ።');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _status = _english
          ? 'Passwords do not match.'
          : 'የይለፍ ቃሎቹ አይዛመዱም።');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _status = _english
          ? 'Passwords do not match.'
          : 'የይለፍ ቃሎቹ አይዛመዱም።');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
      setState(() => _status = _english
          ? 'Username must be 3-24 letters, numbers, or underscores.'
          : 'የተጠቃሚ ስም 3-24 ፊደሎች፣ ቁጥሮች ወይም _ ብቻ ይሁን።');
      return;
    }
    if (_usernameAvailable == false) {
      setState(() => _status = _english
          ? 'Choose an available username before creating an account.'
          : 'መለያ ከመፍጠርዎ በፊት ክፍት የተጠቃሚ ስም ይምረጡ።');
      return;
    }
    if (!_otpVerified) {
      setState(() => _status = _english
          ? 'Verify your phone before creating an account.'
          : 'መለያ ከመፍጠርዎ በፊት ስልኩን ያረጋግጡ።');
      return;
    }
    try {
      final availability = await widget.apiClient.checkUsernameAvailability(username);
      if (availability['available'] != true) {
        setState(() => _status = _english
            ? 'That username is already taken.'
            : 'ይህ የተጠቃሚ ስም ተይዟል።');
        return;
      }
    } catch (error) {
      setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
      return;
    }
    await _authenticate(
      () => widget.apiClient.register(
        fullName: name,
        phoneNumber: phone,
        username: username,
        password: password,
        confirmPassword: confirmPassword,
        language: widget.language.code,
        gender: _signupGender,
      ),
      onSuccess: (result) => _open(
        BelieverJourneyScreen(
          apiClient: widget.apiClient,
          session: result,
          language: widget.language,
        ),
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.session, required this.english});
  final AuthResult? session;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final signedIn = session != null;
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF082C22), AppTheme.evergreen, Color(0xFF2B765D)],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x3312372A), blurRadius: 30, offset: Offset(0, 14))
        ],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 31,
          backgroundColor: AppTheme.gold,
          child: Icon(signedIn ? Icons.person_rounded : Icons.lock_open_rounded,
              color: AppTheme.forest, size: 30),
        ),
        const SizedBox(width: 17),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            signedIn
                ? session!.user.fullName
                : (english ? 'Your faith profile' : 'የእምነት መገለጫዎ'),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            signedIn
                ? session!.user.phoneNumber
                : (english
                    ? 'Register, sign in, and continue across every pillar.'
                    : 'ይመዝገቡ፣ ይግቡ እና በሁሉም መሠረቶች ይቀጥሉ።'),
            style: const TextStyle(color: Colors.white70),
          ),
        ])),
      ]),
    );
  }
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({
    required this.english,
    required this.onJourney,
    required this.onConnected,
    required this.onProfile,
    required this.onMemberships,
    required this.onGrowth,
    required this.onMarketplace,
    required this.onNotifications,
    required this.onSignOut,
  });

  final bool english;
  final VoidCallback onConnected;
  final VoidCallback onJourney;
  final VoidCallback onProfile;
  final VoidCallback onMemberships;
  final VoidCallback onGrowth;
  final VoidCallback onMarketplace;
  final VoidCallback onNotifications;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.route_rounded,
        english ? 'My Christian journey' : 'የክርስቲያን ጉዞዬ',
        onJourney
      ),
      (
        Icons.hub_rounded,
        english ? 'Life workspace' : 'የሕይወት የሥራ ቦታ',
        onConnected
      ),
      (Icons.edit_rounded, english ? 'Edit profile' : 'መገለጫ አርትዕ', onProfile),
      (
        Icons.church_rounded,
        english ? 'Church memberships' : 'የቤተ ክርስቲያን አባልነት',
        onMemberships
      ),
      (
        Icons.local_fire_department_rounded,
        english ? 'Growth and streaks' : 'እድገት እና ተከታታይነት',
        onGrowth
      ),
      (
        Icons.storefront_rounded,
        english ? 'Marketplace' : 'ገበያ',
        onMarketplace
      ),
      (
        Icons.notifications_rounded,
        english ? 'Notifications' : 'ማሳወቂያዎች',
        onNotifications
      ),
    ];
    return Column(children: [
      for (final action in actions) ...[
        Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            leading: Icon(action.$1, color: AppTheme.evergreen),
            title: Text(action.$2,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            trailing: const Icon(Icons.arrow_forward_rounded),
            onTap: action.$3,
          ),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 4),
      OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(english ? 'Sign out' : 'ውጣ')),
    ]);
  }
}
