import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:vsc_datetime_field/datetime_parser.dart';

final _yearSuffixRegexp = RegExp(r'[-/]y+');

const _timePatterns24h = [
  'H',
  'H:m',
  'H:m:s',
  'H:m:s.S',
];

const _timePatternsAmPm = [
  'h a',
  'ha',
  'h:m a',
  'h:ma',
  'h:m:s a',
  'h:m:sa',
  'h:m:s.S a',
  'h:m:s.Sa',
];

enum VscDatetimeFieldType { date, datetime, time }

class VscDatetimeField extends StatefulWidget {
  /// Type of field desired.
  final VscDatetimeFieldType type;

  /// Determine the [PickerBox]'s direction.
  ///
  /// If [AxisDirection.down], the [PickerBox] will be below the [TextField]
  /// and the [PickerBox] will grow **down**.
  ///
  /// If [AxisDirection.up], the [PickerBox] will be above the [TextField]
  /// and the [PickerBox] will grow **up**.
  ///
  /// [AxisDirection.left] and [AxisDirection.right] are not allowed.
  final AxisDirection direction;

  /// The configuration of the [TextField](https://docs.flutter.io/flutter/material/TextField-class.html)
  /// that the VscDatetimeField widget displays
  final TextFieldConfiguration textFieldConfiguration;

  /// How far below the text field should the Picker Box be
  ///
  /// Defaults to 5.0
  final double pickerVerticalOffset;

  /// If set to true, in the case where the Picker Box has less than
  /// _PickerBox.minOverlaySpace to grow in the desired [direction], the direction axis
  /// will be temporarily flipped if there's more room available in the opposite
  /// direction.
  ///
  /// Defaults to true
  final bool autoFlipDirection;

  final void Function(DateTime? value)? onValueChanged;

  final void Function(String errorText)? onError;

  final bool readOnly;

  /// [DateFormat]s to be used in parsing user-entered dates or date-times, in order of precedence.
  late final List<DateFormat> parserFormats;

  late final DateFormat textFormat;

  /// Minimum value to limit input/picker. Defaults to 1900-01-01T00:00:00.000.
  late final DateTime minValue;

  /// Minimum value to limit input/picker. Defaults to 3000-01-01T23:59:59.999.
  late final DateTime maxValue;

  /// Controls the value in the datetime field dynamically. Setting the value on this
  /// controller externally will cause the field to be updated. It is also used to
  /// set the initial value.
  late final ValueNotifier<DateTime?>? valueController;

