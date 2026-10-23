const BACK_OFFICE_ROLES = new Set([
    'OWNER', 'ADMIN', 'MANAGER', 'OPERATIONS', 'FINANCE', 'SUPPORT', 'MARKETING',
]);

export function hasBackOfficeRole(roleCodes: readonly string[]): boolean {
    return roleCodes.some((role) => BACK_OFFICE_ROLES.has(role));
}

export function staffNeedsMfa(roleCodes: readonly string[], currentLevel?: string | null): boolean {
    return hasBackOfficeRole(roleCodes) && currentLevel !== 'aal2';
}

export function safeAdminNextPath(path: string | null | undefined): string | null {
    return path?.startsWith('/') && !path.startsWith('//') ? path : null;
}
