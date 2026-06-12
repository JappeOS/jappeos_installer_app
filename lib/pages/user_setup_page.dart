import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../hostname_generator.dart';
import '../provider/install_provider.dart';
import '../provider/page_provider.dart';

class UserSetupPage extends InstallerPage {
  UserSetupPage() : super('User Setup');

  @override
  List<Widget> widget(BuildContext context, int index) {
    return [Expanded(child: _UserSetupPageWidget(index: index))];
  }
}

class _UserSetupPageWidget extends StatefulWidget {
  final int index;

  const _UserSetupPageWidget({required this.index});

  @override
  State<_UserSetupPageWidget> createState() => _UserSetupPageWidgetState();
}

class _UserSetupPageWidgetState extends State<_UserSetupPageWidget>
    with AutomaticKeepAliveClientMixin<_UserSetupPageWidget> {
  final _nameKey = const TextFieldKey('name');
  final _passwordKey = const TextFieldKey('password');
  final _hostnameKey = const TextFieldKey('hostname');
  final _formController = FormController();

  @override
  void initState() {
    super.initState();
    final nav = context.read<PageProvider>();
    nav.registerFormHandler(widget.index, _handleSubmit);
  }

  Future<bool> _handleSubmit() async {
    _formController.revalidate(context, FormValidationMode.submitted);
    for (final val in _formController.validities.values) {
      if (val is Future<ValidationResult?>) {
        await val;
      }
    }

    final errors = _formController.errors;
    if (errors.isNotEmpty || !mounted) {
      return false;
    }

    final values = _formController.values;
    final installProvider = context.read<InstallProvider>();
    installProvider.installPlan = installProvider.installPlan.copyWith(
      username: _nameKey[values],
      password: _passwordKey[values],
      hostname: _hostnameKey[values],
    );

    return true;
  }

  @override
  void dispose() {
    context.read<PageProvider>().unregisterFormHandler(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scaling = Theme.of(context).scaling;
    return Form(
      controller: _formController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("User Setup").h3(),
          Gap(2 * scaling),
          const Text("Create your user and pick a hostname below.").muted(),
          Gap(8 * scaling),
          FormTableLayout(
            rows: [
              FormField<String>(
                key: _nameKey,
                label: const Text('Username'),
                validator: const LengthValidator(min: 3, max: 32)
                    & const _UsernameValidator(),
                showErrors: const {
                  FormValidationMode.changed,
                  FormValidationMode.submitted,
                },
                child: const TextField(autofocus: true),
              ),
              FormField<String>(
                key: _passwordKey,
                label: const Text('Password'),
                validator: const LengthValidator(min: 8, max: 64) &
                    const SafePasswordValidator(
                      requireSpecialChar: false,
                      requireUppercase: false,
                      requireLowercase: false,
                    ),
                showErrors: const {
                  FormValidationMode.changed,
                  FormValidationMode.submitted,
                },
                child: const TextField(
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  features: [
                    InputFeature.passwordToggle(),
                  ],
                ),
              ),
              FormField<String>(
                key: _hostnameKey,
                label: const Text('Computer Name'),
                validator: const LengthValidator(min: 3, max: 63)
                    & const _HostnameValidator(),
                showErrors: const {
                  FormValidationMode.changed,
                  FormValidationMode.submitted,
                },
                child: TextField(initialValue: generateHostname()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _UsernameValidator extends Validator<String> {
  final String? message;

  // ignore: unused_element_parameter
  const _UsernameValidator({this.message});

  @override
  FutureOr<ValidationResult?> validate(
      BuildContext context, String? value, FormValidationMode state) async {
    ShadcnLocalizations localizations =
        Localizations.of(context, ShadcnLocalizations);
    if (kDebugMode) {
      debugPrint("Skipping form validation for _UsernameValidator due to debug mode");
      return null;
    }

    if (value == null || value.isEmpty) {
      return InvalidResult(message ?? localizations.formNotEmpty, state: state);
    }

    final installProvider = context.read<InstallProvider>();
    bool result;
    try {
      result = await installProvider.service.verifyUsername(value);
    } catch (_) {
      result = false;
    }

    if (!result) {
      return InvalidResult(
        message ?? "Invalid username, example: `jack_robinson`",
        state: state,
      );
    }

    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is _UsernameValidator &&
        other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}

class _HostnameValidator extends Validator<String> {
  final String? message;

  // ignore: unused_element_parameter
  const _HostnameValidator({this.message});

  @override
  FutureOr<ValidationResult?> validate(
      BuildContext context, String? value, FormValidationMode state) async {
    ShadcnLocalizations localizations =
        Localizations.of(context, ShadcnLocalizations);
    if (kDebugMode) {
      debugPrint("Skipping form validation for _HostnameValidator due to debug mode");
      return null;
    }

    if (value == null || value.isEmpty) {
      return InvalidResult(message ?? localizations.formNotEmpty, state: state);
    }

    final installProvider = context.read<InstallProvider>();
    bool result;
    try {
      result = await installProvider.service.verifyHostname(value);
    } catch (_) {
      result = false;
    }

    if (!result) {
      return InvalidResult(
        message ?? "Invalid hostname, example: `my-pc01`",
        state: state,
      );
    }

    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is _HostnameValidator &&
        other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}