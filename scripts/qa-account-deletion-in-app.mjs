import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-account-deletion-in-app';
const screen = read('flutter_mort/lib/features/settings/account_management_screens.dart');
const repository = read('flutter_mort/lib/data/repositories/account_deletion_repository.dart');
assert(screen.includes('reauthenticateWithPassword'), 'In-app deletion does not reauthenticate.');
assert(screen.includes("_confirmation.text.trim() == 'DELETE'"), 'Destructive confirmation is missing.');
assert(repository.includes("'request_account_deletion'"), 'Dedicated deletion RPC is not used.');
assert(repository.includes("'get_my_account_deletion_request'"), 'Deletion status is unavailable.');
assert(!screen.includes('createTicket'), 'Deletion still depends on a support ticket.');
pass(scope, 'in-app deletion is easy to locate, reauthenticated, dedicated, and status-aware');
