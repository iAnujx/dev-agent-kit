export const JWT_ALGORITHM = 'HS256';
export const JWT_EXPIRES_IN = '1h';
export const AUTH_COOKIE_NAME = 'auth_token';
export const CSRF_COOKIE_NAME = 'x-csrf-token';

// Pre-computed bcrypt hash (cost factor 12) for dummy comparison when user is not found.
// Ensures identical response timing to mitigate user enumeration timing attacks.
export const DUMMY_HASH = '$2b$12$ATkP6kqHmxTJur69Qy/j0uL5IRH05RmLWWPhr9.eRnvG//QuUZRFK';
