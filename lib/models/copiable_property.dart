import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:url_launcher/url_launcher.dart';

class CopiableProperty extends StatelessWidget {
  const CopiableProperty(this.name, this.value, {Key key, this.items})
      : assert(name != null),
        super(key: key);

  final String name;
  final String value;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      subtitle: Text(value ?? ''),
      trailing: items != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                value != null && value.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.copy),
                        tooltip: 'نسخ',
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: value)),
                      )
                    : IconButton(
                        icon: Icon(Icons.warning),
                        tooltip: 'بيانات غير كاملة',
                        onPressed: null,
                        color: Colors.red,
                      ),
                ...items,
              ],
            )
          : value != null && value.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.copy),
                  tooltip: 'نسخ',
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: value)),
                )
              : IconButton(
                  icon: Icon(Icons.warning),
                  tooltip: 'بيانات غير كاملة',
                  onPressed: null,
                  color: Colors.red,
                ),
    );
  }
}

class PhoneNumberProperty extends StatelessWidget {
  const PhoneNumberProperty(this.name, this.value, this.phoneCall, {Key key})
      : super(key: key);

  final String name;
  final String value;
  final void Function(String) phoneCall;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      subtitle: Text(value ?? ''),
      trailing: value != null && value.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.phone),
                  tooltip: 'اجراء مكالمة',
                  onPressed: () => phoneCall(value),
                ),
                IconButton(
                  icon: Image.asset('assets/whatsapp.png',
                      width: IconTheme.of(context).size,
                      height: IconTheme.of(context).size,
                      color: Theme.of(context).iconTheme.color),
                  tooltip: 'ارسال رسالة (واتساب)',
                  onPressed: () =>
                      launch('whatsapp://send?phone=+' + getPhone(value)),
                ),
                IconButton(
                  icon: Icon(Icons.message),
                  tooltip: 'ارسال رسالة',
                  onPressed: () => launch('sms://' + getPhone(value, false)),
                ),
                IconButton(
                  icon: Icon(Icons.copy),
                  tooltip: 'نسخ',
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: value)),
                ),
              ],
            )
          : IconButton(
              icon: Icon(Icons.warning),
              tooltip: 'بيانات غير كاملة',
              onPressed: null,
              color: Colors.red,
            ),
    );
  }
}
