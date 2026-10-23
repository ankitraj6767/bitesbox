/// Which app shell a signed-in user gets.
///
/// One codebase, four experiences. The primary role decides the shell; the
/// database independently enforces what each role may actually do, so a
/// tampered client gains nothing by loading a different shell.
enum AppRole {
  customer('CUSTOMER'),
  deliveryPartner('DELIVERY_PARTNER'),
  kitchenStaff('KITCHEN_STAFF'),
  manager('MANAGER'),
  operations('OPERATIONS'),
  finance('FINANCE'),
  support('SUPPORT'),
  marketing('MARKETING'),
  admin('ADMIN'),
  owner('OWNER');

  const AppRole(this.code);

  final String code;

  static AppRole fromCode(String? code) => AppRole.values.firstWhere(
    (role) => role.code == code,
    orElse: () => AppRole.customer,
  );

  /// Roles that belong in the kitchen shell.
  bool get isKitchen => this == kitchenStaff;

  /// Roles that belong in the delivery shell.
  bool get isDelivery => this == deliveryPartner;

  /// Managers get the kitchen shell on the tablet plus an operations tab.
  bool get isManagement =>
      this == manager || this == operations || this == admin || this == owner;

  String get label => switch (this) {
    customer => 'Customer',
    deliveryPartner => 'Delivery Partner',
    kitchenStaff => 'Kitchen',
    manager => 'Manager',
    operations => 'Operations',
    finance => 'Finance',
    support => 'Support',
    marketing => 'Marketing',
    admin => 'Administrator',
    owner => 'Owner',
  };
}

class RoleGrant {
  const RoleGrant({
    required this.role,
    required this.label,
    this.branchId,
    this.isPrimary = false,
  });

  final AppRole role;
  final String label;
  final String? branchId;
  final bool isPrimary;

  factory RoleGrant.fromJson(Map<String, dynamic> json) => RoleGrant(
    role: AppRole.fromCode(json['role'] as String?),
    label: (json['label'] as String?) ?? '',
    branchId: json['branch_id'] as String?,
    isPrimary: json['is_primary'] as bool? ?? false,
  );
}

class UserProfile {
  const UserProfile({
    required this.id,
    this.phone,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.status = 'ACTIVE',
    this.preferredLanguage = 'en',
    this.preferredBranchId,
    this.onboardingCompleted = false,
    this.totalOrders = 0,
    this.marketingOptIn = false,
    this.pushEnabled = true,
    this.smsEnabled = true,
    this.emailEnabled = true,
    this.whatsappEnabled = false,
  });

  final String id;
  final String? phone;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String status;
  final String preferredLanguage;
  final String? preferredBranchId;
  final bool onboardingCompleted;
  final int totalOrders;
  final bool marketingOptIn;
  final bool pushEnabled;
  final bool smsEnabled;
  final bool emailEnabled;
  final bool whatsappEnabled;

  bool get isActive => status == 'ACTIVE';
  bool get isBlocked => status == 'BLOCKED';

  UserProfile copyWith({
    String? phone,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? status,
    String? preferredLanguage,
    String? preferredBranchId,
    bool? onboardingCompleted,
    int? totalOrders,
    bool? marketingOptIn,
    bool? pushEnabled,
    bool? smsEnabled,
    bool? emailEnabled,
    bool? whatsappEnabled,
  }) => UserProfile(
    id: id,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    status: status ?? this.status,
    preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    preferredBranchId: preferredBranchId ?? this.preferredBranchId,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    totalOrders: totalOrders ?? this.totalOrders,
    marketingOptIn: marketingOptIn ?? this.marketingOptIn,
    pushEnabled: pushEnabled ?? this.pushEnabled,
    smsEnabled: smsEnabled ?? this.smsEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
  );

