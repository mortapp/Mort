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
const other = createClient(API_URL, ANON_KEY, options)
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
const otherEmail = `deletion-separate-${randomUUID()}@mortapp.test`
const otherPassword = `${randomBytes(24).toString('base64url')}Bb2!`
const otherSubject = checked(await admin.auth.admin.createUser({
  email: otherEmail, password: otherPassword, email_confirm: true,
  user_metadata: { display_name: 'Separate Deletion Fixture', date_of_birth: '1984-02-14' },
}), 'Create separate local actor').user.id
checked(await other.auth.signInWithPassword({ email: otherEmail, password: otherPassword }), 'Separate GoTrue sign-in')
const objectName = `${subject}/${randomUUID()}.png`
const { session } = checked(await user.auth.signInWithPassword({ email, password }), 'GoTrue sign-in')
assert.ok(session?.refresh_token, 'GoTrue did not issue a refresh token')
checked(await user.storage.from(uploadBucket).upload(objectName, png, { contentType: 'image/png' }), 'Upload as owner')
const original = checked(await admin.storage.from(uploadBucket).download(objectName), 'Read original bytes')
assert.deepEqual(Buffer.from(await original.arrayBuffer()), png)
console.log('PASS: actual user session created and private object bytes verified')

const requests = await Promise.all([
  user.rpc('request_account_deletion', { p_source: 'web' }),
  user.rpc('request_account_deletion', { p_source: 'web' }),
])
const created = checked(requests[0], 'Request deletion')
assert.equal(created?.ok, true, created?.code)
const id = created.request.id
assert.equal(checked(requests[1], 'Concurrent same-account request')?.request?.id, id)
assert.equal(checked(await other.rpc('get_my_account_deletion_request'), 'Separate request status')?.request, null)
assert.equal(checked(await other.rpc('issue_my_account_deletion_receipt', { p_request_id: id }), 'Separate receipt attempt'), null)
assert.equal(checked(await other.rpc('cancel_account_deletion_request'), 'Separate cancellation')?.ok, false)
assert.ok((await other.from('account_deletion_requests').select('id').eq('id', id)).error)
assert.ok((await other.rpc('service_claim_account_deletion_request', { p_request_id: id })).error)
console.log('PASS: concurrent requests collapse to one; a separate GoTrue actor cannot view, receipt, cancel or claim it')
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
const lease = checked(await admin.rpc('service_claim_account_deletion_request', { p_request_id: nextId }), 'Fixture worker claim')
assert.equal(lease.ok, true, lease.code)
const firstLock = lease.request.processor_lock_id
assert.equal(checked(await admin.rpc('service_complete_account_deletion_request', {
  p_request_id: nextId, p_processor_lock_id: firstLock, p_retention_summary: 'Isolated fixture',
}), 'Reject premature completion')?.code, 'deletion_absence_unconfirmed')
assert.equal((await processRequest(nextId)).processed, 0, 'A live lease must not be stolen')
checked(await admin.from('account_deletion_requests')
  .update({ last_attempt_at: new Date(Date.now() - 901_000).toISOString() })
  .eq('id', nextId).eq('processor_lock_id', firstLock).eq('status', 'processing')
  .select('id').single(), 'Age only this fixture lease')
assert.equal(checked(await admin.rpc('service_fail_account_deletion_request', {
  p_request_id: nextId, p_processor_lock_id: firstLock, p_error_code: 'fixture_expired_lease',
}), 'Reject stale lock')?.code, 'deletion_lock_mismatch')
const removed = await processRequest(nextId)
assert.equal(removed.processed, 1, removed.code)
assert.equal(removed.removedStorageObjects, 1)
const missingUser = await admin.auth.admin.getUserById(subject)
assert.equal(missingUser.error?.status, 404)
assert.equal(missingUser.error?.code, 'user_not_found')
assert.equal(checked(await admin.from('profiles').select('id').eq('id', subject).maybeSingle(), 'Check profile'), null)
assert.ok((await user.auth.refreshSession({ refresh_token: session.refresh_token })).error, 'Old refresh token stayed valid')
const missingObject = await admin.storage.from(uploadBucket).download(objectName)
assert.equal(String(missingObject.error?.statusCode ?? missingObject.error?.status), '404')
assert.deepEqual(checked(await anonymous.rpc('get_account_deletion_receipt_status', { p_receipt: nextReceipt }), 'Final receipt'), { status: 'completed' })
assert.equal((await processRequest(nextId)).processed, 0, 'Completed request cannot be processed again')
assert.equal(checked(await other.auth.getUser(), 'Other actor retains a working session').user.id, otherSubject)
console.log('PASS: premature completion and stale lease rejected; expired claim recovered; duplicate processing is a no-op')
console.log('PASS: Auth 404 user_not_found, profile absent, refresh revoked, object GET 404, completed receipt')
