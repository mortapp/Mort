import Foundation
import Observation

@MainActor
@Observable
final class DependencyContainer {
    let configuration: AppConfiguration
    let supabase: SupabaseProvider
    let router: Router

    let auth: AuthRepositoryProtocol
    let profiles: ProfileRepositoryProtocol
    let jobs: JobRepositoryProtocol
    let savedJobs: SavedJobRepositoryProtocol
    let applications: ApplicationRepositoryProtocol
    let messages: MessageRepositoryProtocol
    let guardians: GuardianRepositoryProtocol
    let safety: SafetyRepositoryProtocol
    let notifications: NotificationRepositoryProtocol
    let reviews: ReviewRepositoryProtocol
    let support: SupportRepositoryProtocol
    let portfolio: PortfolioRepositoryProtocol
    let storage: StorageRepositoryProtocol
    let verification: VerificationRepositoryProtocol
    let accountTrust: AccountTrustRepositoryProtocol
    let monetization: MonetizationRepositoryProtocol
    let missionPilot: MissionPilotRepositoryProtocol
    let legalAcceptance: LegalAcceptanceRepositoryProtocol
    let jobContracts: JobContractRepositoryProtocol
    let firstPartyTrust: FirstPartyTrustRepositoryProtocol
    let admin: AdminRepositoryProtocol

    let revenueCat: RevenueCatService
    let ads: AdMobService
    let push: PushNotificationService
    let deviceAuthentication: DeviceAuthenticationService
    let biometricReauthentication: BiometricReauthenticationService
    let appLock: AppLockService
    let walletIdentity: any AppleWalletIdentityProvider
    let businessRegistry: any BusinessRegistryProvider
    let documentCapture: any DocumentCaptureProvider
    let session: SessionStore

    init(configuration: AppConfiguration) {
        self.configuration = configuration
        let supabase = SupabaseProvider(configuration: configuration)
        self.supabase = supabase
        let client = supabase.client
        let router = Router()
        self.router = router

        let auth = AuthRepository(client: client)
        let profiles = ProfileRepository(client: client)
        let jobs = JobRepository(client: client)
        let savedJobs = SavedJobRepository(client: client)
        let applications = ApplicationRepository(client: client)
        let messages = MessageRepository(client: client)
        let guardians = GuardianRepository(client: client)
        let safety = SafetyRepository(client: client)
        let notifications = NotificationRepository(client: client)
        let reviews = ReviewRepository(client: client)
        let support = SupportRepository(client: client)
        let portfolio = PortfolioRepository()
        let storage = StorageRepository(client: client, profileRepository: profiles)
        let verification = VerificationRepository(client: client, storage: storage)
        let accountTrust = AccountTrustRepository(client: client)
        let monetization = MonetizationRepository(client: client)
        let missionPilot = MissionPilotRepository(client: client)
        let legalAcceptance = LegalAcceptanceRepository(client: client)
        let jobContracts = JobContractRepository(client: client)
        let firstPartyTrust = FirstPartyTrustRepository(client: client)
        let admin = AdminRepository(client: client)
        let revenueCat = RevenueCatService(publicAPIKey: configuration.revenueCatIOSAPIKey)
        let ads = AdMobService(configuration: configuration, repository: monetization)
        let push = PushNotificationService()
        let deviceAuthentication = DeviceAuthenticationService()
        let biometricReauthentication = BiometricReauthenticationService(authentication: deviceAuthentication)
        let appLock = AppLockService(authentication: biometricReauthentication)

        self.auth = auth
        self.profiles = profiles
        self.jobs = jobs
        self.savedJobs = savedJobs
        self.applications = applications
        self.messages = messages
        self.guardians = guardians
        self.safety = safety
        self.notifications = notifications
        self.reviews = reviews
        self.support = support
        self.portfolio = portfolio
        self.storage = storage
        self.verification = verification
        self.accountTrust = accountTrust
        self.monetization = monetization
        self.missionPilot = missionPilot
        self.legalAcceptance = legalAcceptance
        self.jobContracts = jobContracts
        self.firstPartyTrust = firstPartyTrust
        self.admin = admin
        self.revenueCat = revenueCat
        self.ads = ads
        self.push = push
        self.deviceAuthentication = deviceAuthentication
        self.biometricReauthentication = biometricReauthentication
        self.appLock = appLock
        self.walletIdentity = DisabledAppleWalletIdentityProvider()
        self.businessRegistry = ManualOfficialSourceBusinessRegistryProvider()
        self.documentCapture = DisabledDocumentCaptureProvider()
        self.session = SessionStore(
            client: client,
            authRepository: auth,
            profileRepository: profiles,
            revenueCat: revenueCat,
            router: router
        )
    }
}
