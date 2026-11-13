export function suggestOutfits(items, occasion = 'Everyday') {
  const available = items.filter((item) => !item.status || item.status === 'Clean')
  const tops = available.filter((item) => item.category === 'Top')
  const bottoms = available.filter((item) => item.category === 'Bottom')
  const layers = available.filter((item) => item.category === 'Layer')
  const shoes = available.filter((item) => item.category === 'Shoes')
  const dresses = available.filter((item) => item.category === 'Dress')
  const suggestions = []
  const styleTitles = {
    Casual: ['Easy casual layers', 'Off-duty favorite'],
    'Semi-casual': ['Relaxed polish', 'A little more put-together'],
    Work: ['A considered workday', 'Ready for the office'],
    Everyday: ['An easy everyday uniform', 'A familiar favorite'],
  }
  const titles = styleTitles[occasion] ?? styleTitles.Everyday
  for (const [index, dress] of dresses.entries()) {
    const shoe = shoes.length ? shoes[index % shoes.length] : null
    suggestions.push({
      id: `dress-${dress.id}`,
      title: `${titles[index % titles.length]} in one piece`,
      items: [dress.id, ...(shoe ? [shoe.id] : [])],
      note: `${occasion} styling built around your ${dress.color} dress.`,
    })
  }

  for (const [index, top] of tops.entries()) {
    const bottom = bottoms.length ? bottoms[index % bottoms.length] : null
    if (!bottom) continue
    const layer = layers.length && occasion !== 'Casual' ? layers[index % layers.length] : null
    const shoe = shoes.length ? shoes[index % shoes.length] : null
    const outfit = [top.id, bottom.id, ...(layer ? [layer.id] : []), ...(shoe ? [shoe.id] : [])]
    suggestions.push({
      id: `pair-${top.id}-${bottom.id}`,
      title: titles[index % titles.length],
      items: outfit,
      note: `${occasion} styling with your ${top.color} top and ${bottom.color} bottoms.`,
    })
  }

  return suggestions.slice(0, 6)
}