  VscDatetimeField({
    Key? key,
    this.type = VscDatetimeFieldType.date,
    this.pickerVerticalOffset = 5.0,
    this.direction = AxisDirection.down,
    this.textFieldConfiguration = const TextFieldConfiguration(),
    this.autoFlipDirection = true,
    this.onValueChanged,
    this.onError,
    this.readOnly = false,
    this.valueController,
    DateTime? minValue,
    DateTime? maxValue,
    List<DateFormat>? parserFormats,
    DateFormat? textFormat,
  }) : super(key: key) {
    // Make sure date or time components are truncated so validation is reliable.
    this.minValue = _truncateBasedOnType(
        minValue ?? DateTime.parse('1900-01-01T00:00:00.000'))!;
    this.maxValue = _truncateBasedOnType(
        maxValue ?? DateTime.parse('3000-01-01T23:59:59.999'))!;
    assert(this.minValue.isBefore(this.maxValue) ||
        this.minValue == this.maxValue);

    if (textFormat != null) {
      this.textFormat = textFormat;
    } else {
      switch (type) {
        case VscDatetimeFieldType.date:
          this.textFormat = DateFormat.yMd();
          break;

        case VscDatetimeFieldType.datetime:
          this.textFormat = DateFormat.yMd().add_jm();
          break;

        case VscDatetimeFieldType.time:
          this.textFormat = DateFormat.jm();
          break;
      }
    }

    if (parserFormats != null) {
      this.parserFormats = parserFormats;
    } else {
      if (type == VscDatetimeFieldType.date ||
          type == VscDatetimeFieldType.datetime) {
        final defaultDateFmt = DateFormat.yMd();
        // Make a date format which exclude any year suffix - e.g., "M/d/y" becomes "M/d"
        final defaultDateFmtLessYear = DateFormat(
            defaultDateFmt.pattern?.replaceFirst(_yearSuffixRegexp, ''));
        final dateFormats = [
          defaultDateFmt,
          defaultDateFmtLessYear,
          // Date format separating month/day with space, e.g., "M/d" -> "M d", which allows for "Mar 3"
          DateFormat(defaultDateFmtLessYear.pattern?.replaceFirst('/', ' ')),
          // Date format separating month/day with space and [space] year with comma, e.g., "M/d/y" -> "M d, y", which allows for "Mar 3, 2022"
          DateFormat(defaultDateFmt.pattern
              ?.replaceFirst('/', ' ')
              .replaceFirst('/', ', ')),
          DateFormat(defaultDateFmt.pattern
              ?.replaceFirst('/', ' ')
              .replaceFirst('/', ',')),
        ];

        if (type == VscDatetimeFieldType.datetime) {
          final defaultDatetimeFmt = DateFormat.yMd().add_jm();
          final hasAmPm = defaultDatetimeFmt.pattern?.contains('a') ?? false;
          final dateTimeFormats = <DateFormat>[];
          dateTimeFormats.addAll(dateFormats);
          for (final dateFmt in dateFormats) {
            for (final timePattern in _timePatterns24h) {
              dateTimeFormats
                  .add(DateFormat(dateFmt.pattern).addPattern(timePattern));
            }

            if (hasAmPm) {
              for (final timePattern in _timePatternsAmPm) {
                dateTimeFormats
                    .add(DateFormat(dateFmt.pattern).addPattern(timePattern));
              }
            }
          }

          dateTimeFormats.add(defaultDatetimeFmt);
          this.parserFormats = dateTimeFormats;
        } else {
          // type == VscDatetimeFieldType.date
          this.parserFormats = dateFormats;
        }
      } else {
        // type == VscDatetimeFieldType.time
        final defaultTimeFmt = DateFormat.jm();
        final hasAmPm = defaultTimeFmt.pattern?.contains('a') ?? false;
        final timeFormats = <DateFormat>[];
        for (final timePattern in _timePatterns24h) {
          timeFormats.add(DateFormat(timePattern));
        }

        if (hasAmPm) {
          for (final timePattern in _timePatternsAmPm) {
            timeFormats.add(DateFormat(timePattern));
          }
        }

        this.parserFormats = timeFormats;
      }
    }
  }

  @override
  State<VscDatetimeField> createState() => VscDatetimeFieldState();

  DateTime? _truncateBasedOnType(DateTime? value) {
    if (value == null) return value;

    // Truncate date or time parts if they don't apply.
    if (type == VscDatetimeFieldType.date) {
      return DateTime(value.year, value.month, value.day);
    }

    if (type == VscDatetimeFieldType.time) {
      return DateTime(0, 1, 1, value.hour, value.minute, value.second,
          value.millisecond, value.microsecond);
    }

    return value;
  }
}

class VscDatetimeFieldState extends State<VscDatetimeField> {
  late final FocusNode _focusNode =
      FocusNode(debugLabel: 'VscDatetimeFieldState');
  late final TextEditingController _textEditingController =
      TextEditingController();

  TextEditingController get _effectiveController =>
      widget.textFieldConfiguration.controller ?? _textEditingController;

  FocusNode get _effectiveFocusNode =>
      widget.textFieldConfiguration.focusNode ?? _focusNode;
  late VoidCallback _focusNodeListener;

  final _textFieldGlobalKey = GlobalKey();

  DateTime? _value;
  String? _internalErrorText;
  String? get internalValidationErrorMsg => _internalErrorText;

