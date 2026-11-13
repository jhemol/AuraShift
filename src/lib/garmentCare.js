const statusTransitions = {
  Clean: 'Worn',
  Worn: 'Laundry',
  Laundry: 'Clean',
}

export function nextGarmentStatus(status) {
  return Object.hasOwn(statusTransitions, status) ? statusTransitions[status] : undefined
}

export function normalizeGarmentStatus(status) {
  if (status === 'Washing') return 'Laundry'
  return Object.hasOwn(statusTransitions, status) ? status : 'Clean'
}
