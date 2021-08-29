import 'package:flutter/material.dart';

class DecoratedTextFormField extends StatefulWidget {
  const DecoratedTextFormField({
    Key? key,
    this.padding,
    this.labelText,
    this.keyboardType,
    this.textInputAction,
    this.initialValue,
    this.onChanged,
    this.onFieldSubmitted,
    this.onSaved,
    this.validator,
    this.decoration,
    this.maxLines = 1,
    this.obscureText = false,
    this.controller,
    this.autoFillHints,
    this.focusNode,
    this.autovalidateMode,
  })  : assert(labelText != null || decoration != null),
        assert(onChanged != null || controller != null),
        super(key: key);

  final EdgeInsetsGeometry? padding;
  final String? labelText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? initialValue;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final void Function(String?)? onSaved;
  final String? Function(String?)? validator;
  final InputDecoration? decoration;
  final int? maxLines;
  final bool obscureText;
  final TextEditingController? controller;
  final Iterable<String>? autoFillHints;
  final FocusNode? focusNode;
  final AutovalidateMode? autovalidateMode;

  @override
  _DecoratedTextFormFieldState createState() => _DecoratedTextFormFieldState();
}

class _DecoratedTextFormFieldState extends State<DecoratedTextFormField> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        decoration: widget.decoration ??
            InputDecoration(
              labelText: widget.labelText,
              border: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        autovalidateMode: widget.autovalidateMode,
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autoFillHints,
        focusNode: widget.focusNode,
        textInputAction: widget.textInputAction ?? TextInputAction.next,
        initialValue: widget.initialValue,
        textCapitalization: widget.keyboardType == TextInputType.name
            ? TextCapitalization.words
            : TextCapitalization.none,
        onChanged: widget.onChanged,
        onFieldSubmitted: (_) {
          FocusScope.of(context).nextFocus();
          widget.onFieldSubmitted?.call(_);
        },
        obscureText: widget.obscureText,
        maxLines: widget.maxLines,
        onSaved: widget.onSaved,
        validator: widget.validator ??
            (value) {
              if (value?.isEmpty ?? true) {
                return widget.labelText != null
                    ? 'برجاء ملئ ${widget.labelText!}'
                    : 'هذا الحقل مطلوب';
              }
              return null;
            },
      ),
    );
  }
}
