export type FixtureConfig = {
  fixtureId:string; project:'mort-mobile'; mode:'local_fixture';
  authUrl:'http://127.0.0.1:55421'; dbHost:'127.0.0.1'; dbPort:55422;
  captureUrl:'http://127.0.0.1:55424'; smtpHost:'127.0.0.1'; smtpPort:55425;
  guardUrl:'http://127.0.0.1:55426'; credentialOrigin:'generated_fixture';
};
export type FixtureIdentity = FixtureConfig & {
  dbFixtureId:string; imageVerified:boolean; volumeVerified:boolean;
  confirmationRequired:boolean; phoneEnabled:boolean; anonymousEnabled:boolean;
  emailExpiry:number; jwtExpiry:number; providerVersion:string; resourceIds:string[];
};
export type FixtureHandle = FixtureConfig & {
  observed:FixtureIdentity; dbUrl:string; serviceKey:string; anonKey:string;
  smtpUrl:string; imageDigests:Readonly<Record<string,string>>; trackedAccounts:Set<string>;trackedEmails?:Set<string>;
};