  @override
  void initState() {
    super.initState();

    final initialValue = widget.valueController?.value;
    _setValue(initialValue, setText: true, notify: false);
    widget.valueController?.addListener(_valueControllerListener);

    _focusNodeListener = () {
      if (!_effectiveFocusNode.hasFocus) {
        // Reformat text from value, only if no error.
        if (_internalErrorText == null) {
          _setValue(_value, setText: true);
        }
      }
    };

    _effectiveFocusNode.addListener(_focusNodeListener);
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_focusNodeListener);
    _focusNode.dispose();
    _textEditingController.dispose();
    widget.valueController?.removeListener(_valueControllerListener);
    super.dispose();
  }

  void _valueControllerListener() {
    // Only set the text if we don't have focus
    _setValue(widget.valueController?.value,
        setText: !_effectiveFocusNode.hasFocus, notify: false);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: _textFieldGlobalKey,
      focusNode: _effectiveFocusNode,
      controller: _effectiveController,
      decoration: widget.textFieldConfiguration.decoration.copyWith(
        // Only set errorText if there's no error widget already provided
        errorText: widget.textFieldConfiguration.decoration.error == null
            ? (_internalErrorText ??
                widget.textFieldConfiguration.decoration.errorText)
            : null,
        suffixIcon: Semantics(
          identifier: 'id_datetime_field_suffix_icon',
          child: InkResponse(
            radius: 24,
            canRequestFocus: false,
            onTap: widget.readOnly ? null : _openPicker,
            child: Icon(widget.type == VscDatetimeFieldType.time
                ? Icons.access_time_outlined
                : Icons.event_outlined),
          ),
        ),
        // suffixIcon: Row(
        //   mainAxisSize: MainAxisSize.min,
        //   children: [
        //     if (_value != null && !widget.readOnly)
        //       InkResponse(
        //         radius: 24,
        //         child: const Icon(Icons.clear_outlined),
        //         onTap: () => _setValue(null, setText: true),
        //       ),
        //     const SizedBox(width: 8),
        //     InkResponse(
        //       radius: 24,
        //       canRequestFocus: false,
        //       onTap: widget.readOnly ? null : _openPicker,
        //       child: Icon(widget.type == VscDatetimeFieldType.time
        //           ? Icons.access_time_outlined
        //           : Icons.event_outlined),
        //     )
        //   ],
        // ),
      ),
      style: widget.textFieldConfiguration.style,
      textAlign: widget.textFieldConfiguration.textAlign,
      enabled: widget.textFieldConfiguration.enabled,
      keyboardType: widget.textFieldConfiguration.keyboardType,
      autofocus: widget.textFieldConfiguration.autofocus,
      inputFormatters: widget.textFieldConfiguration.inputFormatters,
      autocorrect: widget.textFieldConfiguration.autocorrect,
      maxLines: widget.textFieldConfiguration.maxLines,
      textAlignVertical: widget.textFieldConfiguration.textAlignVertical,
      minLines: widget.textFieldConfiguration.minLines,
      maxLength: widget.textFieldConfiguration.maxLength,
      maxLengthEnforcement: widget.textFieldConfiguration.maxLengthEnforcement,
      obscureText: widget.textFieldConfiguration.obscureText,
      onChanged: _onTextChanged,
      onSubmitted: widget.textFieldConfiguration.onSubmitted,
      onEditingComplete: widget.textFieldConfiguration.onEditingComplete,
      onTap: widget.textFieldConfiguration.onTap,
      scrollPadding: widget.textFieldConfiguration.scrollPadding,
      textInputAction: widget.textFieldConfiguration.textInputAction,
      textCapitalization: widget.textFieldConfiguration.textCapitalization,
      keyboardAppearance: widget.textFieldConfiguration.keyboardAppearance,
      cursorWidth: widget.textFieldConfiguration.cursorWidth,
      cursorRadius: widget.textFieldConfiguration.cursorRadius,
      cursorColor: widget.textFieldConfiguration.cursorColor,
      textDirection: widget.textFieldConfiguration.textDirection,
      enableInteractiveSelection:
          widget.textFieldConfiguration.enableInteractiveSelection,
      readOnly: widget.readOnly,
    );
  }

  Future<void> _openPicker() async {
    switch (widget.type) {
      case VscDatetimeFieldType.date:
        final selected = await _showCustomizedDatePicker();
        _effectiveFocusNode.requestFocus();

        if (selected != null) {
          // Modify the field's DateTime date component.
          final currValue = _value ?? testableNow();
          _setValue(
            DateTime(
              selected.year,
              selected.month,
              selected.day,
              currValue.hour,
              currValue.minute,
              currValue.second,
              currValue.millisecond,
              currValue.microsecond,
            ),
            setTextAndMoveCursorToEnd: true,
          );
        }
        break;
      case VscDatetimeFieldType.datetime:
        final selectedDate = await _showCustomizedDatePicker();
        if (selectedDate == null) break;

        var selectedTime = await _showCustomizedTimePicker();
        _effectiveFocusNode.requestFocus();

        selectedTime ??= _value == null
            ? const TimeOfDay(hour: 0, minute: 0)
            : TimeOfDay.fromDateTime(_value!);

        _setValue(
          DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
            0,
            0,
            0,
          ),
          setTextAndMoveCursorToEnd: true,
        );
        break;

      case VscDatetimeFieldType.time:
        final selected = await _showCustomizedTimePicker();
        _effectiveFocusNode.requestFocus();

        if (selected != null) {
          // Modify the field's DateTime time component.
          final currValue = _value ?? testableNow();
          _setValue(
            DateTime(
              currValue.year,
              currValue.month,
              currValue.day,
              selected.hour,
              selected.minute,
              0,
              0,
              0,
            ),
            setTextAndMoveCursorToEnd: true,
          );
        }
        break;
    }
  }

  Future<TimeOfDay?> _showCustomizedTimePicker() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _value == null
          ? const TimeOfDay(hour: 12, minute: 0) // Default to 12pm
          : TimeOfDay.fromDateTime(_value!),
      builder: (context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    return selected;
  }

  Future<DateTime?> _showCustomizedDatePicker() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _value ?? testableNow(),
      firstDate: widget.minValue,
      lastDate: widget.maxValue,
    );
    return selected;
  }

  void _setValue(
    DateTime? newValue, {
    bool setText = false,
    bool setTextAndMoveCursorToEnd = false,
    bool notify = true,
  }) {
    _internalErrorText = null;
    newValue = widget._truncateBasedOnType(newValue);
    if (newValue != null) {
      // Validate between min and max
      if (newValue.isBefore(widget.minValue)) {
        _setErrorText(
            'Must be on or after ${widget.textFormat.format(widget.minValue)}');
        return;
      }

      if (newValue.isAfter(widget.maxValue)) {
        _setErrorText(
            'Must be on or before ${widget.textFormat.format(widget.maxValue)}');
        return;
      }
    }

    _value = newValue;

    if (setText || setTextAndMoveCursorToEnd) {
      final newValue = _value == null ? '' : widget.textFormat.format(_value!);
      _effectiveController.value = _effectiveController.value.copyWith(
        text: newValue,
        selection: setTextAndMoveCursorToEnd
            ? TextSelection.collapsed(offset: newValue.length)
            : null,
      );
    }
    setState(() {});

    if (notify && widget.onValueChanged != null) {
      widget.onValueChanged!(_value);
    }
  }

  void _onTextChanged(String textValue) {
    _internalErrorText = null;
    textValue = textValue.trim();
    if (textValue.isEmpty) {
      _setValue(null, setText: false);
      return;
    }

    try {
      final newValue =
          parseDateTime(textValue, parserFormats: widget.parserFormats);
      _setValue(newValue, setText: false);
    } catch (e) {
      _setErrorText('Invalid value');
    }
  }

  void _setErrorText(String errorText) {
    setState(() => _internalErrorText = errorText);
    widget.onError?.call(errorText);
  }
}

