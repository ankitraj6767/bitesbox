/**
 * Domain contracts shared by the admin dashboard and (mirrored in Dart) the
 * mobile app. These describe the JSONB payloads returned by the Postgres RPCs,
 * which the generated `database.types.ts` can only type as `Json`.
 */
import type { Database } from './database.types';

type Enums = Database['public']['Enums'];

export type AppRole = Enums['app_role'];
export type OrderStatus = Enums['order_status'];
export type PaymentMode = Enums['payment_mode'];
export type PaymentMethod = Enums['payment_method'];
export type PaymentStatus = Enums['payment_status'];
export type CodStatus = Enums['cod_status'];
export type RefundKind = Enums['refund_kind'];
export type RefundStatus = Enums['refund_status'];
export type RefundReason = Enums['refund_reason'];
export type RefundDestination = Enums['refund_destination'];
export type FulfilmentType = Enums['fulfilment_type'];
export type OrderTiming = Enums['order_timing'];
export type FoodType = Enums['food_type'];
export type SpiceLevel = Enums['spice_level'];
export type AvailabilityState = Enums['availability_state'];
export type BranchStatus = Enums['branch_status'];
export type BranchClosureReason = Enums['branch_closure_reason'];
export type RiderDutyState = Enums['rider_duty_state'];
export type RiderOnboardingStatus = Enums['rider_onboarding_status'];
export type AssignmentStatus = Enums['assignment_status'];
export type AssignmentMode = Enums['assignment_mode'];
export type DiscountKind = Enums['discount_kind'];
export type TicketCategory = Enums['ticket_category'];
export type TicketStatus = Enums['ticket_status'];
export type TicketPriority = Enums['ticket_priority'];
export type NotificationEvent = Enums['notification_event'];
export type NotificationChannel = Enums['notification_channel'];
export type HomeSectionKind = Enums['home_section_kind'];
export type BannerLinkKind = Enums['banner_link_kind'];
export type CancellationReason = Enums['cancellation_reason'];
export type AuditAction = Enums['audit_action'];
export type DevicePlatform = Enums['device_platform'];

/** Order statuses that mean the order is still in flight. */
export const ACTIVE_ORDER_STATUSES: readonly OrderStatus[] = [
    'PENDING_PAYMENT',
    'PAYMENT_CONFIRMED',
    'ORDER_PLACED',
    'STORE_ACCEPTED',
    'PREPARING',
    'READY_FOR_PICKUP',
    'RIDER_ASSIGNED',
    'RIDER_ARRIVED_STORE',
    'PICKED_UP',
    'OUT_FOR_DELIVERY',
    'RIDER_ARRIVED_CUSTOMER',
];

export const CANCELLED_ORDER_STATUSES: readonly OrderStatus[] = [
    'CUSTOMER_CANCELLED',
    'ADMIN_CANCELLED',
    'STORE_REJECTED',
    'DELIVERY_FAILED',
];

export function isActiveOrder(status: OrderStatus): boolean {
    return ACTIVE_ORDER_STATUSES.includes(status);
}

export function isCancelledOrder(status: OrderStatus): boolean {
    return CANCELLED_ORDER_STATUSES.includes(status);
}

/**
 * Live-operations kanban columns. Several order statuses collapse into one
 * column so the board stays readable.
 */
export type OperationsColumn =
    | 'NEW'
    | 'ACCEPTED'
    | 'PREPARING'
    | 'READY'
    | 'RIDER_ASSIGNED'
    | 'OUT_FOR_DELIVERY'
    | 'DELIVERED';

export const OPERATIONS_COLUMNS: readonly OperationsColumn[] = [
    'NEW',
    'ACCEPTED',
    'PREPARING',
    'READY',
    'RIDER_ASSIGNED',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
];

// ── Session ────────────────────────────────────────────────────────────────
export interface SessionRoleGrant {
    role: AppRole;
    label: string;
    branch_id: string | null;
    is_primary: boolean;
    surfaces: string[];
}

export interface SessionProfile {
    id: string;
    phone: string | null;
    email: string | null;
    full_name: string | null;
    avatar_url: string | null;
    status: string;
    preferred_language: 'en' | 'hi';
    onboarding_completed: boolean;
    total_orders: number;
    marketing_opt_in: boolean;
}

