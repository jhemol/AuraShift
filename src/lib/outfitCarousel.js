export const outfitCarouselCategories = [
  { key: 'Top', label: 'Top' },
  { key: 'Bottom', label: 'Bottom' },
  { key: 'Dress', label: 'Dress' },
  { key: 'Layer', label: 'Layer' },
  { key: 'Shoes', label: 'Shoes' },
  { key: 'Accessory', label: 'Accessory' },
]

export function groupOutfitCarouselItems(items) {
  return outfitCarouselCategories.map((category) => {
    const categoryItems = items.filter((item) => item.category === category.key)
    const carouselItems = categoryItems.length
      ? categoryItems.map((item) => ({ ...item, carouselCategory: category.key, placeholder: false }))
      : [{
          id: `placeholder-${category.key}`,
          name: `Add ${category.label.toLowerCase()}`,
          category: category.key,
          carouselCategory: category.key,
          placeholder: true,
        }]

    return {
      ...category,
      items: carouselItems.map((item, index) => ({
        ...item,
        angle: index * 360 / carouselItems.length,
      })),
    }
  })
}

export function orderOutfitCarouselItems(items) {
  return groupOutfitCarouselItems(items).flatMap((group) => group.items.map(({ angle, ...item }) => item))
}
