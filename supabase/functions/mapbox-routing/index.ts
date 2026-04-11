const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type RoutePoint = {
  latitude: number;
  longitude: number;
};

type RoutingMode = 'directions' | 'map-matching';

type MapboxRoutingRequest = {
  mode: RoutingMode;
  profile?: string;
  points: RoutePoint[];
};

function buildMapboxCoordinates(points: RoutePoint[]) {
  return points.map((point) => `${point.longitude},${point.latitude}`).join(';');
}

function buildRawGeometry(points: RoutePoint[]) {
  return {
    type: 'LineString',
    coordinates: points.map((point) => [point.longitude, point.latitude]),
  };
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    );
  }

  const body = (await request.json()) as MapboxRoutingRequest;
  if (!body.points || body.points.length < 2) {
    return new Response(
      JSON.stringify({ error: 'At least two points are required' }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    );
  }

  const mapboxSecretToken = Deno.env.get('MAPBOX_SECRET_TOKEN');
  const baseUrl = Deno.env.get('MAPBOX_BASE_URL') ?? 'https://api.mapbox.com';
  const rawGeometry = buildRawGeometry(body.points);

  if (!mapboxSecretToken) {
    return new Response(
      JSON.stringify({
        mode: body.mode,
        geometry: rawGeometry,
        provider: 'raw-fallback',
        warning: 'MAPBOX_SECRET_TOKEN is not configured; returning raw geometry.',
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    );
  }

  const profile = body.profile ?? 'driving';
  const coordinates = buildMapboxCoordinates(body.points);
  let finalUrl = '';

  if (body.mode === 'map-matching') {
    const params = new URLSearchParams({
      access_token: mapboxSecretToken,
      geometries: 'geojson',
      overview: 'full',
      tidy: 'true',
    });
    finalUrl = `${baseUrl}/matching/v5/mapbox/${profile}/${coordinates}?${params.toString()}`;
  } else {
    const params = new URLSearchParams({
      access_token: mapboxSecretToken,
      geometries: 'geojson',
      overview: 'full',
      steps: 'false',
    });
    finalUrl = `${baseUrl}/directions/v5/mapbox/${profile}/${coordinates}?${params.toString()}`;
  }

  const response = await fetch(finalUrl, {
    method: 'GET',
  });

  if (!response.ok) {
    const upstreamBody = await response.text();
    return new Response(
      JSON.stringify({
        mode: body.mode,
        geometry: rawGeometry,
        provider: 'raw-fallback',
        warning: 'Mapbox request failed; returning raw geometry.',
        upstreamStatus: response.status,
        upstreamBody,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    );
  }

  const payload = await response.json();
  const snappedCoordinates =
    body.mode === 'map-matching'
      ? payload.matchings?.[0]?.geometry?.coordinates ?? rawGeometry.coordinates
      : payload.routes?.[0]?.geometry?.coordinates ?? rawGeometry.coordinates;

  return new Response(
    JSON.stringify({
      mode: body.mode,
      geometry: {
        type: 'LineString',
        coordinates: snappedCoordinates,
      },
      provider: `mapbox-${body.mode}`,
    }),
    {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    },
  );
});
