/// Confirmation is an intent, not the spelling of a new name.
bool acceptsProfileName(String answer) {
  final value = answer.toLowerCase().replaceAll(RegExp(r"[,!.?]"), '').trim();
  if (RegExp(
    r"\b(no|not|don't|dont|different|another|instead|but|change|call me)\b",
  ).hasMatch(value)) {
    return false;
  }
  return RegExp(
        r"^(yes|yeah|yep|sure|okay|ok|absolutely|certainly|correct)\b",
      ).hasMatch(value) ||
      RegExp(
        r"^(you can |please )?(use|keep) (the |my |this |that )?(same name|profile name|name|it)$",
      ).hasMatch(value) ||
      RegExp(
        r"^(same name|that's right|that's correct|that is correct)$",
      ).hasMatch(value);
}

/// Only a short acknowledgement can bypass interpretation. Keep any volunteered facts.
bool isOnlyProfileNameConfirmation(String answer) {
  final value = answer.toLowerCase().replaceAll(RegExp(r"[,!.?]"), '').trim();
  return RegExp(
    r"^(?:(?:yes|yeah|yep|sure|okay|ok|absolutely|certainly|correct)(?: please)?(?: (?:you can |please )?(?:use|keep) (?:the |my |this |that )?(?:same name|profile name|name|it)| that works)?|(?:you can |please )?(?:use|keep) (?:the |my |this |that )?(?:same name|profile name|name|it)|same name|that's right|that's correct|that is correct)$",
  ).hasMatch(value);
}
