-- STAFF MFA / SERVER-BOUNDARY ASSURANCE
begin;

select tap.suite('Staff MFA and signed assurance');
select tap.reset();

select tap.eq(
  (select column_default from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'marketing_opt_in'),
  'false',
  'new profiles do not opt into marketing by default'
);
select tap.eq(
  (select column_default from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'whatsapp_enabled'),
  'false',
  'new profiles do not enable WhatsApp by default'
);

select tap.as_user(tap.seed('customer_a'));
select tap.throws(
  'select public.operational_health_alerts()',
  'PERMISSION_DENIED',
  'customers cannot read staff operational health alerts'
);
select tap.reset();
select tap.as_user(tap.seed('owner'));
select tap.no_throw(
  'select public.operational_health_alerts()',
  'owners can read branch-scoped operational health alerts'
);
select tap.reset();

select tap.as_user_aal(tap.seed('owner'), 'aal1');
select tap.eq(app.has_permission('refund.approve'), false, 'AAL1 owner is denied refund approval');
select tap.eq(app.has_permission('payment.reconcile'), false, 'AAL1 owner is denied payment reconciliation');
select tap.eq(app.has_permission('role.assign'), false, 'AAL1 owner is denied role changes');
select tap.eq(app.has_permission('customer.view'), false, 'AAL1 owner is denied customer data');
select tap.eq(app.has_permission('campaign.manage'), false, 'AAL1 owner is denied campaign sends');
select tap.eq(app.has_permission('order.override'), false, 'AAL1 owner is denied order overrides');
select tap.throws('select app.require_permission(''refund.approve'')', 'PERMISSION_DENIED', 'refund RPC guard rejects AAL1');
select tap.throws('select app.require_permission(''role.assign'')', 'PERMISSION_DENIED', 'role RPC guard rejects AAL1');
select tap.throws('select app.require_permission(''campaign.manage'')', 'PERMISSION_DENIED', 'campaign RPC guard rejects AAL1');
select tap.reset();

select tap.as_expired_user(tap.seed('owner'));
select tap.eq(app.has_permission('refund.approve'), false, 'expired AAL2 session cannot perform sensitive actions');
select tap.reset();

select tap.as_user(tap.seed('finance'));
select tap.no_throw('select app.require_permission(''refund.approve'')', 'verified finance AAL2 can approve refunds');
select tap.no_throw('select app.require_permission(''payment.reconcile'')', 'verified finance AAL2 can reconcile payments');
select tap.no_throw('select app.require_permission(''report.export'')', 'verified finance AAL2 can export reports');
select tap.throws('select app.require_permission(''role.assign'')', 'PERMISSION_DENIED', 'AAL2 does not grant finance role-management permission');
select tap.reset();

select tap.as_user(tap.seed('kitchen'));
select tap.throws('select app.require_permission(''refund.approve'')', 'PERMISSION_DENIED', 'AAL2 unprivileged staff remains denied by RBAC');
select tap.reset();

select tap.as_user(tap.seed('support'));
select tap.no_throw('select app.require_permission(''refund.create'')', 'AAL2 support can request a refund within its RBAC grant');
select tap.throws('select app.require_permission(''refund.approve'')', 'PERMISSION_DENIED', 'AAL2 support still cannot approve refunds');
select tap.reset();

select tap.as_user_aal(tap.seed('customer_a'), 'aal1');
select tap.no_throw('select app.require_permission(''order.create'')', 'customers remain usable without staff MFA');
select tap.eq(app.has_permission('refund.approve'), false, 'customer cannot gain staff privileges at AAL1');
select tap.reset();

select tap.done('Staff MFA and signed assurance');
rollback;
