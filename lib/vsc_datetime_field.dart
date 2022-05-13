import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:vsc_datetime_field/datetime_parser.dart';

final _kbdSupportedPlatform = (kIsWeb || Platform.isAndroid || Platform.isIOS);

// Unfortunately stolen from flutter/lib/src/material/calendar_date_picker.dart
const double _dayPickerRowHeight = 42.0;
const int _maxDayPickerRowCount = 6; // A 31 day month that starts on Saturday.
// One extra row for the day-of-week header.
const double _maxDayPickerHeight =
    _dayPickerRowHeight * (_maxDayPickerRowCount + 1);
// Value is from flutter/lib/src/material/date_picker.dart:
const _pickerWidth = 330.0;

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
/*
 * TODO
 *  - Sometimes there's just not enough room with the kbd open on mobile. Don't show any picker in this case.
 *    But if the mobile kbd closes, recalculate available size
 *  - Sometimes on mobile the screen doesn't scroll with the kbd up, even though the example has a scroll widget,
 *    it doesn't have enough height to perform scrolling.
 *  - Maybe on mobile if there is not enough height, don't show the picker but if the calendar icon is tapped,
 *    show the dialog instead.
 */

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
  /// _PickerBoxController.minOverlaySpace to grow in the desired [direction], the direction axis
  /// will be temporarily flipped if there's more room available in the opposite
  /// direction.
  ///
  /// Defaults to true
  final bool autoFlipDirection;

  final void Function(DateTime? value)? onValueChanged;

  final bool readOnly;

  final DateTime? initialValue;

  /// [DateFormat]s to be used in parsing user-entered dates or date-times, in order of precedence.
  late final List<DateFormat> parserFormats;

  late final DateFormat textFormat;

  // Minimum and maximum value to limit input/picker.
  late final DateTime? minValue;
  late final DateTime? maxValue;

  VscDatetimeField({
    Key? key,
    this.type = VscDatetimeFieldType.date,
    this.pickerVerticalOffset = 5.0,
    this.direction = AxisDirection.down,
    this.textFieldConfiguration = const TextFieldConfiguration(),
    this.autoFlipDirection = true,
    this.onValueChanged,
    this.readOnly = false,
    this.initialValue,
    DateTime? minValue,
    DateTime? maxValue,
    List<DateFormat>? parserFormats,
    DateFormat? textFormat,
  }) : super(key: key) {
    // Make sure date or time components are truncated so validation is reliable.
    this.minValue = _truncateBasedOnType(minValue);
    this.maxValue = _truncateBasedOnType(maxValue);

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
  State<VscDatetimeField> createState() => _VscDatetimeFieldState();

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

class _VscDatetimeFieldState extends State<VscDatetimeField> {
  late final FocusNode _focusNode = FocusNode();
  late final TextEditingController _textEditingController =
      TextEditingController();
  late final _PickerBox _pickerBox;

  TextEditingController get _effectiveController =>
      widget.textFieldConfiguration.controller ?? _textEditingController;

  FocusNode get _effectiveFocusNode =>
      widget.textFieldConfiguration.focusNode ?? _focusNode;
  late VoidCallback _focusNodeListener;

  final LayerLink _layerLink = LayerLink();

  // Keyboard detection
  final Stream<bool>? _keyboardVisibility =
      (_kbdSupportedPlatform) ? KeyboardVisibilityController().onChange : null;
  late StreamSubscription<bool>? _keyboardVisibilitySubscription;

  final _textFieldGlobalKey = GlobalKey();

  DateTime? _value;
  String? _internalErrorText;

  @override
  void initState() {
    super.initState();

    _setValue(widget.initialValue, setText: true, notify: false);
    _pickerBox =
        _PickerBox(context, widget.direction, widget.autoFlipDirection);

    _focusNodeListener = () {
      if (_effectiveFocusNode.hasFocus) {
        _pickerBox.open();
      } else {
        // Reformat text from value, only if no error.
        if (_internalErrorText == null) {
          _setValue(_value, setText: true);
        }

        _pickerBox.close();
      }
    };

    _effectiveFocusNode.addListener(_focusNodeListener);

    // If the keyboard is hidden on mobile, recalculate available size
    _keyboardVisibilitySubscription =
        _keyboardVisibility?.listen((bool isVisible) {
      _pickerBox.resize();
    });

    WidgetsBinding.instance.addPostFrameCallback((duration) {
      if (mounted) {
        _initOverlayEntry();
        // calculate initial picker box size
        _pickerBox.resize();

        // in case we already missed the focus event
        if (_effectiveFocusNode.hasFocus) {
          _pickerBox.open();
        }
      }
    });
  }

  @override
  void dispose() {
    _pickerBox.close();
    _pickerBox.widgetMounted = false;
    _keyboardVisibilitySubscription?.cancel();
    _effectiveFocusNode.removeListener(_focusNodeListener);
    _focusNode.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  void _initOverlayEntry() {
    if (widget.type == VscDatetimeFieldType.time) {
      // Time fields don't have a picker currently.
      return;
    }

    _pickerBox._overlayEntry = OverlayEntry(builder: (context) {
      final picker = Card(
        child: CalendarDatePicker(
          initialDate: _value ?? DateTime.now(),
          firstDate: widget.minValue ?? DateTime.parse('1900-01-01'),
          lastDate: widget.maxValue ?? DateTime.parse('3000-01-01'),
          onDateChanged: (DateTime newValue) {
            // Modify the field's DateTime, sans the time component.
            final currValue = _value ?? DateTime.now();
            _setValue(
              DateTime(
                newValue.year,
                newValue.month,
                newValue.day,
                currValue.hour,
                currValue.minute,
                currValue.second,
                currValue.millisecond,
                currValue.microsecond,
              ),
              setText: true,
            );
          },
        ),
      );

      final renderBox =
          _textFieldGlobalKey.currentContext?.findRenderObject() as RenderBox?;
      var pickerX = 0.0;
      if (renderBox != null) {
        // If text field position would cause picker to appear off right edge, slide it left.
        final screenWidth = MediaQuery.of(context).size.width;
        final globalFieldPosition = renderBox.localToGlobal(Offset.zero);
        if ((globalFieldPosition.dx + _pickerWidth) > screenWidth) {
          pickerX = renderBox
              .globalToLocal(
                  Offset(screenWidth - _pickerWidth, globalFieldPosition.dy))
              .dx;
        }
      }

      // TODO If it won't fit below, try above (automatically done), then left or right. We can control the width somewhat.
      //   Or, if no room, don't display it.
      const overlayWidth = _pickerWidth;
      var above = _pickerBox.direction == AxisDirection.up;
      var pickerY = !above
          ? _pickerBox.textBoxHeight + widget.pickerVerticalOffset
          : _pickerBox.directionUpOffset;

      return Positioned(
        width: overlayWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(pickerX, pickerY),
          child: !above
              ? picker
              : FractionalTranslation(
                  // visually flips list to go up
                  translation: const Offset(0.0, -1.0),
                  child: picker,
                ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Make sure the pickerBox position is reset in case an error message shows up
    // below the field, or if it goes away. This must be done after the size of
    // this widget is known.
    if (_pickerBox.isOpened) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickerBox.resize();
      });
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _pickerBox.close,
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: TextField(
          key: _textFieldGlobalKey,
          focusNode: _effectiveFocusNode,
          controller: _effectiveController,
          decoration: widget.textFieldConfiguration.decoration.copyWith(
            errorText: _internalErrorText ??
                widget.textFieldConfiguration.decoration.errorText,
            suffixIcon: _value == null || widget.readOnly
                ? InkWell(
                    canRequestFocus: false,
                    child: Icon(widget.type == VscDatetimeFieldType.time
                        ? Icons.access_time_outlined
                        : Icons.event_outlined),
                    onTap: widget.readOnly
                        ? null
                        : () {
                            if (_pickerBox.isOpened) {
                              _pickerBox.close();
                            } else {
                              _pickerBox.open();
                              _effectiveFocusNode.requestFocus();
                            }
                          },
                  )
                : InkWell(
                    child: const Icon(Icons.clear_outlined),
                    onTap: () => _setValue(null, setText: true),
                  ),
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
          maxLengthEnforcement:
              widget.textFieldConfiguration.maxLengthEnforcement,
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
        ),
      ),
    );
  }

  void _setValue(
    DateTime? newValue, {
    bool setText = false,
    bool notify = true,
  }) {
    _internalErrorText = null;
    final oldValue = _value;
    newValue = widget._truncateBasedOnType(newValue);
    if (newValue != null) {
      // Validate between min and max
      if (widget.minValue != null && newValue.isBefore(widget.minValue!)) {
        _setErrorText(
            'Must be on or after ${widget.textFormat.format(widget.minValue!)}');
        return;
      }

      if (widget.maxValue != null && newValue.isAfter(widget.maxValue!)) {
        _setErrorText(
            'Must be on or before ${widget.textFormat.format(widget.maxValue!)}');
        return;
      }
    }

    _value = newValue;

    if (setText) {
      _effectiveController.text =
          _value == null ? '' : widget.textFormat.format(_value!);
      _effectiveController.selection =
          TextSelection.collapsed(offset: _effectiveController.text.length);
    }
    setState(() {});

    if (notify && widget.onValueChanged != null && oldValue != _value) {
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

  void _setErrorText(String errorText) =>
      setState(() => _internalErrorText = errorText);
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

class _PickerBox {
  static const int waitMetricsTimeoutMillis = 1000;
  static const double minOverlaySpace = _maxDayPickerHeight;

  final BuildContext context;
  final AxisDirection desiredDirection;
  final bool autoFlipDirection;

  OverlayEntry? _overlayEntry;
  AxisDirection direction;

  bool isOpened = false;
  bool widgetMounted = true;
  double maxHeight = _maxDayPickerHeight;
  double textBoxWidth = 100.0;
  double textBoxHeight = 100.0;
  late double directionUpOffset;

  _PickerBox(this.context, this.direction, this.autoFlipDirection)
      : desiredDirection = direction;

  void open() {
    final widget = context.widget as VscDatetimeField;
    if (widget.readOnly || isOpened || _overlayEntry == null) return;
    assert(_overlayEntry != null);
    resize();
    Overlay.of(context)!.insert(_overlayEntry!);
    isOpened = true;
  }

  void close() {
    if (!isOpened || _overlayEntry == null) return;
    assert(_overlayEntry != null);
    _overlayEntry!.remove();
    isOpened = false;
  }

  void toggle() {
    if (isOpened) {
      close();
    } else {
      open();
    }
  }

  MediaQuery? _findRootMediaQuery() {
    MediaQuery? rootMediaQuery;
    context.visitAncestorElements((element) {
      if (element.widget is MediaQuery) {
        rootMediaQuery = element.widget as MediaQuery;
      }
      return true;
    });

    return rootMediaQuery;
  }

  /// Delays until the keyboard has toggled or the orientation has fully changed
  Future<bool> _waitChangeMetrics() async {
    if (widgetMounted) {
      // initial viewInsets which are before the keyboard is toggled
      EdgeInsets initial = MediaQuery.of(context).viewInsets;
      // initial MediaQuery for orientation change
      MediaQuery? initialRootMediaQuery = _findRootMediaQuery();

      int timer = 0;
      // viewInsets or MediaQuery have changed once keyboard has toggled or orientation has changed
      while (widgetMounted && timer < waitMetricsTimeoutMillis) {
        // TODO: reduce delay if showDialog ever exposes detection of animation end
        await Future<void>.delayed(const Duration(milliseconds: 170));
        timer += 170;

        if (widgetMounted &&
            (MediaQuery.of(context).viewInsets != initial ||
                _findRootMediaQuery() != initialRootMediaQuery)) {
          return true;
        }
      }
    }

    return false;
  }

  void resize() {
    // check to see if widget is still mounted
    // user may have closed the widget with the keyboard still open
    if (widgetMounted && _overlayEntry != null) {
      _adjustMaxHeightAndOrientation();
      _overlayEntry!.markNeedsBuild();
    }
  }

  // See if there's enough room in the desired direction for the overlay to display
  // correctly. If not, try the opposite direction if things look more roomy there
  void _adjustMaxHeightAndOrientation() {
    VscDatetimeField widget = context.widget as VscDatetimeField;

    RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || box.hasSize == false) {
      return;
    }

    textBoxWidth = box.size.width;
    textBoxHeight = box.size.height;

    // top of text box
    double textBoxAbsY = box.localToGlobal(Offset.zero).dy;

    // height of window
    double windowHeight = MediaQuery.of(context).size.height;

    // we need to find the root MediaQuery for the unsafe area height
    // we cannot use BuildContext.ancestorWidgetOfExactType because
    // widgets like SafeArea creates a new MediaQuery with the padding removed
    MediaQuery rootMediaQuery = _findRootMediaQuery()!;

    // height of keyboard
    double keyboardHeight = rootMediaQuery.data.viewInsets.bottom;

    double maxHDesired = _calculateMaxHeight(desiredDirection, box, widget,
        windowHeight, rootMediaQuery, keyboardHeight, textBoxAbsY);

    // if there's enough room in the desired direction, update the direction and the max height
    if (maxHDesired >= minOverlaySpace || !autoFlipDirection) {
      direction = desiredDirection;
      maxHeight = maxHDesired;
    } else {
      // There's not enough room in the desired direction so see how much room is in the opposite direction
      AxisDirection flipped = flipAxisDirection(desiredDirection);
      double maxHFlipped = _calculateMaxHeight(flipped, box, widget,
          windowHeight, rootMediaQuery, keyboardHeight, textBoxAbsY);

      // if there's more room in this opposite direction, update the direction and maxHeight
      if (maxHFlipped > maxHDesired) {
        direction = flipped;
        maxHeight = maxHFlipped;
      }
    }

    if (maxHeight < 0) maxHeight = 0;
  }

  double _calculateMaxHeight(
      AxisDirection direction,
      RenderBox box,
      VscDatetimeField widget,
      double windowHeight,
      MediaQuery rootMediaQuery,
      double keyboardHeight,
      double textBoxAbsY) {
    return direction == AxisDirection.down
        ? _calculateMaxHeightDown(box, widget, windowHeight, rootMediaQuery,
            keyboardHeight, textBoxAbsY)
        : _calculateMaxHeightUp(box, widget, windowHeight, rootMediaQuery,
            keyboardHeight, textBoxAbsY);
  }

  double _calculateMaxHeightDown(
      RenderBox box,
      VscDatetimeField widget,
      double windowHeight,
      MediaQuery rootMediaQuery,
      double keyboardHeight,
      double textBoxAbsY) {
    // unsafe area, ie: iPhone X 'home button'
    // keyboardHeight includes unsafeAreaHeight, if keyboard is showing, set to 0
    double unsafeAreaHeight =
        keyboardHeight == 0 ? rootMediaQuery.data.padding.bottom : 0;

    return windowHeight -
        keyboardHeight -
        unsafeAreaHeight -
        textBoxHeight -
        textBoxAbsY -
        2 * widget.pickerVerticalOffset;
  }

  double _calculateMaxHeightUp(
      RenderBox box,
      VscDatetimeField widget,
      double windowHeight,
      MediaQuery rootMediaQuery,
      double keyboardHeight,
      double textBoxAbsY) {
    // recalculate keyboard absolute y value
    double keyboardAbsY = windowHeight - keyboardHeight;

    directionUpOffset = textBoxAbsY > keyboardAbsY
        ? keyboardAbsY - textBoxAbsY - widget.pickerVerticalOffset
        : -widget.pickerVerticalOffset;

    // unsafe area, ie: iPhone X notch
    double unsafeAreaHeight = rootMediaQuery.data.padding.top;

    return textBoxAbsY > keyboardAbsY
        ? keyboardAbsY - unsafeAreaHeight - 2 * widget.pickerVerticalOffset
        : textBoxAbsY - unsafeAreaHeight - 2 * widget.pickerVerticalOffset;
  }

  Future<void> onChangeMetrics() async {
    if (await _waitChangeMetrics()) {
      resize();
    }
  }
}

/// Supply an instance of this class to the [VscDatetimeField.pickerBoxController]
/// property to manually control the Picker Box
class PickerBoxController {
  _PickerBox? _pickerBox;
  FocusNode? _effectiveFocusNode;

  /// Opens the Picker Box
  void open() {
    _effectiveFocusNode!.requestFocus();
  }

  bool isOpened() {
    return _pickerBox!.isOpened;
  }

  /// Closes the Picker Box
  void close() {
    _effectiveFocusNode!.unfocus();
  }

  /// Opens the Picker Box if closed and vice-versa
  void toggle() {
    if (_pickerBox!.isOpened) {
      close();
    } else {
      open();
    }
  }

  /// Recalculates the height of the Picker Box
  void resize() {
    _pickerBox!.resize();
  }
}