export interface SessionBranch {
    id: string;
    code: string;
    name: string;
    status: BranchStatus;
}

export interface Session {
    authenticated: boolean;
    user_id?: string;
    profile?: SessionProfile | null;
    primary_role?: AppRole | null;
    roles?: SessionRoleGrant[];
    permissions?: string[];
    branches?: SessionBranch[];
    account_active?: boolean;
}

// ── Branch / ordering state ────────────────────────────────────────────────
export interface BranchOrderingState {
    branch_id: string;
    branch_name: string;
    status: BranchStatus;
    accepting_orders: boolean;
    is_busy: boolean;
    within_hours: boolean;
    /** A human operator explicitly opened the branch outside its schedule. */
    manual_override?: boolean;
    maintenance: boolean;
    reason_code: string | null;
    status_note: string | null;
    service_mode: 'DELIVERY' | 'PICKUP' | 'BOTH';
    prep_minutes: number;
    auto_resume_at: string | null;
}

// ── Serviceability ─────────────────────────────────────────────────────────
export interface ServiceabilityResult {
    serviceable: boolean;
    reason_code?: string;
    message?: string;
    branch_id?: string;
    zone_id?: string;
    zone_name?: string;
    distance_km?: number;
    delivery_fee?: number;
    min_order_amount?: number;
    free_delivery_threshold?: number | null;
    eta_minutes?: number;
    cod_enabled?: boolean;
    max_cod_amount?: number;
    pickup_available?: boolean;
    branch?: BranchOrderingState;
}

// ── Checkout ───────────────────────────────────────────────────────────────
export interface CheckoutLineModifier {
    modifier_id: string;
    modifier_group_id: string;
    group_name: string;
    modifier_name: string;
    unit_price: number;
    list_price: number;
    quantity: number;
    total_price: number;
    food_type: FoodType;
    is_available: boolean;
    is_free: boolean;
}

export interface CheckoutLine {
    cart_item_id: string;
    product_id: string;
    variant_id: string | null;
    category_id: string;
    product_name: string;
    product_slug: string;
    short_description: string | null;
    variant_name: string | null;
    variant_option_group: string | null;
    category_name: string;
    food_type: FoodType;
    image_path: string | null;
    quantity: number;
    unit_price: number;
    compare_price: number | null;
    modifiers_price: number;
    gross_amount: number;
    packaging_charge: number;
    allocated_discount: number;
    net_amount: number;
    taxable_amount: number;
    tax_amount: number;
    tax_rate: number;
    tax_inclusive: boolean;
    special_instructions: string | null;
    preparation_minutes: number;
    modifiers: CheckoutLineModifier[];
    is_available: boolean;
}

export interface CheckoutTotals {
    items_subtotal: number;
    items_discount: number;
    coupon_discount: number;
    promotion_discount: number;
    total_discount: number;
    taxable_amount: number;
    tax_amount: number;
    cgst_amount: number;
    sgst_amount: number;
    igst_amount: number;
    cess_amount: number;
    packaging_charge: number;
    delivery_fee: number;
    delivery_fee_waived: number;
    service_fee: number;
    tip_amount: number;
    loyalty_points_redeemed: number;
    loyalty_discount: number;
    round_off: number;
    grand_total: number;
    wallet_applied: number;
    wallet_balance: number;
    payable_amount: number;
    total_savings: number;
}

export type IssueSeverity = 'BLOCKING' | 'WARNING';

export interface CheckoutIssue {
    code: string;
    severity: IssueSeverity;
    message: string;
    cart_item_id?: string;
    product_id?: string;
    shortfall?: number;
    min_order_amount?: number;
    limit?: number;
}

export interface CouponEvaluation {
    valid: boolean;
    coupon_id?: string;
    code?: string;
    title?: string;
    discount_kind?: DiscountKind;
    discount_amount?: number;
    free_delivery?: boolean;
    eligible_subtotal?: number;
    reason_code?: string;
    message?: string;
    shortfall?: number;
}

