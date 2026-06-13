/**
 * Simple in-memory rate limiter.
 * Tracks requests per IP, returns 429 when exceeded.
 */
interface RateEntry {
  count: number;
  resetAt: number;
}

const store = new Map<string, RateEntry>();

// Clean up expired entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of store) {
    if (now > entry.resetAt) store.delete(key);
  }
}, 300_000);

export function rateLimit(maxRequests: number = 100, windowMs: number = 60000) {
  return (req: any, res: any, next: any) => {
    const ip = req.ip || req.socket?.remoteAddress || "unknown";
    const now = Date.now();
    const entry = store.get(ip);

    if (!entry || now > entry.resetAt) {
      store.set(ip, { count: 1, resetAt: now + windowMs });
      next();
      return;
    }

    entry.count++;
    if (entry.count > maxRequests) {
      res.status(429).json({
        error: "请求过于频繁，请稍后再试",
        retryAfter: Math.ceil((entry.resetAt - now) / 1000),
      });
      return;
    }
    next();
  };
}

/** Stricter limit for auth endpoints (login/register) */
export const authRateLimit = rateLimit(10, 60000);

/** General API limit */
export const apiRateLimit = rateLimit(200, 60000);
