import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env from project root
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

export function validateEnv(env = process.env) {
  const errors = [];

  if (!env.JWT_SECRET) {
    errors.push('JWT_SECRET is required');
  } else if (typeof env.JWT_SECRET !== 'string' || env.JWT_SECRET.length < 32) {
    errors.push('JWT_SECRET must be at least 32 characters long');
  }

  const csrfSecret = env.CSRF_SECRET || env.JWT_SECRET;
  if (!csrfSecret || csrfSecret.length < 32) {
    errors.push('CSRF_SECRET must be at least 32 characters long');
  }

  return {
    isValid: errors.length === 0,
    errors,
    config: {
      port: parseInt(env.PORT || '3000', 10),
      nodeEnv: env.NODE_ENV || 'development',
      jwtSecret: env.JWT_SECRET,
      csrfSecret,
      corsOrigin: env.CORS_ORIGIN || 'http://localhost:5173'
    }
  };
}

const validation = validateEnv(process.env);

if (!validation.isValid) {
  if (process.env.NODE_ENV !== 'test') {
    console.error('FATAL Configuration Error:');
    validation.errors.forEach(err => console.error(` - ${err}`));
    process.exit(1);
  }
}

export const env = validation.config;
export default env;
