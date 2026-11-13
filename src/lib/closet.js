const compareText = (first, second) => String(first ?? '').localeCompare(String(second ?? ''), undefined, { sensitivity: 'base' })

export function sortClosetItems(items, sortBy = 'recent') {
  const sorted = [...items]

  if (sortBy === 'name') return sorted.sort((a, b) => compareText(a.name, b.name))
  if (sortBy === 'category') return sorted.sort((a, b) => compareText(a.category, b.category) || compareText(a.name, b.name))
  if (sortBy === 'color') return sorted.sort((a, b) => compareText(a.color, b.color) || compareText(a.name, b.name))
  if (sortBy === 'status') return sorted.sort((a, b) => compareText(a.status, b.status) || compareText(a.name, b.name))

  return sorted
}