/// Supply an instance of this class to the [VscDatetimeField.textFieldConfiguration]
/// property to configure the displayed text field
class TextFieldConfiguration {
  /// The decoration to show around the text field.
  ///
  /// Same as [TextField.decoration](https://docs.flutter.io/flutter/material/TextField/decoration.html)
  final InputDecoration decoration;

  /// Controls the text being edited.
  ///
  /// If null, this widget will create its own [TextEditingController](https://docs.flutter.io/flutter/widgets/TextEditingController-class.html).
  /// A typical use case for this field in the VscDatetimeField widget is to set the
  /// text of the widget when a date is selected. For example:
  ///
  /// ```dart
  /// final _controller = TextEditingController();
  /// ...
  /// ...
  /// VscDatetimeField(
  ///   controller: _controller,
  ///   ...
  ///   ...
  /// )
  /// ```
  final TextEditingController? controller;

  /// Controls whether this widget has keyboard focus.
  ///
  /// Same as [TextField.focusNode](https://docs.flutter.io/flutter/material/TextField/focusNode.html)
  final FocusNode? focusNode;

  /// The style to use for the text being edited.
  ///
  /// Same as [TextField.style](https://docs.flutter.io/flutter/material/TextField/style.html)
  final TextStyle? style;

  /// How the text being edited should be aligned horizontally.
  ///
  /// Same as [TextField.textAlign](https://docs.flutter.io/flutter/material/TextField/textAlign.html)
  final TextAlign textAlign;

