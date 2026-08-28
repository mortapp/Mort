drop trigger if exists message_threads_sync_conversation
on public.message_threads;

-- Participant foreign keys are set null during profile deletion. Re-running the
-- conversation upsert for those cascade updates can reintroduce job/application
-- references after their own FK actions have already run.
create trigger message_threads_sync_conversation
after insert or update of job_id, application_id on public.message_threads
for each row execute function public.sync_conversation_for_thread();

