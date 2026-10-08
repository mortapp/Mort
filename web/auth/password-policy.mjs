// UTF-16 length deliberately matches Dart String.length and provider UI bounds.
export function validPassword(value) {
  return typeof value === 'string' && value.length >= 12 && value.length <= 128 &&
    /[A-Z]/.test(value) && /[a-z]/.test(value) && /[0-9]/.test(value) && /[^A-Za-z0-9]/.test(value);
}