export interface PromotionEvaluation {
    applied: boolean;
    promotion_id?: string;
    name?: string;
    headline?: string;
    badge_text?: string | null;
    discount_kind?: DiscountKind;
    discount_amount: number;
    free_delivery: boolean;
    stacks_with_coupon?: boolean;
    suppressed_by_coupon?: boolean;
}

export interface CheckoutQuote {
    cart_id: string | null;
    branch_id: string;
    currency_code: string;
    fulfilment_type: FulfilmentType;
    timing: OrderTiming;
    scheduled_for: string | null;
    address_id: string | null;
    payment_mode: PaymentMode;
    lines: CheckoutLine[];
    item_count: number;
    unit_count: number;
    totals: CheckoutTotals;
    coupon: CouponEvaluation | null;
    promotion: PromotionEvaluation | null;
    delivery: {
        zone_id: string | null;
        zone_name: string | null;
        distance_km: number | null;
        min_order_amount: number;
        free_delivery_threshold: number | null;
        eta_minutes: number;
    };
    timing_estimate: {
        prep_minutes: number;
        delivery_minutes: number;
        total_minutes: number;
        promised_at: string;
    };
    branch: BranchOrderingState;
    issues: CheckoutIssue[];
    is_valid: boolean;
    calculated_at: string;
}

// ── Order placement & payment ──────────────────────────────────────────────
export interface PlaceOrderResult {
    order_id: string;
    order_number: string;
    status: OrderStatus;
    payment_mode: PaymentMode;
    payment_status: PaymentStatus;
    grand_total: number;
    payable_amount: number;
    currency_code: string;
    requires_payment: boolean;
    promised_at: string | null;
    replayed: boolean;
}

export interface CreatePaymentResult {
    payment_id: string;
    order_id: string;
    order_number: string;
    provider: 'RAZORPAY';
    provider_order_id: string;
    /** Razorpay works in paise. */
    amount_in_paise: number;
    amount: number;
    currency: string;
    /** Publishable checkout key — safe to hand to the SDK. */
    razorpay_key_id: string;
    customer_name: string | null;
    customer_phone: string | null;
    customer_email: string | null;
    notes: Record<string, string>;
    replayed: boolean;
}

export interface VerifyPaymentResult {
    verified: boolean;
    order_id: string;
    order_number: string;
    status: OrderStatus;
    payment_status: PaymentStatus;
    already_captured: boolean;
    fully_reconciled: boolean;
}

// ── Order detail ───────────────────────────────────────────────────────────
export interface OrderTimelineEntry {
    to_status: OrderStatus;
    from_status: OrderStatus | null;
    label: string;
    note: string | null;
    is_override: boolean;
    actor_kind: string;
    actor_role: AppRole | null;
    created_at: string;
}

export interface OrderItemModifier {
    group_name: string;
    modifier_name: string;
    unit_price: number;
    quantity: number;
    total_price: number;
}

export interface OrderItem {
    id: string;
    product_id: string | null;
    product_name: string;
    variant_name: string | null;
    variant_option_group: string | null;
    category_name: string | null;
    food_type: FoodType;
    image_path: string | null;
    quantity: number;
    unit_price: number;
    modifiers_price: number;
    gross_amount: number;
    allocated_discount: number;
    net_amount: number;
    tax_amount: number;
    special_instructions: string | null;
    is_cancelled: boolean;
    refunded_quantity: number;
    modifiers: OrderItemModifier[];
}

export interface RiderLiveLocation {
    latitude: number;
    longitude: number;
    heading_degrees: number | null;
    eta_minutes: number | null;
    distance_to_destination_km: number | null;
    recorded_at: string;
    is_fresh: boolean;
}

export interface OrderRider {
    assignment_id: string;
    assignment_status: AssignmentStatus;
    delivery_partner_id: string;
    name: string;
    photo_path: string | null;
    phone: string;
    vehicle_type: string;
    vehicle_number: string | null;
    rating_average: number;
    total_deliveries: number | null;
    live_location: RiderLiveLocation | null;
}

