// Never return provider text, addresses, credentials or dynamically supplied codes.
export function smtpDiagnostic(error: unknown): string {
  const code = (error as {code?: string} | null)?.code;
  if (code === 'EAUTH') return 'authentication';
  if (code === 'EENVELOPE') return 'envelope';
  if (code === 'ETIMEDOUT') return 'timeout';
  if (['ECONNREFUSED','ECONNRESET','EPIPE'].includes(code ?? '')) return 'connection';
  if (['CERT_HAS_EXPIRED','DEPTH_ZERO_SELF_SIGNED_CERT','ERR_TLS_CERT_ALTNAME_INVALID','UNABLE_TO_VERIFY_LEAF_SIGNATURE'].includes(code ?? '')) return 'tls';
  if (code === 'ESOCKET') return 'socket';
  return 'unclassified';
}
