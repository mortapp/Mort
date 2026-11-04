console.error("DISABLED: this readiness generator consumes historical version 0.9.1+91 evidence and references the deleted Supabase project. It is not valid for the current production release. Use only a newly generated readiness report tied to the current signed AAB, current production project, and verified external gates.");
process.exitCode = 1;