export interface OrderDetail {
    id: string;
    order_number: string;
    branch_id: string;
    status: OrderStatus;
    status_changed_at: string;
    is_active: boolean;
    fulfilment_type: FulfilmentType;
    timing: OrderTiming;
    scheduled_for: string | null;
    channel: string;
    item_count: number;
    unit_count: number;
    customer_note: string | null;
    customer: {
        user_id: string;
        name: string | null;
        phone: string | null;
        email: string | null;
        is_first_order: boolean;
    };
    delivery: {
        address_line1: string | null;
        address_line2: string | null;
        landmark: string | null;
        area: string | null;
        city: string | null;
        state: string | null;
        postal_code: string | null;
        latitude: number | null;
        longitude: number | null;
        instructions: string | null;
        contact_name: string | null;
        contact_phone: string | null;
        zone_name: string | null;
        distance_km: number | null;
    };
    totals: {
        currency_code: string;
        items_subtotal: number;
        items_discount: number;
        coupon_code: string | null;
        coupon_discount: number;
        promotion_discount: number;
        total_discount: number;
        taxable_amount: number;
        tax_amount: number;
        cgst_amount: number;
        sgst_amount: number;
        igst_amount: number;
        cess_amount: number;
        packaging_charge: number;
        delivery_fee: number;
        delivery_fee_waived: number;
        service_fee: number;
        tip_amount: number;
        round_off: number;
        wallet_applied: number;
        loyalty_discount: number;
        loyalty_points_redeemed: number;
        grand_total: number;
        payable_amount: number;
        refunded_amount: number;
        cancellation_fee: number;
    };
    payment: {
        mode: PaymentMode;
        status: PaymentStatus;
        cod_status: CodStatus | null;
        paid_at: string | null;
        method: PaymentMethod | null;
        provider_payment_id: string | null;
    };
    items: OrderItem[];
    timeline: OrderTimelineEntry[];
    timing_info?: unknown;
    timing_detail?: unknown;
    rider: OrderRider | null;
    cancellation: {
        actor: string;
        reason: string | null;
        note: string | null;
        cancelled_at: string;
        fee: number;
    } | null;
    refunds: Array<{
        id: string;
        kind: RefundKind;
        status: RefundStatus;
        amount: number;
        amount_processed: number;
        destination: RefundDestination;
        reason: RefundReason;
        created_at: string;
        completed_at: string | null;
    }>;
    review: {
        id: string;
        food_rating: number;
        delivery_rating: number | null;
        overall_rating: number;
        comment: string | null;
        created_at: string;
    } | null;
    support_tickets: Array<{
        id: string;
        ticket_number: string;
        category: TicketCategory;
        status: TicketStatus;
        priority: TicketPriority;
        created_at: string;
    }>;
    internal_notes: Array<{ id: string; note: string; created_at: string; author: string | null }>;
    can_cancel: boolean;
    can_review: boolean;
    can_reorder: boolean;
}

export interface CancellationOptions {
    can_cancel: boolean;
    requires_approval: boolean;
    reason_code?: string;
    refund_amount?: number;
    cancellation_fee?: number;
    refund_percentage?: number;
    grace_period_seconds?: number;
    within_grace_period?: boolean;
    message: string;
    refund_destination?: 'NONE' | RefundDestination;
}

// ── Menu ───────────────────────────────────────────────────────────────────
export interface MenuCategory {
    id: string;
    name: string;
    slug: string;
    short_description: string | null;
    image_path: string | null;
    thumbnail_path: string | null;
    icon_name: string | null;
    accent_color: string | null;
    day_part: string;
    display_order: number;
    subcategories: Array<{
        id: string;
        name: string;
        slug: string;
        image_path: string | null;
        display_order: number;
    }>;
    product_count: number;
}

