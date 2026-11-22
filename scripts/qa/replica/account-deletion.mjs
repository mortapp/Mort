// Runs only against a disposable local stack started by the replica runner.
// Uses a real GoTrue session, never a synthetic authenticated JWT.
import assert from 'node:assert/strict'
import { randomBytes, randomUUID } from 'node:crypto'
import { createClient } from '@supabase/supabase-js'

const { API_URL, ANON_KEY, SERVICE_ROLE_KEY, MORT_LOCAL_DELETION_WORKER_URL, ACCOUNT_DELETION_WORKER_SECRET } = process.env
function requireLocal(value, name) {
  if (!value) throw new Error(`${name} is required`)
  const url = new URL(value)
  if (url.protocol !== 'http:' || !['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)
      || url.username || url.password) throw new Error(`${name} must use HTTP loopback`)
}
requireLocal(API_URL, 'API_URL')
requireLocal(MORT_LOCAL_DELETION_WORKER_URL, 'MORT_LOCAL_DELETION_WORKER_URL')
assert.ok(ANON_KEY && SERVICE_ROLE_KEY && ACCOUNT_DELETION_WORKER_SECRET, 'Local credentials are required')
const options = { auth: { persistSession: false, autoRefreshToken: false } }
const admin = createClient(API_URL, SERVICE_ROLE_KEY, options)
const user = createClient(API_URL, ANON_KEY, options)
const anonymous = createClient(API_URL, ANON_KEY, options)
const email = `deletion-${randomUUID()}@mortapp.test`
const password = `${randomBytes(24).toString('base64url')}Aa1!`
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=', 'base64')
const uploadBucket = 'profile-avatars'

function checked(result, operation) {
  if (result.error) throw new Error(`${operation}: ${result.error.code ?? result.error.name}`)
  return result.data
}

async function processRequest(requestId) {
  const response = await fetch(MORT_LOCAL_DELETION_WORKER_URL, {
    method: 'POST',
    redirect: 'error',
    headers: { 'Content-Type': 'application/json', 'x-mort-deletion-secret': ACCOUNT_DELETION_WORKER_SECRET },
    body: JSON.stringify({ requestId }),
  })
  const body = await response.json()
  assert.equal(response.status, 200, body.code)
  return body
}

const subject = checked(await admin.auth.admin.createUser({
  email, password, email_confirm: true,
  user_metadata: { display_name: 'Deletion Fixture', date_of_birth: '1985-02-14' },
}), 'Create local actor').user.id
const objectName = `${subject}/${randomUUID()}.png`
const { session } = checked(await user.auth.signInWithPassword({ email, password }), 'GoTrue sign-in')
assert.ok(session?.refresh_token, 'GoTrue did not issue a refresh token')
checked(await user.storage.from(uploadBucket).upload(objectName, png, { contentType: 'image/png' }), 'Upload as owner')
const original = checked(await admin.storage.from(uploadBucket).download(objectName), 'Read original bytes')
assert.deepEqual(Buffer.from(await original.arrayBuffer()), png)
console.log('PASS: actual user session created and private object bytes verified')

const request = (await user.rpc('request_account_deletion', { p_source: 'web' }))
const created = checked(request, 'Request deletion')
assert.equal(created?.ok, true, created?.code)
const id = created.request.id
const receipt = checked(await user.rpc('issue_my_account_deletion_receipt', { p_request_id: id }), 'Issue receipt')
assert.match(receipt, /^[0-9a-f]{64}$/)
const receiptStatus = async () => checked(await anonymous.rpc('get_account_deletion_receipt_status', { p_receipt: receipt }), 'Anonymous receipt')
assert.deepEqual(await receiptStatus(), { status: 'requested' })
assert.equal((await processRequest(id)).processed, 0, 'Cancellation grace period was not enforced')
assert.equal(checked(await user.rpc('cancel_account_deletion_request'), 'Cancel request')?.request?.status, 'cancelled')
assert.deepEqual(await receiptStatus(), { status: 'cancelled' })
console.log('PASS: confirmed request, status-only receipt, cancellation grace and cancellation')

const second = checked(await user.rpc('request_account_deletion', { p_source: 'in_app' }), 'Submit new request')
assert.equal(second?.ok, true, second?.code)
const nextId = second.request.id
const nextReceipt = checked(await user.rpc('issue_my_account_deletion_receipt', { p_request_id: nextId }), 'Issue second receipt')
assert.match(nextReceipt, /^[0-9a-f]{64}$/)
// Advance only this run's newly created row. Do not poll or process a global queue.
checked(await admin.from('account_deletion_requests')
  .update({ requested_at: new Date(Date.now() - 301_000).toISOString() })
  .eq('id', nextId).eq('user_id', subject).eq('status', 'requested')
  .select('id').single(), 'Advance local fixture grace period')
const removed = await processRequest(nextId)
assert.equal(removed.processed, 1, removed.code)
assert.equal(removed.removedStorageObjects, 1)
const missingUser = await admin.auth.admin.getUserById(subject)
assert.equal(missingUser.error?.status, 404)
assert.equal(missingUser.error?.code, 'user_not_found')
assert.equal(checked(await admin.from('profiles').select('id').eq('id', subject).maybeSingle(), 'Check profile'), null)
assert.ok((await user.auth.refreshSession({ refresh_token: session.refresh_token })).error, 'Old refresh token stayed valid')
const missingObject = await admin.storage.from(uploadBucket).download(objectName)
assert.equal(String(missingObject.error?.status ?? missingObject.error?.statusCode), '404')
assert.deepEqual(checked(await anonymous.rpc('get_account_deletion_receipt_status', { p_receipt: nextReceipt }), 'Final receipt'), { status: 'completed' })
console.log('PASS: Auth 404 user_not_found, profile absent, refresh revoked, object GET 404, completed receipt')