  /// Same as [TextField.textDirection](https://docs.flutter.io/flutter/material/TextField/textDirection.html)
  ///
  /// Defaults to null
  final TextDirection? textDirection;

  /// Same as [TextField.textAlignVertical](https://api.flutter.dev/flutter/material/TextField/textAlignVertical.html)
  final TextAlignVertical? textAlignVertical;

  /// If false the textfield is "disabled": it ignores taps and its
  /// [decoration] is rendered in grey.
  ///
  /// Same as [TextField.enabled](https://docs.flutter.io/flutter/material/TextField/enabled.html)
  final bool enabled;

  /// The type of keyboard to use for editing the text.
  ///
  /// Same as [TextField.keyboardType](https://docs.flutter.io/flutter/material/TextField/keyboardType.html)
  final TextInputType keyboardType;

  /// Whether this text field should focus itself if nothing else is already
  /// focused.
  ///
  /// Same as [TextField.autofocus](https://docs.flutter.io/flutter/material/TextField/autofocus.html)
  final bool autofocus;

  /// Optional input validation and formatting overrides.
  ///
  /// Same as [TextField.inputFormatters](https://docs.flutter.io/flutter/material/TextField/inputFormatters.html)
  final List<TextInputFormatter>? inputFormatters;

  /// Whether to enable autocorrection.
  ///
  /// Same as [TextField.autocorrect](https://docs.flutter.io/flutter/material/TextField/autocorrect.html)
  final bool autocorrect;

  /// The maximum number of lines for the text to span, wrapping if necessary.
  ///
  /// Same as [TextField.maxLines](https://docs.flutter.io/flutter/material/TextField/maxLines.html)
  final int? maxLines;

  /// The minimum number of lines to occupy when the content spans fewer lines.
  ///
  /// Same as [TextField.minLines](https://docs.flutter.io/flutter/material/TextField/minLines.html)
  final int? minLines;

  /// The maximum number of characters (Unicode scalar values) to allow in the
  /// text field.
  ///
  /// Same as [TextField.maxLength](https://docs.flutter.io/flutter/material/TextField/maxLength.html)
  final int? maxLength;

  /// If true, prevents the field from allowing more than [maxLength]
  /// characters.
  ///
  /// Same as [TextField.maxLengthEnforcement](https://api.flutter.dev/flutter/material/TextField/maxLengthEnforcement.html)
  final MaxLengthEnforcement? maxLengthEnforcement;

  /// Whether to hide the text being edited (e.g., for passwords).
  ///
  /// Same as [TextField.obscureText](https://docs.flutter.io/flutter/material/TextField/obscureText.html)
  final bool obscureText;

  /// Called when the text being edited changes.
  ///
  /// Same as [TextField.onChanged](https://docs.flutter.io/flutter/material/TextField/onChanged.html)
  final ValueChanged<String>? onChanged;

  /// Called when the user indicates that they are done editing the text in the
  /// field.
  ///
  /// Same as [TextField.onSubmitted](https://docs.flutter.io/flutter/material/TextField/onSubmitted.html)
  final ValueChanged<String>? onSubmitted;

  /// The color to use when painting the cursor.
  ///
  /// Same as [TextField.cursorColor](https://docs.flutter.io/flutter/material/TextField/cursorColor.html)
  final Color? cursorColor;

  /// How rounded the corners of the cursor should be. By default, the cursor has a null Radius
  ///
  /// Same as [TextField.cursorRadius](https://docs.flutter.io/flutter/material/TextField/cursorRadius.html)
  final Radius? cursorRadius;

  /// How thick the cursor will be.
  ///
  /// Same as [TextField.cursorWidth](https://docs.flutter.io/flutter/material/TextField/cursorWidth.html)
  final double cursorWidth;

  /// The appearance of the keyboard.
  ///
  /// Same as [TextField.keyboardAppearance](https://docs.flutter.io/flutter/material/TextField/keyboardAppearance.html)
  final Brightness? keyboardAppearance;

  /// Called when the user submits editable content (e.g., user presses the "done" button on the keyboard).
  ///
  /// Same as [TextField.onEditingComplete](https://docs.flutter.io/flutter/material/TextField/onEditingComplete.html)
  final VoidCallback? onEditingComplete;

  /// Called for each distinct tap except for every second tap of a double tap.
  ///
  /// Same as [TextField.onTap](https://docs.flutter.io/flutter/material/TextField/onTap.html)
  final GestureTapCallback? onTap;