export interface MenuProduct {
    id: string;
    category_id: string;
    subcategory_id: string | null;
    name: string;
    slug: string;
    short_description: string | null;
    description: string | null;
    thumbnail_path: string | null;
    hero_image_path: string | null;
    food_type: FoodType;
    spice_level: SpiceLevel;
    allergens: string[];
    dietary_tags: string[];
    base_price: number;
    compare_price: number | null;
    packaging_charge: number;
    preparation_minutes: number;
    serves_count: number | null;
    calories: number | null;
    is_featured: boolean;
    is_best_seller: boolean;
    is_new: boolean;
    is_recommended: boolean;
    is_combo: boolean;
    rating_average: number;
    rating_count: number;
    display_order: number;
    min_quantity_per_order: number;
    max_quantity_per_order: number | null;
    allows_special_instructions: boolean;
    is_available: boolean;
    availability_state: AvailabilityState;
    out_of_stock_until: string | null;
    has_variants: boolean;
    min_price: number;
    images: Array<{
        storage_path: string;
        alt_text: string | null;
        variants: Record<string, string>;
        is_primary: boolean;
    }>;
}

export interface MenuCatalog {
    branch: BranchOrderingState;
    categories: MenuCategory[];
    products: MenuProduct[];
    generated_at: string;
}

export interface ProductVariantOption {
    id: string;
    name: string;
    option_group: string;
    price: number;
    compare_price: number | null;
    packaging_charge: number;
    calories: number | null;
    serves_count: number | null;
    is_default: boolean;
    is_available: boolean;
    availability_state: AvailabilityState;
    display_order: number;
}

export interface ProductModifierOption {
    id: string;
    name: string;
    description: string | null;
    image_path: string | null;
    price: number;
    food_type: FoodType;
    calories: number | null;
    max_quantity: number;
    is_default: boolean;
    is_available: boolean;
    display_order: number;
}

export interface ProductModifierGroup {
    id: string;
    name: string;
    description: string | null;
    selection: 'SINGLE' | 'MULTIPLE';
    is_required: boolean;
    min_select: number;
    max_select: number | null;
    free_selections: number;
    display_order: number;
    modifiers: ProductModifierOption[];
}

export interface ProductDetail extends Omit<MenuProduct, 'availability_state' | 'out_of_stock_until' | 'has_variants' | 'min_price'> {
    category_name: string;
    weight_grams: number | null;
    meta_title: string | null;
    meta_description: string | null;
    variants: ProductVariantOption[];
    modifier_groups: ProductModifierGroup[];
    reviews: Array<{ rating: number; comment: string | null; customer_name: string; created_at: string }>;
    similar_products: Array<{
        id: string;
        name: string;
        thumbnail_path: string | null;
        base_price: number;
        food_type: FoodType;
        rating_average: number;
        is_available: boolean;
    }>;
}

// ── Home feed ──────────────────────────────────────────────────────────────
export interface HomeBanner {
    id: string;
    title: string | null;
    subtitle: string | null;
    badge_text: string | null;
    image_path: string;
    image_path_wide: string | null;
    alt_text: string | null;
    background_color: string | null;
    link_kind: BannerLinkKind;
    link_category_id: string | null;
    link_product_id: string | null;
    link_coupon_id: string | null;
    link_collection_id: string | null;
    link_url: string | null;
    link_route: string | null;
}

export interface HomeSection {
    id: string;
    key: string;
    kind: HomeSectionKind;
    title: string | null;
    subtitle: string | null;
    action_label: string | null;
    action_route: string | null;
    layout: 'CAROUSEL' | 'GRID' | 'LIST' | 'BANNER' | 'STRIP';
    background_color: string | null;
    text_color: string | null;
    image_path: string | null;
    rich_text: string | null;
    display_order: number;
    banners?: HomeBanner[];
    categories?: Array<Pick<MenuCategory, 'id' | 'name' | 'slug' | 'image_path' | 'thumbnail_path' | 'icon_name' | 'accent_color' | 'product_count'>>;
    products?: MenuProduct[];
    coupons?: CustomerCoupon[];
}

export interface HomeFeed {
    branch: BranchOrderingState;
    sections: HomeSection[];
    generated_at: string;
}

export interface CustomerCoupon {
    id: string;
    code: string;
    title: string;
    description: string | null;
    terms?: string | null;
    discount_kind: DiscountKind;
    discount_value: number;
    min_order_amount: number;
    max_discount_amount: number | null;
    banner_path: string | null;
    ends_at: string | null;
    is_applicable?: boolean;
    reason_code?: string | null;
    reason?: string | null;
    estimated_discount?: number;
}

