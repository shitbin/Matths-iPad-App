#!/bin/sh
set -eu

FORM_TEST_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
FORM_TEST_WORK="$(mktemp -d /tmp/matths-native-social-form.XXXXXX)"
trap 'rm -rf "$FORM_TEST_WORK"' EXIT

swiftc \
  "$FORM_TEST_ROOT/Matths/NativeSocialRegistrationForm.swift" \
  "$FORM_TEST_ROOT/tests/NativeSocialRegistrationFormCases.swift" \
  -o "$FORM_TEST_WORK/form-cases"
"$FORM_TEST_WORK/form-cases"
