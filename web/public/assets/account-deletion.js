const config = window.MORT_PUBLIC_CONFIG || {};
const form = document.querySelector('#deletion-link-form');
const result = document.querySelector('#link-result');
const requestPanel = document.querySelector('#request-panel');
const confirmedPanel = document.querySelector('#confirmed-panel');
const deletionResult = document.querySelector('#deletion-result');
const submit = document.querySelector('#submit-deletion');
const signOut = document.querySelector('#sign-out');
if (!config.supabaseUrl || !config.supabaseAnonKey) {
  form.querySelector('button').disabled = true;
  result.textContent = 'Web account deletion is not configured in this preview. Use the in-app account deletion control.';
} else {
  const client = window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey, { auth: { persistSession: true, detectSessionInUrl: true, flowType: 'pkce' } });
  async function showSession() {
    const { data } = await client.auth.getSession();
    const signedIn = Boolean(data.session);
    requestPanel.hidden = signedIn;
    confirmedPanel.hidden = !signedIn;
    if (signedIn) {
      const { data: status } = await client.rpc('get_my_account_deletion_request');
      if (status?.request) deletionResult.textContent = 'Current request status: ' + status.request.status.replaceAll('_', ' ') + '.';
    }
  }
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const email = new FormData(form).get('email')?.toString().trim();
    if (!email) return;
    form.querySelector('button').disabled = true;
    try {
      await client.auth.signInWithOtp({ email, options: { shouldCreateUser: false, emailRedirectTo: new URL('/account-deletion/?confirm=1', location.origin).toString() } });
    } finally {
      result.textContent = 'If that email can receive a MORT sign-in link, check its inbox. This page never confirms whether an account exists.';
      form.reset();
      form.querySelector('button').disabled = false;
    }
  });
  submit.addEventListener('click', async () => {
    submit.disabled = true;
    deletionResult.textContent = 'Submitting your verified request...';
    const { data, error } = await client.rpc('request_account_deletion', { p_source: 'web' });
    deletionResult.textContent = !error && data?.ok === true
      ? 'Deletion request submitted. Current status: ' + data.request.status.replaceAll('_', ' ') + '.'
      : data?.code === 'recent_reauthentication_required'
        ? 'The private link expired. Sign out and request a new link.'
        : 'The request could not be submitted. Try again later or use the in-app deletion control.';
    submit.disabled = false;
  });
  signOut.addEventListener('click', async () => { await client.auth.signOut(); await showSession(); });
  client.auth.onAuthStateChange(() => { void showSession(); });
  await showSession();
}
