// Splitway Edge Function: mapbox-routing
//
// Proxies requests to the Mapbox Map Matching API so the client never
// exposes the secret Mapbox token. Accepts an array of GPS coordinates
// and returns the matched route geometry + duration/distance metadata.
//
// POST /mapbox-routing
// Body: { coordinates: [[lng, lat], ...], profile?: "driving" | "cycling" | "walking" }
// Returns: Mapbox Map Matching API response (GeoJSON)
//
// Required env vars (set in Supabase Dashboard → Edge Functions → Secrets):
//   MAPBOX_SERVER_TOKEN — a Mapbox secret token with Map Matching scope.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const MAPBOX_BASE = "https://api.mapbox.com/matching/v5/mapbox";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface RequestBody {
  coordinates: [number, number][];
  profile?: "driving" | "cycling" | "walking";
  radiuses?: number[];
  timestamps?: number[];
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify the caller is authenticated via Supabase JWT.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const mapboxToken = Deno.env.get("MAPBOX_SERVER_TOKEN");
    if (!mapboxToken) {
      return new Response(
        JSON.stringify({ error: "MAPBOX_SERVER_TOKEN not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = (await req.json()) as RequestBody;
    const { coordinates, profile = "driving", radiuses, timestamps } = body;

    if (!coordinates || coordinates.length < 2) {
      return new Response(
        JSON.stringify({ error: "Need at least 2 coordinates" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (coordinates.length > 100) {
      return new Response(
        JSON.stringify({ error: "Maximum 100 coordinates per request" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build Mapbox Map Matching URL
    const coordString = coordinates
      .map(([lng, lat]) => `${lng},${lat}`)
      .join(";");

    const params = new URLSearchParams({
      access_token: mapboxToken,
      geometries: "geojson",
      overview: "full",
      steps: "false",
      annotations: "duration,distance,speed",
    });

    if (radiuses && radiuses.length === coordinates.length) {
      params.set("radiuses", radiuses.join(";"));
    }

    if (timestamps && timestamps.length === coordinates.length) {
      params.set("timestamps", timestamps.join(";"));
    }

    const mapboxUrl = `${MAPBOX_BASE}/${profile}/${coordString}?${params}`;

    const mapboxRes = await fetch(mapboxUrl);
    const mapboxData = await mapboxRes.json();

    if (!mapboxRes.ok) {
      return new Response(JSON.stringify(mapboxData), {
        status: mapboxRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify(mapboxData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