// ── Kitchen ────────────────────────────────────────────────────────────────
export interface KitchenOrder {
    id: string;
    order_number: string;
    status: OrderStatus;
    fulfilment_type: FulfilmentType;
    timing: OrderTiming;
    scheduled_for: string | null;
    payment_mode: PaymentMode;
    payment_status: PaymentStatus;
    is_paid: boolean;
    customer_note: string | null;
    item_count: number;
    unit_count: number;
    grand_total: number;
    placed_at: string | null;
    accepted_at: string | null;
    preparing_at: string | null;
    ready_at: string | null;
    promised_at: string | null;
    prep_minutes_estimate: number | null;
    elapsed_seconds: number;
    is_delayed: boolean;
    is_late_in_stage: boolean;
    is_first_order: boolean;
    items: Array<{
        id: string;
        product_name: string;
        variant_name: string | null;
        quantity: number;
        food_type: FoodType;
        special_instructions: string | null;
        is_cancelled: boolean;
        modifiers: Array<{ group_name: string; modifier_name: string; quantity: number }>;
    }>;
    rider: {
        name: string;
        phone: string;
        assignment_status: AssignmentStatus;
        arrived_store_at: string | null;
    } | null;
}

export interface KitchenQueue {
    branch: BranchOrderingState;
    orders: KitchenOrder[];
    recently_completed: Array<{
        id: string;
        order_number: string;
        status: OrderStatus;
        unit_count: number;
        picked_up_at: string | null;
        delivered_at: string | null;
    }>;
    counts: {
        new: number;
        accepted: number;
        preparing: number;
        ready: number;
        delayed: number;
    };
    generated_at: string;
}

// ── Live operations ────────────────────────────────────────────────────────
export interface OperationsOrderCard {
    id: string;
    order_number: string;
    status: OrderStatus;
    fulfilment_type: FulfilmentType;
    customer_name: string | null;
    customer_phone: string | null;
    area: string | null;
    unit_count: number;
    grand_total: number;
    payment_mode: PaymentMode;
    payment_status: PaymentStatus;
    placed_at: string | null;
    promised_at: string | null;
    status_changed_at: string;
    elapsed_seconds: number;
    is_delayed: boolean;
    distance_km: number | null;
    rider_name: string | null;
}

export interface OperationsAlert {
    type:
    | 'ORDER_DELAYED'
    | 'NO_RIDER_AVAILABLE'
    | 'PAYMENT_UNRECONCILED'
    | 'AWAITING_ACCEPTANCE'
    | 'SUPPORT_ESCALATION';
    severity: string;
    order_id?: string;
    order_number?: string;
    ticket_number?: string;
    message: string;
}

export interface AvailableRider {
    delivery_partner_id: string;
    full_name: string;
    phone: string;
    photo_path: string | null;
    vehicle_type: string;
    duty_state: RiderDutyState;
    active_load: number;
    max_concurrent_orders: number;
    distance_to_store_km: number | null;
    last_location_at: string | null;
    rating_average: number;
    score: number;
}

export interface LiveOperations {
    branch: BranchOrderingState;
    columns: Partial<Record<OperationsColumn, OperationsOrderCard[]>>;
    alerts: OperationsAlert[];
    riders: AvailableRider[];
    stats: {
        active_orders: number;
        delayed_orders: number;
        unpaid_orders: number;
        online_riders: number;
    };
    generated_at: string;
}

// ── Delivery partner app ───────────────────────────────────────────────────
export interface RiderAssignmentOrder {
    id: string;
    order_number: string;
    status: OrderStatus;
    item_count: number;
    unit_count: number;
    payment_mode: PaymentMode;
    cod_amount: number;
    grand_total: number;
    customer_name: string | null;
    customer_phone: string | null;
    address: string;
    latitude: number | null;
    longitude: number | null;
    instructions: string | null;
    distance_km: number | null;
    promised_at: string | null;
    placed_at: string | null;
    ready_at: string | null;
    items: Array<{ name: string; variant: string | null; quantity: number }> | null;
}

