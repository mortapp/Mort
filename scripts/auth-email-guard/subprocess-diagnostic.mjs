import {createHash} from 'node:crypto';

const signals=new Set(['SIGABRT','SIGALRM','SIGBUS','SIGFPE','SIGHUP','SIGILL','SIGINT','SIGKILL','SIGPIPE','SIGQUIT','SIGSEGV','SIGTERM','SIGTRAP','SIGUSR1','SIGUSR2']);
const codes=new Set(['EACCES','EAGAIN','EBADF','ECONNREFUSED','ECONNRESET','EFAULT','EINTR','EINVAL','EIO','EISDIR','EMFILE','ENFILE','ENOBUFS','ENOENT','ENOMEM','ENOTDIR','EPERM','EPIPE','ETIMEDOUT','23505','42501','P0001']);
const stages=new Set(['shape','database','receipt','store','outside','wrong-secret','trusted-relay','replay','delivery']);
const names=new Set(['Error','TypeError','InvalidData','PermissionDenied','ConnectionRefused','ConnectionReset','TimedOut','unclassified']);
const recoveryLabels=new Set(['scenario','actual SMTP recovery code','actual SMTP recovery link','expired link denied','expired link changes no password','expired link grants no capability','wrong link denied','wrong link changes no password','real recovery capability','reused link denied','password replacement committed','reused capability denied','stored password actually changed','replacement password signs in','admission released']);
const reviewedCodes=new Set([...codes,'unclassified']);
const allowlisted=(value,allowed)=>value==null?null:allowed.has(value)?value:'unclassified';
const stderrClasses=[
  ['duplicate_object',/\bERROR:\s+[^\r\n]*\balready exists\b/i],
  ['undefined_function',/\bERROR:\s+function\b[^\r\n]*\bdoes not exist\b/i],
  ['undefined_object',/\bERROR:\s+(?!function\b)[^\r\n]*\bdoes not exist\b/i],
  ['permission_denied',/\bERROR:\s+(?:permission denied\b|must be owner\b)/i],
  ['dependency',/\bERROR:\s+(?:cannot drop\b|[^\r\n]*\bdependent objects\b)/i],
  ['syntax',/\bERROR:\s+syntax error\b/i],
  ['connection',/\b(?:ECONNREFUSED|could not connect|server closed the connection|connection[^\r\n]*(?:refused|failed|closed|timed out))\b/i],
];

// Treat stderr as untrusted: only reconstructed, complete reviewed labels may
// leave the child. Fingerprint raw bytes without exposing values or paths.
export function subprocessDiagnostic(result){
  const status=Number.isSafeInteger(result.status)?result.status:null;
  const signal=allowlisted(result.signal,signals),errorCode=allowlisted(result.error?.code,codes);
  const stderr=Buffer.isBuffer(result.stderr)?result.stderr:typeof result.stderr==='string'?Buffer.from(result.stderr):Buffer.alloc(0);
  const stderrText=stderr.toString('utf8');
  const reviewedLines=new Set();
  for(const raw of stderrText.split(/\r?\n/)){
    const line=raw.replace(/\x1b\[[0-9;]*m/g,'').replace(/^error: Uncaught(?: \(in promise\))? Error: /,'');
    const assertion=/^Fixture ingress assertion failed: ([a-z-]+)$/.exec(line);
    const detail=/^Fixture ingress diagnostic: stage=([a-z-]+) name=([A-Za-z]+) code=([A-Z0-9_]+|unclassified)$/.exec(line);
    const recovery=/^Recovery control failed: (.+)$/.exec(line);
    if(assertion&&stages.has(assertion[1]))reviewedLines.add(`Fixture ingress assertion failed: ${assertion[1]}`);
    else if(detail&&stages.has(detail[1])&&names.has(detail[2])&&reviewedCodes.has(detail[3]))reviewedLines.add(`Fixture ingress diagnostic: stage=${detail[1]} name=${detail[2]} code=${detail[3]}`);
    else if(recovery&&recoveryLabels.has(recovery[1]))reviewedLines.add(`Recovery control failed: ${recovery[1]}`);
    if(reviewedLines.size===12)break;
  }
  const category=errorCode==='ETIMEDOUT'?'timeout':errorCode&&errorCode!=='unclassified'?'spawn_error':signal&&signal!=='unclassified'?'signal':status!==null&&status!==0?'exit_code':status===0&&!signal&&!errorCode?'success':'unknown_failure';
  const stderrCategories=stderrClasses.filter(([,pattern])=>pattern.test(stderrText)).map(([label])=>label);
  return {category,status,signal,errorCode,stderrBytes:stderr.length,stderrSha256:createHash('sha256').update(stderr).digest('hex'),stderrCategories,reviewedLines:[...reviewedLines]};
}

export function recordSubprocessFailure(result){
  if(result.status!==0)console.error('Fixture subprocess failed: '+JSON.stringify(subprocessDiagnostic(result)));
  return result;
}