  /// Configures padding to edges surrounding a Scrollable when the Textfield scrolls into view.
  ///
  /// Same as [TextField.scrollPadding](https://docs.flutter.io/flutter/material/TextField/scrollPadding.html)
  final EdgeInsets scrollPadding;

  /// Configures how the platform keyboard will select an uppercase or lowercase keyboard.
  ///
  /// Same as [TextField.TextCapitalization](https://docs.flutter.io/flutter/material/TextField/textCapitalization.html)
  final TextCapitalization textCapitalization;

  /// The type of action button to use for the keyboard.
  ///
  /// Same as [TextField.textInputAction](https://docs.flutter.io/flutter/material/TextField/textInputAction.html)
  final TextInputAction? textInputAction;

  final bool enableInteractiveSelection;

  /// Creates a TextFieldConfiguration
  const TextFieldConfiguration({
    this.decoration = const InputDecoration(),
    this.style,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.maxLengthEnforcement,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.textAlignVertical,
    this.autocorrect = true,
    this.inputFormatters,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.focusNode,
    this.cursorColor,
    this.cursorRadius,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.cursorWidth = 2.0,
    this.keyboardAppearance,
    this.onEditingComplete,
    this.onTap,
    this.textDirection,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.enableInteractiveSelection = true,
  });

  /// Copies the [TextFieldConfiguration] and only changes the specified
  /// properties
  TextFieldConfiguration copyWith(
      {InputDecoration? decoration,
      TextStyle? style,
      TextEditingController? controller,
      ValueChanged<String>? onChanged,
      ValueChanged<String>? onSubmitted,
      bool? obscureText,
      MaxLengthEnforcement? maxLengthEnforcement,
      int? maxLength,
      int? maxLines,
      int? minLines,
      bool? autocorrect,
      List<TextInputFormatter>? inputFormatters,
      bool? autofocus,
      TextInputType? keyboardType,
      bool? enabled,
      TextAlign? textAlign,
      FocusNode? focusNode,
      Color? cursorColor,
      TextAlignVertical? textAlignVertical,
      Radius? cursorRadius,
      double? cursorWidth,
      Brightness? keyboardAppearance,
      VoidCallback? onEditingComplete,
      GestureTapCallback? onTap,
      EdgeInsets? scrollPadding,
      TextCapitalization? textCapitalization,
      TextDirection? textDirection,
      TextInputAction? textInputAction,
      bool? enableInteractiveSelection}) {
    return TextFieldConfiguration(
      decoration: decoration ?? this.decoration,
      style: style ?? this.style,
      controller: controller ?? this.controller,
      onChanged: onChanged ?? this.onChanged,
      onSubmitted: onSubmitted ?? this.onSubmitted,
      obscureText: obscureText ?? this.obscureText,
      maxLengthEnforcement: maxLengthEnforcement ?? this.maxLengthEnforcement,
      maxLength: maxLength ?? this.maxLength,
      maxLines: maxLines ?? this.maxLines,
      minLines: minLines ?? this.minLines,
      autocorrect: autocorrect ?? this.autocorrect,
      inputFormatters: inputFormatters ?? this.inputFormatters,
      autofocus: autofocus ?? this.autofocus,
      keyboardType: keyboardType ?? this.keyboardType,
      enabled: enabled ?? this.enabled,
      textAlign: textAlign ?? this.textAlign,
      textAlignVertical: textAlignVertical ?? this.textAlignVertical,
      focusNode: focusNode ?? this.focusNode,
      cursorColor: cursorColor ?? this.cursorColor,
      cursorRadius: cursorRadius ?? this.cursorRadius,
      cursorWidth: cursorWidth ?? this.cursorWidth,
      keyboardAppearance: keyboardAppearance ?? this.keyboardAppearance,
      onEditingComplete: onEditingComplete ?? this.onEditingComplete,
      onTap: onTap ?? this.onTap,
      scrollPadding: scrollPadding ?? this.scrollPadding,
      textCapitalization: textCapitalization ?? this.textCapitalization,
      textInputAction: textInputAction ?? this.textInputAction,
      textDirection: textDirection ?? this.textDirection,
      enableInteractiveSelection:
          enableInteractiveSelection ?? this.enableInteractiveSelection,
    );
  }
}
