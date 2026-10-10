export function certificateCurrent(certificate,now=Date.now()){
 const from=Date.parse(certificate.validFrom),to=Date.parse(certificate.validTo);
 return Number.isFinite(from)&&Number.isFinite(to)&&Number.isFinite(now)&&from<=now&&now<to;
}
