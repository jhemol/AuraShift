const categories = ['Top', 'Bottom', 'Dress', 'Layer', 'Shoes', 'Accessory']
const statuses = ['Clean', 'Worn', 'Laundry']

export function getWardrobeAnalytics(items, looks) {
  const statusCounts = Object.fromEntries(statuses.map((status) => [status, 0]))
  const categoryCounts = Object.fromEntries(categories.map((category) => [category, 0]))

  for (const item of items) {
    if (Object.hasOwn(statusCounts, item.status)) statusCounts[item.status] += 1
    if (Object.hasOwn(categoryCounts, item.category)) categoryCounts[item.category] += 1
  }

  return {
    totalItems: items.length,
    plannedLooks: Object.keys(looks).length,
    statusCounts,
    categoryCounts,
  }
}

function csvCell(value) {
  return `"${String(value ?? '').replaceAll('"', '""')}"`
}

export function buildWardrobeReportCsv({ items, looks, weather, generatedAt = new Date() }) {
  const analytics = getWardrobeAnalytics(items, looks)
  const rows = [
    ['Section', 'Metric', 'Value', 'Details'],
    ['Summary', 'Generated', generatedAt.toISOString(), ''],
    ['Summary', 'Wardrobe pieces', analytics.totalItems, ''],
    ['Summary', 'Planned looks', analytics.plannedLooks, ''],
    ...statuses.map((status) => ['Status', status, analytics.statusCounts[status], '']),
    ...categories.map((category) => ['Category', category, analytics.categoryCounts[category], '']),
    ['Weather', 'City', weather?.city ?? '', ''],
    ['Weather', 'Conditions', weather?.description ?? '', ''],
    ['Weather', 'Temperature (°C)', weather?.temperature ?? '', ''],
    ['Weather', 'Precipitation (mm)', weather?.precipitation ?? '', ''],
    ...items.map((item) => [
      'Item',
      item.name,
      item.status,
      [item.category, item.color, item.season, ...(item.tags ?? [])].filter(Boolean).join('; '),
    ]),
  ]
  return rows.map((row) => row.map(csvCell).join(',')).join('\r\n')
}
