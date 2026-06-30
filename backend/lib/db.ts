import { neon } from "@neondatabase/serverless";

// Neon serverless driver. DATABASE_URL is injected by Doppler -> Vercel env.
export const sql = neon(process.env.DATABASE_URL!);