export interface RiderAssignment {
    assignment_id: string;
    status: AssignmentStatus;
    offered_at: string;
    expires_at: string | null;
    accepted_at: string | null;
    arrived_store_at: string | null;
    picked_up_at: string | null;
    total_payout: number;
    order: RiderAssignmentOrder;
    branch: {
        id: string;
        name: string;
        phone: string;
        address: string;
        latitude: number;
        longitude: number;
    };
}

export interface RiderDeliveries {
    partner: {
        id: string;
        full_name: string;
        photo_path: string | null;
        phone: string;
        vehicle_type: string;
        vehicle_number: string | null;
        onboarding_status: RiderOnboardingStatus;
        duty_state: RiderDutyState;
        rating_average: number;
        total_deliveries: number;
        cash_in_hand: number;
        max_concurrent_orders: number;
        active_load: number;
    };
    active: RiderAssignment[];
    history: Array<{
        assignment_id: string;
        status: AssignmentStatus;
        order_number: string;
        completed_at: string | null;
        total_payout: number;
        cash_collected: number;
        distance_km: number | null;
        area: string | null;
    }>;
}

export interface RiderEarnings {
    today: number;
    this_week: number;
    this_month: number;
    lifetime: number;
    cash_in_hand: number;
    unsettled_cash: number;
    deliveries_today: number;
    daily: Array<{ date: string; amount: number; deliveries: number }>;
    entries: Array<{
        id: string;
        entry_type: string;
        amount: number;
        description: string | null;
        earned_on: string;
        created_at: string;
    }>;
}

// ── Dashboard ──────────────────────────────────────────────────────────────
export interface DashboardOverview {
    range: { from: string; to: string; timezone: string };
    current: Record<string, number | null>;
    previous: Record<string, number | null>;
    deltas: { orders: number | null; net_sales: number | null; average_order_value: number | null };
    live: {
        preparing: number;
        ready: number;
        out_for_delivery: number;
        online_riders: number;
        available_riders: number;
        out_of_stock_items: number;
        open_tickets: number;
        pending_refunds: number;
    };
}

export interface DashboardCharts {
    revenue_trend: Array<{
        bucket: string;
        orders: number;
        gross_sales: number;
        net_sales: number;
        average_order_value: number;
    }>;
    orders_by_hour: Array<{ hour: number; orders: number; revenue: number }>;
    order_status_breakdown: Array<{ status: string; count: number }>;
    payment_methods: Array<{ method: string; count: number; revenue: number }>;
    top_products: Array<{
        product_id: string;
        product_name: string;
        units: number;
        revenue: number;
        orders: number;
    }>;
    top_categories: Array<{
        category_id: string;
        category_name: string;
        units: number;
        revenue: number;
    }>;
    customer_mix: { new: number; returning: number };
    cancellation_reasons: Array<{ reason: string; count: number }>;
    coupon_usage: Array<{
        code: string;
        uses: number;
        discount_given: number;
        revenue_influenced: number;
    }>;
    delivery_performance: Array<{
        delivery_partner_id: string;
        name: string;
        deliveries: number;
        avg_minutes: number;
        on_time_rate: number;
        rating: number;
    }>;
    zero_result_searches: Array<{ query: string; count: number }>;
}

// ── Invoice ────────────────────────────────────────────────────────────────
export interface OrderInvoice {
    invoice_number: string;
    order_number: string;
    invoice_date: string;
    restaurant: {
        name: string;
        legal_name: string;
        address: string;
        phone: string;
        email: string | null;
        gstin: string | null;
        fssai: string | null;
    };
    customer: { name: string | null; phone: string | null; address: string };
    items: Array<{
        name: string;
        hsn_sac_code: string | null;
        quantity: number;
        unit_price: number;
        modifiers: string[];
        gross_amount: number;
        discount: number;
        taxable_amount: number;
        tax_rate: number;
        cgst: number;
        sgst: number;
        tax_amount: number;
        net_amount: number;
        is_cancelled: boolean;
    }>;
    totals: Record<string, number | string | null>;
    payment: {
        mode: PaymentMode;
        status: PaymentStatus;
        paid_at: string | null;
        reference: string | null;
    };
    tax_note: string | null;
    footer_note: string | null;
}
