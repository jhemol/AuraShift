const weatherDescriptions = {
  0: 'Clear skies',
  1: 'Mostly clear',
  2: 'Partly cloudy',
  3: 'Cloudy',
  45: 'Foggy',
  48: 'Foggy',
  51: 'Drizzle',
  53: 'Drizzle',
  55: 'Drizzle',
  61: 'Rain',
  63: 'Rain',
  65: 'Heavy rain',
  71: 'Snow',
  73: 'Snow',
  75: 'Heavy snow',
  80: 'Rain showers',
  81: 'Rain showers',
  82: 'Heavy showers',
  95: 'Thunderstorms',
  96: 'Thunderstorms',
  99: 'Thunderstorms',
}

async function getJson(url) {
  const response = await fetch(url)
  if (!response.ok) throw new Error('Weather service is temporarily unavailable.')
  return response.json()
}

export async function getWeather(city) {
  const locationUrl = new URL('https://geocoding-api.open-meteo.com/v1/search')
  locationUrl.search = new URLSearchParams({ name: city, count: '1', language: 'en', format: 'json' })
  const location = (await getJson(locationUrl)).results?.[0]
  if (!location) throw new Error('No matching city was found.')

  const forecastUrl = new URL('https://api.open-meteo.com/v1/forecast')
  forecastUrl.search = new URLSearchParams({
    latitude: location.latitude,
    longitude: location.longitude,
    current: 'temperature_2m,precipitation,weather_code',
    temperature_unit: 'celsius',
    timezone: 'auto',
  })
  const current = (await getJson(forecastUrl)).current
  if (!current) throw new Error('The weather response was incomplete.')
  return {
    city: location.name,
    temperature: current.temperature_2m,
    precipitation: current.precipitation,
    description: weatherDescriptions[current.weather_code] ?? 'Weather updated',
  }
}
