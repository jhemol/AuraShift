const weatherRules = [
  {
    matches: (weather) => weather.precipitation > 0 || /rain|shower|storm|snow/i.test(weather.description ?? ''),
    title: 'Rain-ready picks',
    detail: 'Rain is expected. Prioritize waterproof or quick-dry pieces.',
    tags: /rain|waterproof|water-resistant|water resistant|quick-dry|umbrella/i,
    categories: ['Layer', 'Shoes'],
  },
  {
    matches: (weather) => weather.temperature <= 12,
    title: 'Warm layers',
    detail: 'It is chilly. Look for warm, cozy, or insulating pieces.',
    tags: /warm|wool|thermal|knit|coat|jacket|sweater|fleece/i,
    categories: ['Layer'],
  },
  {
    matches: (weather) => weather.temperature >= 28,
    title: 'Light and breathable',
    detail: 'It is warm. Choose breathable fabrics and lighter layers.',
    tags: /breathable|lightweight|linen|cotton|summer|sleeveless|sun/i,
    categories: ['Top', 'Dress', 'Shoes', 'Accessory'],
  },
]

export function getWeatherBasedSuggestions(items, weather, limit = 4) {
  const cleanItems = items.filter((item) => item.status === 'Clean')
  if (!weather) {
    return {
      title: 'Weather-based suggestions',
      detail: 'Add your city in Settings to get picks for local conditions.',
      items: cleanItems.slice(0, limit),
      matched: false,
    }
  }

  const rule = weatherRules.find((candidate) => candidate.matches(weather))
  if (!rule) {
    return {
      title: 'Comfortable-weather picks',
      detail: `Conditions are mild in ${weather.city}. Choose any clean pieces you love.`,
      items: cleanItems.slice(0, limit),
      matched: false,
    }
  }

  const rankedItems = cleanItems
    .map((item, index) => {
      const tags = Array.isArray(item.tags) ? item.tags : []
      const tagMatch = tags.some((tag) => rule.tags.test(tag))
      const categoryMatch = rule.categories.includes(item.category)
      return { item, index, score: Number(tagMatch) * 3 + Number(categoryMatch), tagMatch }
    })
    .sort((left, right) => right.score - left.score || left.index - right.index)
  const matched = rankedItems.some(({ tagMatch }) => tagMatch)

  return {
    title: rule.title,
    detail: matched ? rule.detail : `${rule.detail} Showing clean items; tag weather-ready pieces for more tailored picks.`,
    items: rankedItems.slice(0, limit).map(({ item }) => item),
    matched,
  }
}