  /// The greeting on the home screen prefers a first name.
  String get firstName {
    final name = fullName?.trim();
    if (name == null || name.isEmpty) return 'there';
    return name.split(RegExp(r'\s+')).first;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    fullName: json['full_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    status: (json['status'] as String?) ?? 'ACTIVE',
    preferredLanguage: (json['preferred_language'] as String?) ?? 'en',
    preferredBranchId: json['preferred_branch_id'] as String?,
    onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
    totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
    marketingOptIn: json['marketing_opt_in'] as bool? ?? false,
    pushEnabled: json['push_enabled'] as bool? ?? true,
    smsEnabled: json['sms_enabled'] as bool? ?? true,
    emailEnabled: json['email_enabled'] as bool? ?? true,
    whatsappEnabled: json['whatsapp_enabled'] as bool? ?? false,
  );
}

class BranchSummary {
  const BranchSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
  });

  final String id;
  final String code;
  final String name;
  final String status;

  factory BranchSummary.fromJson(Map<String, dynamic> json) => BranchSummary(
    id: json['id'] as String,
    code: (json['code'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    status: (json['status'] as String?) ?? 'CLOSED',
  );
}

/// Result of `public.my_session()` — identity, live permissions and branch scope
/// in one round trip.
class AppSession {
  const AppSession({
    required this.authenticated,
    this.userId,
    this.profile,
    this.primaryRole = AppRole.customer,
    this.roles = const [],
    this.permissions = const {},
    this.branches = const [],
    this.accountActive = true,
  });

  const AppSession.guest()
    : authenticated = false,
      userId = null,
      profile = null,
      primaryRole = AppRole.customer,
      roles = const [],
      permissions = const {},
      branches = const [],
      accountActive = true;

  final bool authenticated;
  final String? userId;
  final UserProfile? profile;
  final AppRole primaryRole;
  final List<RoleGrant> roles;
  final Set<String> permissions;
  final List<BranchSummary> branches;
  final bool accountActive;

  bool get isGuest => !authenticated;
  bool get isCustomer => primaryRole == AppRole.customer;
  bool get isRider => roles.any((grant) => grant.role.isDelivery);
  bool get isKitchen => roles.any((grant) => grant.role.isKitchen);
  bool get isManagement => roles.any((grant) => grant.role.isManagement);

  /// A manager signing in on the kitchen tablet should land in the kitchen.
  bool get prefersKitchenShell => isKitchen || isManagement;

  String? get branchId => branches.isEmpty ? null : branches.first.id;

  bool can(String permission) => permissions.contains(permission);

  bool canAny(Iterable<String> codes) => codes.any(permissions.contains);

  AppSession copyWith({UserProfile? profile}) => AppSession(
    authenticated: authenticated,
    userId: userId,
    profile: profile ?? this.profile,
    primaryRole: primaryRole,
    roles: roles,
    permissions: permissions,
    branches: branches,
    accountActive: accountActive,
  );

  /// Profile is complete enough to check out.
  bool get needsProfileSetup =>
      authenticated &&
      isCustomer &&
      ((profile?.fullName ?? '').trim().isEmpty ||
          !(profile?.onboardingCompleted ?? false));

  factory AppSession.fromJson(Map<String, dynamic> json) {
    if (json['authenticated'] != true) return const AppSession.guest();

    final profileJson = json['profile'];
    final rolesJson = json['roles'];
    final permissionsJson = json['permissions'];
    final branchesJson = json['branches'];

    return AppSession(
      authenticated: true,
      userId: json['user_id'] as String?,
      profile: profileJson is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(profileJson))
          : null,
      primaryRole: AppRole.fromCode(json['primary_role'] as String?),
      roles: rolesJson is List
          ? rolesJson
                .whereType<Map>()
                .map(
                  (role) => RoleGrant.fromJson(Map<String, dynamic>.from(role)),
                )
                .toList()
          : const [],
      permissions: permissionsJson is List
          ? permissionsJson.whereType<String>().toSet()
          : const {},
      branches: branchesJson is List
          ? branchesJson
                .whereType<Map>()
                .map(
                  (branch) =>
                      BranchSummary.fromJson(Map<String, dynamic>.from(branch)),
                )
                .toList()
          : const [],
      accountActive: json['account_active'] as bool? ?? true,
    );
  }
}
