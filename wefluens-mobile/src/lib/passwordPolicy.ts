/**
 * Shared password-strength policy — used at every password entry point
 * (sign-up, forced change, voluntary change, recovery). Keeps the rule in one
 * place so all four screens stay in lock-step.
 *
 * Rule: at least 8 characters AND an uppercase letter AND a lowercase letter
 * AND a digit AND a special character (any non-alphanumeric).
 */

const MIN_LENGTH = 8;

/**
 * Returns an i18n KEY describing why `pw` is too weak, or null when it passes.
 * Callers render the key with t(...). A single message covers the whole rule so
 * the UI never leaks which specific class is missing.
 */
export function passwordStrengthError(pw: string): string | null {
  const longEnough = pw.length >= MIN_LENGTH;
  const hasUpper = /[A-Z]/.test(pw);
  const hasLower = /[a-z]/.test(pw);
  const hasDigit = /[0-9]/.test(pw);
  const hasSpecial = /[^A-Za-z0-9]/.test(pw);
  if (longEnough && hasUpper && hasLower && hasDigit && hasSpecial) return null;
  return 'authErrPasswordWeak';
}
