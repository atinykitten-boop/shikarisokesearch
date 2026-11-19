import { NextResponse } from "next/server";
export async function GET() {
  return NextResponse.json({ app: "shikarisøkesearch", status: "starter", region: "Washington-first", externalActions: "disabled", note: "Configure Supabase and production integrations before live use." });
}
