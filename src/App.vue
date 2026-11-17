<script setup>
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue'
import { IonApp, IonIcon } from '@ionic/vue'
import { addOutline, arrowBackOutline, arrowForwardOutline, calendarClearOutline, checkmarkCircle, closeOutline, colorPaletteOutline, helpCircleOutline, imageOutline, logOutOutline, shirtOutline, sparklesOutline, settingsOutline, sunnyOutline, syncOutline, trashOutline, waterOutline } from 'ionicons/icons'
import { coordinatePalette } from './lib/palette.js'
import { approachForDate } from './lib/dailyApproach.js'
import { sortClosetItems } from './lib/closet.js'
import { groupOutfitCarouselItems, outfitCarouselCategories } from './lib/outfitCarousel.js'
import { nextGarmentStatus, normalizeGarmentStatus } from './lib/garmentCare.js'
import { suggestOutfits } from './lib/styling.js'
import { getWeatherBasedSuggestions } from './lib/weatherSuggestions.js'
import { buildWardrobeReportCsv, getWardrobeAnalytics } from './lib/wardrobeAnalytics.js'
import { loadSharedWardrobe, loadWardrobe, saveWardrobe } from './lib/storage.js'
import { supabase } from './lib/supabase.js'
import { getWeather } from './lib/weather.js'
import { removeFlatBackground } from './lib/backgroundRemoval.js'

const today = new Date()
const keyFor = (date) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
const parseDate = (key) => { const [year, month, day] = key.split('-').map(Number); return new Date(year, month - 1, day) }
const images = {
  cream: 'https://images.unsplash.com/photo-1598033129183-c4f50c736f10?auto=format&fit=crop&w=700&q=85',
  olive: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=700&q=85',
  denim: 'https://images.unsplash.com/photo-1542272604-787c3835535d?auto=format&fit=crop&w=700&q=85',
  burgundy: 'https://images.unsplash.com/photo-1539008835657-9e8e9680c956?auto=format&fit=crop&w=700&q=85',
  navy: 'https://images.unsplash.com/photo-1576566588028-4147f3842f27?auto=format&fit=crop&w=700&q=85',
  brown: 'https://images.unsplash.com/photo-1531310197839-ccf54634509e?auto=format&fit=crop&w=700&q=85',
  red: 'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?auto=format&fit=crop&w=700&q=85',
  white: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=700&q=85',
}
async function removePhotoBackground() {
  try {
    itemForm.image = await removeFlatBackground(itemForm.image)
    itemPhotoError.value = 'Flat background removed. Review the edges before saving.'
  } catch (error) {
    itemPhotoError.value = error.message || 'The background could not be removed.'
  }
}
const productImages = {
  top1: 'https://images.pexels.com/photos/11671964/pexels-photo-11671964.jpeg?auto=compress&cs=tinysrgb&w=900',
  top2: 'https://images.pexels.com/photos/39457694/pexels-photo-39457694.jpeg?auto=compress&cs=tinysrgb&w=900',
  top3: 'https://images.pexels.com/photos/13983321/pexels-photo-13983321.jpeg?auto=compress&cs=tinysrgb&w=900',
  top4: 'https://images.pexels.com/photos/1564149/pexels-photo-1564149.jpeg?auto=compress&cs=tinysrgb&w=900',
  top5: 'https://images.pexels.com/photos/36912346/pexels-photo-36912346.jpeg?auto=compress&cs=tinysrgb&w=900',
  top6: 'https://images.pexels.com/photos/36899309/pexels-photo-36899309.jpeg?auto=compress&cs=tinysrgb&w=900',
  top7: 'https://images.pexels.com/photos/34579435/pexels-photo-34579435.jpeg?auto=compress&cs=tinysrgb&w=900',
  top8: 'https://images.pexels.com/photos/36908588/pexels-photo-36908588.jpeg?auto=compress&cs=tinysrgb&w=900',
  top9: 'https://images.pexels.com/photos/40754116/pexels-photo-40754116.jpeg?auto=compress&cs=tinysrgb&w=900',
  top10: 'https://images.pexels.com/photos/37245849/pexels-photo-37245849.jpeg?auto=compress&cs=tinysrgb&w=900',
  bottom1: 'https://images.pexels.com/photos/39457820/pexels-photo-39457820.jpeg?auto=compress&cs=tinysrgb&w=900',
  bottom2: 'https://images.pexels.com/photos/19995460/pexels-photo-19995460.jpeg?auto=compress&cs=tinysrgb&w=900',
  bottom3: 'https://images.pexels.com/photos/7202826/pexels-photo-7202826.jpeg?auto=compress&cs=tinysrgb&w=900',
  bottom4: 'https://images.pexels.com/photos/7203892/pexels-photo-7203892.jpeg?auto=compress&cs=tinysrgb&w=900',
  bottom5: 'https://images.pexels.com/photos/7202906/pexels-photo-7202906.jpeg?auto=compress&cs=tinysrgb&w=900',
  bottom6: 'https://images.pexels.com/photos/10324419/pexels-photo-10324419.jpeg?auto=compress&cs=tinysrgb&w=900',
  bottom7: 'https://images.pexels.com/photos/7202782/pexels-photo-7202782.jpeg?auto=compress&cs=tinysrgb&w=900',
  bottom8: 'https://images.pexels.com/photos/39457813/pexels-photo-39457813.jpeg?auto=compress&cs=tinysrgb&w=900',
  bottom9: 'https://images.pexels.com/photos/15221657/pexels-photo-15221657.jpeg?auto=compress&cs=tinysrgb&w=900',
  bottom10: 'https://images.pexels.com/photos/31444321/pexels-photo-31444321.jpeg?auto=compress&cs=tinysrgb&w=900',
  dress1: 'https://images.pexels.com/photos/39457810/pexels-photo-39457810.jpeg?auto=compress&cs=tinysrgb&w=900',
  dress2: 'https://images.pexels.com/photos/8619007/pexels-photo-8619007.jpeg?auto=compress&cs=tinysrgb&w=900',
  dress3: 'https://images.pexels.com/photos/19895958/pexels-photo-19895958.jpeg?auto=compress&cs=tinysrgb&w=900',
  dress4: 'https://images.pexels.com/photos/21879348/pexels-photo-21879348.jpeg?auto=compress&cs=tinysrgb&w=900',
  dress5: 'https://images.pexels.com/photos/19895961/pexels-photo-19895961.jpeg?auto=compress&cs=tinysrgb&w=900',
  dress6: 'https://images.pexels.com/photos/29997430/pexels-photo-29997430.jpeg?auto=compress&cs=tinysrgb&w=900',
  dress7: 'https://images.pexels.com/photos/5817207/pexels-photo-5817207.jpeg?auto=compress&cs=tinysrgb&w=900',
  dress8: 'https://images.pexels.com/photos/34363121/pexels-photo-34363121.jpeg?auto=compress&cs=tinysrgb&w=900',
  dress9: 'https://images.pexels.com/photos/20151744/pexels-photo-20151744.jpeg?auto=compress&cs=tinysrgb&w=900',
  dress10: 'https://images.pexels.com/photos/31410216/pexels-photo-31410216.jpeg?auto=compress&cs=tinysrgb&w=900',
  layer1: 'https://images.pexels.com/photos/16428734/pexels-photo-16428734.jpeg?auto=compress&cs=tinysrgb&w=900',
  layer2: 'https://images.pexels.com/photos/19060012/pexels-photo-19060012.jpeg?auto=compress&cs=tinysrgb&w=900',
  layer3: 'https://images.pexels.com/photos/18999070/pexels-photo-18999070.jpeg?auto=compress&cs=tinysrgb&w=900',
  layer4: 'https://images.pexels.com/photos/19014598/pexels-photo-19014598.jpeg?auto=compress&cs=tinysrgb&w=900',
  layer5: 'https://images.pexels.com/photos/18913370/pexels-photo-18913370.jpeg?auto=compress&cs=tinysrgb&w=900',
  layer6: 'https://images.pexels.com/photos/19230345/pexels-photo-19230345.jpeg?auto=compress&cs=tinysrgb&w=900',
  layer7: 'https://images.pexels.com/photos/19014600/pexels-photo-19014600.jpeg?auto=compress&cs=tinysrgb&w=900',
  layer8: 'https://images.pexels.com/photos/19584321/pexels-photo-19584321.jpeg?auto=compress&cs=tinysrgb&w=900',
  layer9: 'https://images.pexels.com/photos/19129083/pexels-photo-19129083.jpeg?auto=compress&cs=tinysrgb&w=900',
  layer10: 'https://images.pexels.com/photos/19501283/pexels-photo-19501283.jpeg?auto=compress&cs=tinysrgb&w=900',
  shoe1: 'https://images.pexels.com/photos/27617195/pexels-photo-27617195.jpeg?auto=compress&cs=tinysrgb&w=900',
  shoe2: 'https://images.pexels.com/photos/14212621/pexels-photo-14212621.jpeg?auto=compress&cs=tinysrgb&w=900',
  shoe3: 'https://images.pexels.com/photos/5168531/pexels-photo-5168531.jpeg?auto=compress&cs=tinysrgb&w=900',
  shoe4: 'https://images.pexels.com/photos/10827097/pexels-photo-10827097.jpeg?auto=compress&cs=tinysrgb&w=900',
  shoe5: 'https://images.pexels.com/photos/27426618/pexels-photo-27426618.jpeg?auto=compress&cs=tinysrgb&w=900',
  shoe6: 'https://images.pexels.com/photos/27398615/pexels-photo-27398615.png?auto=compress&cs=tinysrgb&w=900',
  shoe7: 'https://images.pexels.com/photos/12112062/pexels-photo-12112062.jpeg?auto=compress&cs=tinysrgb&w=900',
  shoe8: 'https://images.pexels.com/photos/27127377/pexels-photo-27127377.jpeg?auto=compress&cs=tinysrgb&w=900',
  shoe9: 'https://images.pexels.com/photos/27018344/pexels-photo-27018344.jpeg?auto=compress&cs=tinysrgb&w=900',
  shoe10: 'https://images.pexels.com/photos/5168562/pexels-photo-5168562.jpeg?auto=compress&cs=tinysrgb&w=900',
  bag1: 'https://images.pexels.com/photos/22432989/pexels-photo-22432989.jpeg?auto=compress&cs=tinysrgb&w=900',
  bag2: 'https://images.pexels.com/photos/2986445/pexels-photo-2986445.jpeg?auto=compress&cs=tinysrgb&w=900',
  bag3: 'https://images.pexels.com/photos/8989582/pexels-photo-8989582.jpeg?auto=compress&cs=tinysrgb&w=900',
  bag4: 'https://images.pexels.com/photos/1460838/pexels-photo-1460838.jpeg?auto=compress&cs=tinysrgb&w=900',
  bag5: 'https://images.pexels.com/photos/5352628/pexels-photo-5352628.jpeg?auto=compress&cs=tinysrgb&w=900',
  bag6: 'https://images.pexels.com/photos/27503501/pexels-photo-27503501.png?auto=compress&cs=tinysrgb&w=900',
  bag7: 'https://images.pexels.com/photos/15674425/pexels-photo-15674425.jpeg?auto=compress&cs=tinysrgb&w=900',
  bag8: 'https://images.pexels.com/photos/30592270/pexels-photo-30592270.jpeg?auto=compress&cs=tinysrgb&w=900',
  bag9: 'https://images.pexels.com/photos/19869756/pexels-photo-19869756.jpeg?auto=compress&cs=tinysrgb&w=900',
  bag10: 'https://images.pexels.com/photos/14108006/pexels-photo-14108006.jpeg?auto=compress&cs=tinysrgb&w=900',
}

async function refreshWeather() {
  const city = state.settings.city.trim()
  if (!city) { weather.value = null; weatherError.value = 'Add a city in preferences to see local weather.'; return }
  weatherLoading.value = true
  weatherError.value = ''
  try { weather.value = await getWeather(city) } catch (error) { weather.value = null; weatherError.value = error.message || 'Weather could not be loaded.' }
  finally { weatherLoading.value = false }
  if (weather.value?.precipitation > 0) {
    const key = `${todayKey}:${city.toLowerCase()}`
    const hasRainReady = state.items.some((item) => item.status === 'Clean' && (item.tags ?? []).some((tag) => /rain|waterproof/i.test(tag)))
    if (!hasRainReady && weatherReminderKey.value !== key) {
      weatherReminderKey.value = key
      notify('Weather outfit reminder', 'Rain is expected. Consider a rain-ready or waterproof piece.')
    }
  }
}
function setGarmentStatus(item) {
  const nextStatus = nextGarmentStatus(item.status)
  if (!nextStatus) return
  item.status = nextStatus
  if (nextStatus === 'Laundry') {
    item.laundryStartedAt = new Date().toISOString()
    item.laundryDurationMinutes = Number(item.laundryDurationMinutes) || 45
  } else {
    item.laundryStartedAt = ''
  }
  if (nextStatus === 'Clean') notify('Laundry complete', `${item.name} is ready to wear again.`)
  if (nextStatus === 'Laundry') notify('Laundry started', `${item.name} is in the laundry queue.`)
}
function addWeatherSuggestion(item) {
  if (item.status !== 'Clean') return
  const currentLook = state.looks[selected.value]
  const currentItems = currentLook?.items ?? []
  if (currentItems.includes(item.id)) return
  state.looks[selected.value] = {
    title: currentLook?.title || 'Weather-ready look',
    note: currentLook?.note || '',
    event: currentLook?.event || '',
    eventTime: currentLook?.eventTime || '',
    items: [...currentItems, item.id],
  }
}
function downloadWardrobeReport() {
  const report = buildWardrobeReportCsv({
    items: state.items,
    looks: state.looks,
    weather: weather.value,
  })
  const url = URL.createObjectURL(new Blob([`\uFEFF${report}`], { type: 'text/csv;charset=utf-8' }))
  const link = document.createElement('a')
  link.href = url
  link.download = `aurashift-wardrobe-report-${todayKey}.csv`
  document.body.append(link)
  link.click()
  link.remove()
  window.setTimeout(() => URL.revokeObjectURL(url), 1000)
}
async function markLookWorn() {
  outfitItems.value.forEach((item) => { if (item.status === 'Clean') setGarmentStatus(item) })
}
async function enableReminders() {
  if (!('Notification' in window)) { reminderMessage.value = 'This browser does not support notifications.'; return }
  const permission = await Notification.requestPermission()
  notificationsEnabled.value = permission === 'granted'
  reminderMessage.value = permission === 'granted' ? 'Gentle reminders are enabled while AuraShift is open.' : 'Notifications are blocked in browser settings.'
}
function notify(title, body) {
  reminderMessage.value = body
  if ('Notification' in window && Notification.permission === 'granted') new Notification(title, { body })
}
function updateLaundry() {
  const now = Date.now()
  for (const item of laundryItems.value) {
    const started = Date.parse(item.laundryStartedAt ?? '')
    const duration = Math.max(1, Number(item.laundryDurationMinutes) || 45) * 60_000
    if (Number.isFinite(started) && now - started >= duration) setGarmentStatus(item)
  }
}
function beginCarouselDrag(event, categoryKey) {
  lastCarouselDrag = { categoryKey, x: event.clientX, moved: false }
  const captureTarget = typeof event.target.setPointerCapture === 'function' ? event.target : event.currentTarget
  captureTarget.setPointerCapture(event.pointerId)
}
function rotateCarousel(event) {
  if (!lastCarouselDrag) return
  const delta = event.clientX - lastCarouselDrag.x
  if (Math.abs(delta) > 3) lastCarouselDrag.moved = true
  carouselRotations[lastCarouselDrag.categoryKey] += delta * 0.35
  lastCarouselDrag.x = event.clientX
}
function endCarouselDrag() {
  if (!lastCarouselDrag) return
  const dragged = lastCarouselDrag.moved
  lastCarouselDrag = null
  if (dragged) setTimeout(() => { suppressCarouselClick = false }, 0)
  suppressCarouselClick = dragged
}
function toggleCarouselItem(item) {
  if (!suppressCarouselClick) toggleItem(item.id)
}
function focusCarouselItem(group, item) { carouselRotations[group.key] = -item.angle }
function stepCarousel(group, direction) {
  const options = group.items.filter((item) => !item.placeholder)
  if (options.length < 2) return
  const currentIndex = options.findIndex((item) => item.id === activeCarouselItem(group)?.id)
  const nextIndex = (currentIndex + direction + options.length) % options.length
  focusCarouselItem(group, options[nextIndex])
}
function activeCarouselItem(group) {
  const normalize = (angle) => ((angle % 360) + 540) % 360 - 180
  return group.items.reduce((closest, item) =>
    Math.abs(normalize(item.angle + carouselRotations[group.key])) < Math.abs(normalize(closest.angle + carouselRotations[group.key])) ? item : closest,
  )
}
const createStarterItems = (entries) => entries.map(([id, name, category, color, colorHex]) => ({ id, name, category, color, colorHex, image: productImages[id] ?? images[color], season: 'All season', brand: '', tags: [], status: 'Clean', laundryDurationMinutes: 45 }))
const additionalStarterItems = createStarterItems([
  ['top3', 'Classic cotton button-down', 'Top', 'white', '#e4e1d8'],
  ['top4', 'Striped boatneck tee', 'Top', 'navy', '#34475b'],
  ['top5', 'Soft crewneck sweater', 'Top', 'burgundy', '#794b54'],
  ['top6', 'Relaxed linen blouse', 'Top', 'cream', '#d9cdb8'],
  ['top7', 'Everyday polo shirt', 'Top', 'olive', '#77795a'],
  ['top8', 'Sleeveless ribbed tank', 'Top', 'brown', '#805c47'],
  ['top9', 'Lightweight graphic tee', 'Top', 'red', '#ac5b4c'],
  ['top10', 'Textured knit top', 'Top', 'denim', '#617c91'],
  ['bottom2', 'Wide-leg linen trousers', 'Bottom', 'cream', '#d9cdb8'],
  ['bottom3', 'Tailored black trousers', 'Bottom', 'navy', '#34475b'],
  ['bottom4', 'Relaxed chino pants', 'Bottom', 'brown', '#805c47'],
  ['bottom5', 'Pleated midi skirt', 'Bottom', 'burgundy', '#794b54'],
  ['bottom6', 'Classic denim shorts', 'Bottom', 'denim', '#617c91'],
  ['bottom7', 'Straight-leg khakis', 'Bottom', 'olive', '#77795a'],
  ['bottom8', 'Flowy printed skirt', 'Bottom', 'red', '#ac5b4c'],
  ['bottom9', 'Everyday joggers', 'Bottom', 'white', '#e4e1d8'],
  ['bottom10', 'Dark wash jeans', 'Bottom', 'navy', '#34475b'],
  ['dress2', 'Floral wrap dress', 'Dress', 'red', '#ac5b4c'],
  ['dress3', 'Cotton shirt dress', 'Dress', 'white', '#e4e1d8'],
  ['dress4', 'Knit sweater dress', 'Dress', 'olive', '#77795a'],
  ['dress5', 'Pleated midi dress', 'Dress', 'navy', '#34475b'],
  ['dress6', 'Linen sundress', 'Dress', 'cream', '#d9cdb8'],
  ['dress7', 'Little black dress', 'Dress', 'brown', '#805c47'],
  ['dress8', 'Denim pinafore dress', 'Dress', 'denim', '#617c91'],
  ['dress9', 'Soft jersey maxi dress', 'Dress', 'burgundy', '#794b54'],
  ['dress10', 'Casual printed dress', 'Dress', 'red', '#ac5b4c'],
  ['layer2', 'Classic denim jacket', 'Layer', 'denim', '#617c91'],
  ['layer3', 'Lightweight trench coat', 'Layer', 'cream', '#d9cdb8'],
  ['layer4', 'Zip-up hoodie', 'Layer', 'olive', '#77795a'],
  ['layer5', 'Tailored blazer', 'Layer', 'navy', '#34475b'],
  ['layer6', 'Quilted vest', 'Layer', 'brown', '#805c47'],
  ['layer7', 'Cozy fleece jacket', 'Layer', 'white', '#e4e1d8'],
  ['layer8', 'Longline raincoat', 'Layer', 'red', '#ac5b4c'],
  ['layer9', 'Light knit shrug', 'Layer', 'burgundy', '#794b54'],
  ['layer10', 'Relaxed utility jacket', 'Layer', 'denim', '#617c91'],
  ['shoe3', 'Minimal white trainers', 'Shoes', 'white', '#e4e1d8'],
  ['shoe4', 'Leather ankle boots', 'Shoes', 'brown', '#805c47'],
  ['shoe5', 'Classic ballet flats', 'Shoes', 'burgundy', '#794b54'],
  ['shoe6', 'Strappy sandals', 'Shoes', 'cream', '#d9cdb8'],
  ['shoe7', 'Low-top canvas shoes', 'Shoes', 'red', '#ac5b4c'],
  ['shoe8', 'Smart block heels', 'Shoes', 'navy', '#34475b'],
  ['shoe9', 'Everyday slip-ons', 'Shoes', 'olive', '#77795a'],
  ['shoe10', 'Casual leather mules', 'Shoes', 'denim', '#617c91'],
  ['bag2', 'Structured shoulder bag', 'Accessory', 'brown', '#805c47'],
  ['bag3', 'Simple leather belt', 'Accessory', 'navy', '#34475b'],
  ['bag4', 'Soft wool scarf', 'Accessory', 'burgundy', '#794b54'],
  ['bag5', 'Classic baseball cap', 'Accessory', 'olive', '#77795a'],
  ['bag6', 'Delicate gold necklace', 'Accessory', 'cream', '#d9cdb8'],
  ['bag7', 'Everyday crossbody bag', 'Accessory', 'red', '#ac5b4c'],
  ['bag8', 'Knitted beanie', 'Accessory', 'white', '#e4e1d8'],
  ['bag9', 'Lightweight silk scarf', 'Accessory', 'denim', '#617c91'],
  ['bag10', 'Woven summer tote', 'Accessory', 'brown', '#805c47'],
])
const starterItems = [
  ...createStarterItems([
    ['top1', 'Linen overshirt', 'Top', 'cream', '#d9cdb8'], ['top2', 'Ribbed knit tee', 'Top', 'olive', '#77795a'],
    ['bottom1', 'Relaxed straight denim', 'Bottom', 'denim', '#617c91'], ['dress1', 'Sunday slip dress', 'Dress', 'burgundy', '#794b54'],
    ['layer1', 'Soft wool cardigan', 'Layer', 'navy', '#34475b'], ['shoe1', 'Everyday loafers', 'Shoes', 'brown', '#805c47'],
    ['bag1', 'Market tote', 'Accessory', 'red', '#ac5b4c'], ['shoe2', 'Canvas sneakers', 'Shoes', 'white', '#e4e1d8'],
  ]),
  ...additionalStarterItems,
]
const todayKey = keyFor(today)
const sampleLooks = {}
for (const offset of [0, 2, 4, 6, 8]) {
  const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() + offset)
  sampleLooks[keyFor(date)] = { title: ['Easy layers', 'Soft neutrals', 'Color study', 'Weekend uniform', 'Blue hour'][offset / 2], note: offset === 0 ? 'A little texture, a lot of ease.' : '', items: date.getDay() === 0 ? ['dress1', 'shoe1'] : ['top1', 'bottom1', 'layer1', 'shoe1'] }
}
const state = reactive({ items: structuredClone(starterItems), looks: sampleLooks, settings: { weekStarts: 0, showLookNames: true, accent: 'forest', theme: 'light', profileName: '', profileStyle: 'All styles', city: '', stylePreference: 'Everyday', colorBlindMode: 'None', auraIntensity: 65, sampleCatalogVersion: 3 } })
const month = ref(new Date(today.getFullYear(), today.getMonth(), 1))
const selected = ref(todayKey)
const page = ref('Calendar')
const modal = ref('')
const status = ref('Saved locally')
const syncError = ref('')
const syncingFromMobile = ref(false)
const applyingSharedData = ref(false)
const tourOpen = ref(false)
const tourIndex = ref(0)
const lookForm = reactive({ title: '', note: '', event: '', eventTime: '', items: [] })
const itemForm = reactive({ name: '', category: 'Top', color: 'blue', colorHex: '#6487a5', image: '', season: 'All season', brand: '', tags: '', laundryDurationMinutes: 45 })
const itemPhotoName = ref('')
const itemPhotoError = ref('')
const itemPhotoUrl = ref('')
const filter = reactive({ category: 'All', search: '' })
const closetSort = ref('recent')
const styleOccasion = ref('Everyday')
const outfitStyles = ['Casual', 'Semi-casual', 'Work', 'Everyday']
const styleReferencePhotos = {
  Casual: [
    'https://images.pexels.com/photos/27542890/pexels-photo-27542890.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/8811247/pexels-photo-8811247.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/29047212/pexels-photo-29047212.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/15576193/pexels-photo-15576193.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/30381007/pexels-photo-30381007.jpeg?auto=compress&cs=tinysrgb&w=900',
  ],
  'Semi-casual': [
    'https://images.pexels.com/photos/7760002/pexels-photo-7760002.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/15343587/pexels-photo-15343587.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/30833074/pexels-photo-30833074.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/6211660/pexels-photo-6211660.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/36905971/pexels-photo-36905971.jpeg?auto=compress&cs=tinysrgb&w=900',
  ],
  Work: [
    'https://images.pexels.com/photos/10532718/pexels-photo-10532718.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/17323594/pexels-photo-17323594.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/16970143/pexels-photo-16970143.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/26728093/pexels-photo-26728093.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/30468649/pexels-photo-30468649.jpeg?auto=compress&cs=tinysrgb&w=900',
  ],
  Everyday: [
    'https://images.pexels.com/photos/32870716/pexels-photo-32870716.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/8217535/pexels-photo-8217535.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/28494855/pexels-photo-28494855.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/616376/pexels-photo-616376.jpeg?auto=compress&cs=tinysrgb&w=900',
    'https://images.pexels.com/photos/38432409/pexels-photo-38432409.jpeg?auto=compress&cs=tinysrgb&w=900',
  ],
}
const closetOutfitStyle = ref('Casual')
const weather = ref(null)
const weatherError = ref('')
const weatherLoading = ref(false)
const weatherRainFilter = ref(false)
const carouselRotations = reactive(Object.fromEntries(outfitCarouselCategories.map(({ key }) => [key, 0])))
const reminderMessage = ref('')
const notificationsEnabled = ref(false)
const clockNow = ref(Date.now())
const weatherReminderKey = ref('')
const ready = ref(false)
let saveTimer
let lastCarouselDrag = null
let suppressCarouselClick = false

const monthLabel = computed(() => new Intl.DateTimeFormat('en', { month: 'long', year: 'numeric' }).format(month.value))
const dateLabel = computed(() => new Intl.DateTimeFormat('en', { weekday: 'long', month: 'long', day: 'numeric' }).format(parseDate(selected.value)))
const selectedLook = computed(() => state.looks[selected.value])
const dailyApproach = computed(() => approachForDate(parseDate(selected.value)))
const outfitItems = computed(() => (selectedLook.value?.items ?? []).map((id) => state.items.find((item) => item.id === id)).filter(Boolean))
const previewItems = computed(() => lookForm.items.map((id) => state.items.find((item) => item.id === id)).filter(Boolean))
const previewPalette = computed(() => coordinatePalette(previewItems.value.map((item) => item.color)))
const hasAuraScore = computed(() => new Set(previewItems.value.map((item) => item.category)).size > 1)
const carouselGroups = computed(() => {
  const selectedIds = new Set(lookForm.items)
  return groupOutfitCarouselItems(pickerItems.value).map((group) => ({
    ...group,
    items: group.items.map((item) => ({ ...item, selected: selectedIds.has(item.id) })),
  }))
})
const palette = computed(() => coordinatePalette(outfitItems.value.map((item) => item.color)))
const cells = computed(() => {
  const first = new Date(month.value.getFullYear(), month.value.getMonth(), 1)
  const offset = (first.getDay() - state.settings.weekStarts + 7) % 7
  const count = new Date(month.value.getFullYear(), month.value.getMonth() + 1, 0).getDate()
  const total = Math.ceil((offset + count) / 7) * 7
  return Array.from({ length: total }, (_, index) => {
    const date = new Date(month.value.getFullYear(), month.value.getMonth(), index - offset + 1)
    return { date, key: keyFor(date), current: date.getMonth() === month.value.getMonth() }
  })
})
const weekdays = computed(() => { const all = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']; return [...all.slice(state.settings.weekStarts), ...all.slice(0, state.settings.weekStarts)] })
const categories = ['All', 'Top', 'Bottom', 'Dress', 'Layer', 'Shoes', 'Accessory']
const stylingIdeas = computed(() => {
  const photos = styleReferencePhotos[styleOccasion.value] ?? styleReferencePhotos.Everyday
  return suggestOutfits(weatherSuggestedItems.value, styleOccasion.value).map((idea, index) => ({ ...idea, photo: photos[index % photos.length] }))
})
const tourSteps = [
  {
    eyebrow: 'A WARDROBE THAT WORKS FOR YOU',
    title: 'Start with what you already own.',
    description: 'Bring your pieces into one digital closet. Add a name, category, color, season, and a photo so your wardrobe is easy to browse.',
    image: images.cream,
    imageAlt: 'A neutral wardrobe piece',
    action: 'Explore your closet',
    page: 'Closet',
  },
  {
    eyebrow: 'A STYLIST THAT STARTS WITH YOUR CLOSET',
    title: 'Find a new way to wear what you own.',
    description: 'Browse outfit pairings built from the pieces already in your closet. Choose an occasion to shift the suggestions, then make any idea your own.',
    image: images.olive,
    imageAlt: 'A wardrobe styling idea',
    action: 'Explore style ideas',
    page: 'Style ideas',
  },
  {
    eyebrow: 'YOUR OUTFIT, YOUR CANVAS',
    title: 'Build a look piece by piece.',
    description: 'Choose garments, give the outfit a name, and keep a note about the mood or occasion. See its colors come together as you select.',
    image: images.denim,
    imageAlt: 'Everyday blue denim',
    action: 'Open outfit canvas',
    page: 'Calendar',
    canvas: true,
  },
  {
    eyebrow: 'A LITTLE PLAN, A LITTLE FREEDOM',
    title: 'Give each day its own approach.',
    description: 'Place an OOTD on any date, move between months, choose when your week begins, and keep the looks you want to remember.',
    image: images.cream,
    imageAlt: 'A softly layered outfit',
    action: 'Open calendar settings',
    page: 'Calendar',
    settings: true,
  },
  {
    eyebrow: 'NOTICE YOUR COLOR RHYTHM',
    title: 'See the palette take shape.',
    description: 'Color notes gather the colors in your closet, while each saved outfit gets a harmony score to help you experiment.',
    image: images.red,
    imageAlt: 'A burgundy outfit inspiration',
    action: 'Explore color notes',
    page: 'Color notes',
  },
]
const closetItems = computed(() => {
  const search = filter.search.trim().toLocaleLowerCase()
  return state.items.filter((item) =>
    (filter.category === 'All' || item.category === filter.category) &&
    (!search || [item.name, item.brand, item.color, ...(item.tags ?? [])].some((value) => String(value ?? '').toLocaleLowerCase().includes(search))) &&
    (!weatherRainFilter.value || (item.tags ?? []).some((tag) => /rain|waterproof/i.test(tag))),
  )
})
const sortedClosetItems = computed(() => sortClosetItems(closetItems.value, closetSort.value))
const heroImage = computed(() => outfitItems.value.find((item) => item.category === 'Dress')?.image ?? outfitItems.value.find((item) => item.category === 'Top')?.image)
const auraColor = computed(() => outfitItems.value[0]?.colorHex ?? '#59745c')
const availableItems = computed(() => state.items.filter((item) => item.status === 'Clean'))
const pickerItems = computed(() => state.items.filter((item) => {
  const alreadySelected = lookForm.items.includes(item.id)
  if (item.status !== 'Clean') return alreadySelected
  if (!weatherRainFilter.value) return true
  return (item.tags ?? []).some((tag) => /rain|waterproof|warm|wool|thermal/i.test(tag))
}))
const laundryItems = computed(() => state.items.filter((item) => item.status === 'Laundry'))
const wardrobeAnalytics = computed(() => getWardrobeAnalytics(state.items, state.looks))
const laundryMinutesLeft = (item) => Math.max(0, Math.ceil(((Number(item.laundryDurationMinutes) || 45) * 60_000 - (clockNow.value - Date.parse(item.laundryStartedAt || ''))) / 60_000))
const weatherSuggestion = computed(() => getWeatherBasedSuggestions(state.items, weather.value))
const weatherSuggestedItems = computed(() => weatherSuggestion.value.items)

watch(state, () => {
  if (!ready.value || applyingSharedData.value) return
  status.value = 'Saving'
  clearTimeout(saveTimer)
  saveTimer = setTimeout(async () => {
    try {
      const result = await saveWardrobe(state)
      status.value = result.synced ? 'Synced' : result.localSaved ? 'Saved locally · Sync pending' : 'Sync failed'
      syncError.value = result.error ?? ''
    } catch (error) {
      status.value = 'Sync failed'
      syncError.value = error.message || 'The wardrobe could not be saved.'
    }
  }, 350)
}, { deep: true })
watch(() => state.settings.stylePreference, (preference) => {
  if (outfitStyles.includes(preference)) styleOccasion.value = preference
})
onMounted(async () => {
  const saved = await loadWardrobe()
  if (saved && Array.isArray(saved.items)) {
    const savedItemIds = new Set(saved.items.map((item) => item.id))
    const needsCatalogUpdate = saved.items.length > 0 && Number(saved.settings?.sampleCatalogVersion ?? 0) < 2
    const migratedItems = needsCatalogUpdate ? additionalStarterItems.filter((item) => !savedItemIds.has(item.id)) : []
    state.items = [...saved.items.map((item) => {
      const sample = starterItems.find((starter) => starter.id === item.id)
      return {
        ...item,
        status: normalizeGarmentStatus(item.status),
        ...(sample && item.image === images[sample.color] && productImages[sample.id] ? { image: productImages[sample.id] } : {}),
      }
    }), ...migratedItems]
    state.looks = saved.looks ?? {}
    state.settings = { ...state.settings, ...saved.settings, sampleCatalogVersion: 3 }
    delete state.settings.timerMinutes
    state.items = state.items.map((item) => ({ status: 'Clean', brand: '', tags: [], laundryDurationMinutes: 45, ...item }))
  }
  ready.value = true
  refreshWeather()
  updateLaundry()
  const timer = setInterval(updateLaundry, 15_000)
  const clockTimer = setInterval(() => { clockNow.value = Date.now() }, 15_000)
  window.addEventListener('beforeunload', () => clearInterval(timer), { once: true })
  window.addEventListener('beforeunload', () => clearInterval(clockTimer), { once: true })
  notificationsEnabled.value = 'Notification' in window && Notification.permission === 'granted'
  if (localStorage.getItem('thread-walkthrough-complete') !== 'yes') tourOpen.value = true
})

async function syncFromMobile() {
  if (syncingFromMobile.value || status.value === 'Saving') return
  syncingFromMobile.value = true
  try {
    const result = await loadSharedWardrobe()
    if (!result.data) {
      status.value = 'Sync failed'
      syncError.value = result.error || 'Shared wardrobe data is unavailable.'
      return
    }
    applyingSharedData.value = true
    state.items = result.data.items.map((item) => ({
      status: 'Clean',
      brand: '',
      tags: [],
      laundryDurationMinutes: 45,
      ...item,
      status: normalizeGarmentStatus(item.status),
    }))
    state.looks = result.data.looks ?? {}
    state.settings = { ...state.settings, ...result.data.settings }
    delete state.settings.timerMinutes
    await nextTick()
    applyingSharedData.value = false
    status.value = result.error ? 'Synced · cache issue' : 'Synced with mobile'
    syncError.value = result.error ?? ''
    refreshWeather()
  } catch (error) {
    applyingSharedData.value = false
    status.value = 'Sync failed'
    syncError.value = error.message || 'The shared wardrobe could not be loaded.'
  } finally {
    syncingFromMobile.value = false
  }
}

function changeMonth(amount) { month.value = new Date(month.value.getFullYear(), month.value.getMonth() + amount, 1) }
async function signOut() {
  const { error } = await supabase.auth.signOut()
  if (error) status.value = 'Sign out failed'
}
function openLook(date = selected.value) {
  selected.value = date
  const look = state.looks[date]
  lookForm.title = look?.title ?? ''; lookForm.note = look?.note ?? ''; lookForm.event = look?.event ?? ''; lookForm.eventTime = look?.eventTime ?? ''; lookForm.items = [...(look?.items ?? [])]
  for (const { key } of outfitCarouselCategories) carouselRotations[key] = 0
  modal.value = 'look'
}
function toggleItem(id) {
  const at = lookForm.items.indexOf(id)
  at < 0 ? lookForm.items.push(id) : lookForm.items.splice(at, 1)
  const item = state.items.find((candidate) => candidate.id === id)
  if (at >= 0 && item?.status !== 'Clean' && item && Object.hasOwn(carouselRotations, item.category)) {
    carouselRotations[item.category] = 0
  }
}
function saveLook() {
  if (lookForm.items.length) state.looks[selected.value] = { title: lookForm.title.trim() || 'A new look', note: lookForm.note.trim(), event: lookForm.event.trim(), eventTime: lookForm.eventTime, items: [...lookForm.items] }
  else delete state.looks[selected.value]
  modal.value = ''
}
function deleteLook() { delete state.looks[selected.value]; modal.value = '' }
function addItem() {
  if (!itemForm.name.trim()) return
  state.items.unshift({ ...itemForm, tags: itemForm.tags.split(',').map((tag) => tag.trim()).filter(Boolean), id: `item-${Date.now()}`, image: itemPhotoName.value ? itemForm.image : itemPhotoUrl.value || images[itemForm.color] || images.white, status: 'Clean' })
  Object.assign(itemForm, { name: '', category: 'Top', color: 'blue', colorHex: '#6487a5', image: '', season: 'All season', brand: '', tags: '', laundryDurationMinutes: 45 })
  itemPhotoName.value = ''; itemPhotoError.value = ''; itemPhotoUrl.value = ''
  modal.value = ''
}
async function chooseItemPhoto(event) {
  const file = event.target.files?.[0]
  event.target.value = ''
  if (!file) return
  if (!file.type.startsWith('image/')) { itemPhotoError.value = 'Choose an image file.'; return }
  if (file.size > 15 * 1024 * 1024) { itemPhotoError.value = 'Choose an image smaller than 15 MB.'; return }
  const objectUrl = URL.createObjectURL(file)
  try {
    const image = new Image()
    image.src = objectUrl
    await new Promise((resolve, reject) => { image.onload = resolve; image.onerror = reject })
    const scale = Math.min(1, 900 / Math.max(image.naturalWidth, image.naturalHeight))
    const canvas = document.createElement('canvas')
    canvas.width = Math.max(1, Math.round(image.naturalWidth * scale))
    canvas.height = Math.max(1, Math.round(image.naturalHeight * scale))
    canvas.getContext('2d').drawImage(image, 0, 0, canvas.width, canvas.height)
    itemForm.image = canvas.toDataURL('image/jpeg', 0.8)
    itemPhotoName.value = file.name
    itemPhotoError.value = ''
  } catch {
    itemPhotoError.value = 'That image could not be opened. Try another photo.'
  } finally {
    URL.revokeObjectURL(objectUrl)
  }
}
function removeItem(id) { state.items = state.items.filter((item) => item.id !== id); Object.values(state.looks).forEach((look) => { look.items = look.items.filter((itemId) => itemId !== id) }) }
function saveStylingIdea(idea) {
  selected.value = todayKey
  state.looks[todayKey] = { title: idea.title, note: idea.note, items: [...idea.items] }
  page.value = 'Calendar'
}
function finishTour() {
  localStorage.setItem('thread-walkthrough-complete', 'yes')
  tourOpen.value = false
}
function continueTour() {
  if (tourIndex.value < tourSteps.length - 1) tourIndex.value += 1
  else {
    page.value = tourSteps[tourIndex.value].page
    finishTour()
  }
}
function openTour() { tourIndex.value = 0; tourOpen.value = true }
function visitTourFeature() {
  const step = tourSteps[tourIndex.value]
  page.value = step.page
  if (step.settings) modal.value = 'settings'
  if (step.canvas) openLook()
  finishTour()
}
</script>

<template>
  <IonApp>
    <div class="app-shell" :data-accent="state.settings.accent" :data-theme="state.settings.theme" :data-colorblind="state.settings.colorBlindMode" :style="{ '--aura': auraColor, '--aura-opacity': Number(state.settings.auraIntensity) / 100 }">
      <aside class="sidebar">
        <a class="brand" href="#calendar" @click.prevent="page = 'Calendar'"><span class="brand-mark"><img src="/aura-mark.png" alt="" /></span>Aura<span class="brand-period">Shift</span></a>
        <div class="side-label">YOUR SPACE</div>
        <nav class="main-nav" aria-label="Main navigation">
          <button :class="{ active: page === 'Calendar' }" @click="page = 'Calendar'"><IonIcon :icon="calendarClearOutline" />Calendar</button>
          <button :class="{ active: page === 'Closet' }" @click="page = 'Closet'"><IonIcon :icon="shirtOutline" />My closet <span class="nav-count">{{ state.items.length }}</span></button>
          <button :class="{ active: page === 'Style ideas' }" @click="page = 'Style ideas'"><IonIcon :icon="sparklesOutline" />Style ideas</button>
          <button :class="{ active: page === 'Color notes' }" @click="page = 'Color notes'"><IonIcon :icon="colorPaletteOutline" />Color notes</button>
          <button :class="{ active: page === 'Laundry' }" @click="page = 'Laundry'"><IonIcon :icon="waterOutline" />Laundry queue <span class="nav-count">{{ laundryItems.length }}</span></button>
        </nav>
        <div class="sidebar-bottom"><div class="mini-weather"><IonIcon :icon="weather?.precipitation > 0 ? waterOutline : sunnyOutline" /><div><strong>{{ weather ? `${weather.description} in ${weather.city}` : 'Local weather' }}</strong><span>{{ weather ? `${Math.round(weather.temperature)}°C · ${weather.precipitation} mm rain` : weatherError || 'Set your city in preferences' }}</span></div></div><button class="profile-button" @click="modal = 'settings'"><span class="avatar">{{ (state.settings.profileName || 'A').slice(0, 1).toUpperCase() }}</span><span><strong>{{ state.settings.profileName || 'Your wardrobe' }}</strong><small>{{ state.settings.profileStyle }} · {{ state.settings.stylePreference || 'Personal style' }}</small></span></button></div>
      </aside>
      <main class="main-content">
        <header class="topbar"><div class="breadcrumb">My space <span>/</span> <strong>{{ page }}</strong></div><div class="top-actions"><span v-if="weather" class="weather-summary">{{ weather.city }} · {{ Math.round(weather.temperature) }}° · {{ weather.description }}</span><span class="save-indicator" :title="syncError"><i></i>{{ status }}</span><button class="icon-button" aria-label="Sync with mobile" title="Pull latest wardrobe from mobile" :disabled="syncingFromMobile" @click="syncFromMobile"><IonIcon :icon="syncOutline" /></button><button class="icon-button" aria-label="Walkthrough" title="Walkthrough" @click="openTour()"><IonIcon :icon="helpCircleOutline" /></button><button class="icon-button" aria-label="Calendar settings" @click="modal = 'settings'"><IonIcon :icon="settingsOutline" /></button><button class="icon-button" aria-label="Sign out" title="Sign out" @click="signOut"><IonIcon :icon="logOutOutline" /></button></div></header>

        <section v-if="page === 'Calendar'" class="page-wrap">
          <div class="page-heading"><div><p class="eyebrow">A little more intention, every day</p><h1>Outfit calendar</h1><p class="heading-note">Plan a week of getting dressed like yourself.</p></div><button class="primary-button" @click="openLook()"><IonIcon :icon="addOutline" />Plan an outfit</button></div>
          <div class="planner-grid">
            <section class="calendar-panel" aria-label="Outfit calendar">
              <div class="calendar-toolbar"><div class="month-switch"><h2>{{ monthLabel }}</h2><button class="icon-button" aria-label="Previous month" @click="changeMonth(-1)"><IonIcon :icon="arrowBackOutline" /></button><button class="icon-button" aria-label="Next month" @click="changeMonth(1)"><IonIcon :icon="arrowForwardOutline" /></button></div><button class="today-button" @click="month = new Date(today.getFullYear(), today.getMonth(), 1); selected = todayKey">Today</button></div>
              <div class="calendar-grid" :class="{ compact: !state.settings.showLookNames }"><div v-for="day in weekdays" :key="day" class="weekday-label">{{ day }}</div><button v-for="cell in cells" :key="cell.key" class="day-cell" :class="{ muted: !cell.current, selected: selected === cell.key, 'is-today': cell.key === todayKey, 'has-look': state.looks[cell.key] }" @click="selected = cell.key"><span class="day-number">{{ cell.date.getDate() }}</span><span v-if="state.looks[cell.key] && state.settings.showLookNames" class="look-caption">{{ state.looks[cell.key].title }}</span><span v-if="state.looks[cell.key]" class="mini-palette"><i v-for="id in state.looks[cell.key].items.slice(0, 4)" :key="id" :style="{ backgroundColor: state.items.find((item) => item.id === id)?.colorHex ?? '#ddd' }"></i></span><span v-else-if="cell.current" class="empty-day">+</span></button></div>
              <div class="calendar-legend"><span><i class="legend-dot planned"></i>Planned look</span><span><i class="legend-dot today-dot"></i>Today</span><button @click="modal = 'settings'"><IonIcon :icon="settingsOutline" />Customize calendar</button></div>
            </section>
            <aside class="day-panel"><div class="day-panel-header"><div><p class="eyebrow">{{ selected === todayKey ? 'TODAY, YOUR WAY' : 'YOUR DAY' }}</p><h2>{{ dateLabel }}</h2></div><button class="icon-button" aria-label="Plan outfit" @click="openLook()"><IonIcon :icon="addOutline" /></button></div><div class="daily-intention"><span class="intention-mark"><IonIcon :icon="sparklesOutline" /></span><div><small>TODAY'S INTENTION</small><strong>{{ dailyApproach.title }}</strong><p>{{ dailyApproach.prompt }}</p></div></div>
              <template v-if="selectedLook && outfitItems.length"><div class="outfit-hero"><img :src="heroImage" :alt="selectedLook.title" /><div class="image-shade"></div><span class="hero-tag">LOOK OF THE DAY</span><div class="hero-copy"><p>THE PLAN</p><h3>{{ selectedLook.title }}</h3><span>Ready when you are</span></div><button class="hero-edit" aria-label="Edit outfit" @click="openLook()">···</button></div>
                <div class="palette-block"><div class="section-line"><h3>Color story</h3><span>{{ palette.score }}% together</span></div><div class="palette-swatches"><i v-for="item in outfitItems.slice(0, 5)" :key="item.id" class="palette-chip" :style="{ backgroundColor: item.colorHex }" :title="item.color"></i><strong>{{ palette.label }}</strong></div><div class="harmony-meter"><span :style="{ width: `${palette.score}%` }"></span></div></div>
                <div class="look-items"><div class="section-line"><h3>In this look</h3><button @click="openLook()">Edit outfit</button></div><div v-for="item in outfitItems" :key="item.id" class="look-item"><img :src="item.image" :alt="item.name" /><span><strong>{{ item.name }}</strong><small>{{ item.category }} · {{ item.color }}</small></span><i :style="{ backgroundColor: item.colorHex }"></i></div></div><p v-if="selectedLook.note" class="look-note">“{{ selectedLook.note }}”</p>
              </template><div v-else class="empty-outfit"><div class="empty-icon"><IonIcon :icon="shirtOutline" /></div><h3>A day with possibility.</h3><p>Choose a few pieces and give this day a look of its own.</p><button class="secondary-button" @click="openLook()"><IonIcon :icon="addOutline" />Build an outfit</button></div>
              <div class="weather-strip"><IonIcon :icon="weather?.precipitation > 0 ? waterOutline : sunnyOutline" /><div><strong>{{ weather ? `${weather.description} in ${weather.city}` : 'Weather for your day' }}</strong><small>{{ weather ? `${Math.round(weather.temperature)}°C · ${weather.precipitation > 0 ? `${weather.precipitation} mm precipitation — choose weather-ready pieces` : 'A good day to wear what you love'}` : weatherError || 'Set your city in preferences for local conditions.' }}</small></div><button v-if="weather" class="weather-refresh" aria-label="Refresh weather" @click="refreshWeather">Refresh</button></div>
              <div v-if="selectedLook?.event" class="event-card"><strong>{{ selectedLook.eventTime ? `${selectedLook.eventTime} · ` : '' }}{{ selectedLook.event }}</strong><span>Outfit planned for this event</span></div>
              <button v-if="selectedLook && outfitItems.some((item) => item.status === 'Clean')" class="secondary-button mark-worn-button" @click="markLookWorn"><IonIcon :icon="checkmarkCircle" />Mark outfit as worn</button>
            </aside>
          </div>
          <div class="week-note"><span><IonIcon :icon="sparklesOutline" /></span><div><small>YOUR WEEK, CURATED</small><p>{{ Object.keys(state.looks).length }} looks planned · Let every day have its own approach.</p></div><button @click="page = 'Closet'">Explore the closet →</button></div>
          <section class="weather-suggestions" aria-labelledby="weather-suggestions-title">
            <div class="weather-suggestions-heading">
              <div><p class="eyebrow">DRESS FOR THE DAY</p><h2 id="weather-suggestions-title">{{ weatherSuggestion.title }}</h2><p>{{ weatherSuggestion.detail }}</p></div>
              <button v-if="state.settings.city" class="weather-refresh" :disabled="weatherLoading" @click="refreshWeather">{{ weatherLoading ? 'Updating…' : 'Refresh weather' }}</button>
            </div>
            <div v-if="weatherSuggestion.items.length" class="weather-suggestion-grid">
              <article v-for="item in weatherSuggestion.items" :key="item.id" class="weather-suggestion-item">
                <img :src="item.image" :alt="item.name" loading="lazy" />
                <div><strong>{{ item.name }}</strong><small>{{ item.category }} · {{ item.color }}</small></div>
                <button type="button" :disabled="selectedLook?.items?.includes(item.id)" :aria-label="selectedLook?.items?.includes(item.id) ? `${item.name} already in this look` : `Add ${item.name} to this look`" @click="addWeatherSuggestion(item)">{{ selectedLook?.items?.includes(item.id) ? 'Added' : 'Add' }}</button>
              </article>
            </div>
            <p v-else class="weather-suggestion-empty">Add clean pieces to your closet to see outfit picks here.</p>
            <p v-if="weatherError" class="settings-message" role="status">{{ weatherError }}</p>
          </section>
        </section>

        <section v-else-if="page === 'Closet'" class="page-wrap">
          <div class="page-heading"><div><p class="eyebrow">Everything you love to wear</p><h1>Your closet</h1><p class="heading-note">{{ state.items.length }} pieces, all in one thoughtful place.</p></div><button class="primary-button" @click="modal = 'item'"><IonIcon :icon="addOutline" />Add a piece</button></div>
          <div class="closet-toolbar"><div class="category-filters"><button v-for="category in categories" :key="category" :class="{ active: filter.category === category }" @click="filter.category = category">{{ category }}</button></div><div class="closet-tools"><input v-model="filter.search" class="search-field" placeholder="Find a piece" aria-label="Search closet" /><label class="sort-control"><span>Sort by</span><select v-model="closetSort" class="sort-select" aria-label="Sort closet"><option value="recent">Recently added</option><option value="name">Name</option><option value="category">Category</option><option value="color">Color</option><option value="status">Wear status</option></select></label><label class="rain-filter"><input v-model="weatherRainFilter" type="checkbox" />Rain-ready</label></div></div>
          <div class="closet-grid"><article v-for="item in sortedClosetItems" :key="item.id" class="closet-card"><div class="closet-image"><img :src="item.image" :alt="item.name" /><span class="category-tag">{{ item.category }}</span><button class="remove-item" :aria-label="`Remove ${item.name}`" @click="removeItem(item.id)"><IonIcon :icon="trashOutline" /></button></div><div class="closet-info"><div><h3>{{ item.name }}</h3><p>{{ item.brand || 'No brand' }} · {{ item.season }} · {{ item.status }}</p></div><i :style="{ backgroundColor: item.colorHex }"></i></div></article><p v-if="!sortedClosetItems.length" class="no-results">{{ weatherRainFilter ? 'Tag items as rain-ready to filter them here.' : 'No pieces found.' }}</p></div>
          <section class="closet-outfits" aria-labelledby="closet-outfits-title">
            <div class="closet-outfits-heading"><div><p class="eyebrow">OUTFIT INSPIRATION</p><h2 id="closet-outfits-title">Five looks for every style</h2><p>Front-view outfit photos to browse by occasion.</p></div></div>
            <div class="style-filter-row" role="tablist" aria-label="Outfit inspiration style"><button v-for="style in outfitStyles" :key="style" role="tab" :aria-selected="closetOutfitStyle === style" :class="{ active: closetOutfitStyle === style }" @click="closetOutfitStyle = style">{{ style }}</button></div>
            <div class="closet-outfit-grid"><article v-for="(photo, index) in styleReferencePhotos[closetOutfitStyle]" :key="photo" class="closet-outfit-card"><div class="closet-outfit-photo"><img :src="photo" :alt="`${closetOutfitStyle} outfit ${index + 1}, front view`" loading="lazy" /><span>{{ closetOutfitStyle }} · 0{{ index + 1 }}</span></div></article></div>
          </section>
        </section>

        <section v-else-if="page === 'Style ideas'" class="page-wrap style-page"><div class="page-heading"><div><p class="eyebrow">Front-view style references</p><h1>Choose an outfit style</h1><p class="heading-note">Pick a look, then wear the matching pieces from your closet.</p></div></div><div class="style-filter-row" role="tablist" aria-label="Outfit style"><button v-for="style in outfitStyles" :key="style" role="tab" :aria-selected="styleOccasion === style" :class="{ active: styleOccasion === style }" @click="styleOccasion = style">{{ style }}</button></div><div class="idea-grid"><article v-for="(idea, index) in stylingIdeas" :key="idea.id" class="idea-card"><div class="idea-photo"><img :src="idea.photo" :alt="`${styleOccasion} outfit reference, front view`" /><span>{{ styleOccasion }} · FRONT VIEW</span></div><div class="idea-copy"><small>{{ styleOccasion.toUpperCase() }} · LOOK 0{{ index + 1 }}</small><h2>{{ idea.title }}</h2><p>{{ idea.note }}</p><div class="idea-swatches"><i v-for="id in idea.items" :key="id" :style="{ backgroundColor: state.items.find((item) => item.id === id)?.colorHex }"></i></div><button class="secondary-button" @click="saveStylingIdea(idea)"><IonIcon :icon="checkmarkCircle" />Wear this today</button></div></article><div v-if="!stylingIdeas.length" class="no-results">Add tops and bottoms to your closet to see outfit pairings.</div></div></section>

        <section v-else-if="page === 'Color notes'" class="page-wrap insights-page"><div class="page-heading"><div><p class="eyebrow">Notice the little patterns</p><h1>Color notes</h1><p class="heading-note">A living moodboard made from the outfits you plan.</p></div></div><div class="insight-intro"><IonIcon :icon="colorPaletteOutline" /><div><small>YOUR PALETTE, LATELY</small><h2>Getting dressed in color.</h2><p>Every planned outfit adds a note to your personal color story.</p></div></div><div class="insight-swatches"><article v-for="color in [...new Set(state.items.map((item) => item.color))]" :key="color"><i :style="{ backgroundColor: state.items.find((item) => item.color === color)?.colorHex }"></i><strong>{{ color }}</strong><small>{{ state.items.filter((item) => item.color === color).length }} pieces</small></article></div><div class="approach-strip"><div><small>THE EVERYDAY APPROACH</small><h2>One palette, many moods.</h2></div><p>Try tonal layers, one bright accent, or a crisp contrast. Let each day feel a little different.</p><IonIcon :icon="sparklesOutline" /></div></section>
        <section v-else-if="page === 'Laundry'" class="page-wrap care-page">
          <div class="page-heading"><div><p class="eyebrow">Garment care, at a glance</p><h1>Laundry queue</h1><p class="heading-note">Track each piece through Clean → Worn → Laundry → Clean.</p></div><span class="laundry-count">{{ laundryItems.length }} in laundry</span></div>
          <div class="care-state-summary" aria-label="Clothing state counts">
            <article v-for="statusName in ['Clean', 'Worn', 'Laundry']" :key="statusName" :class="`care-state-${statusName.toLowerCase()}`"><span>{{ statusName }}</span><strong>{{ wardrobeAnalytics.statusCounts[statusName] }}</strong><small>{{ statusName === 'Clean' ? 'Ready to wear' : statusName === 'Worn' ? 'Ready for laundry' : 'In the wash cycle' }}</small></article>
          </div>
          <p class="care-state-flow">Clean <span>→</span> Worn <span>→</span> Laundry <span>→</span> Clean <small>Each button advances one step; laundry returns to clean after its cycle.</small></p>
          <div class="laundry-grid"><article v-for="item in state.items" :key="`${item.id}-${item.status}`" class="laundry-card" :class="`status-${item.status.toLowerCase()}`"><img :src="item.image" :alt="item.name" /><div class="laundry-copy"><small>{{ item.category }} · {{ item.brand || 'Your wardrobe' }}</small><h2>{{ item.name }}</h2><strong>{{ item.status }}</strong><p v-if="item.status === 'Laundry'">{{ laundryMinutesLeft(item) }} min left</p><p v-else-if="item.status === 'Worn'">Ready to add to the wash</p><p v-else>Available to wear</p><button class="secondary-button" @click="setGarmentStatus(item)">{{ item.status === 'Clean' ? 'Mark as worn' : item.status === 'Worn' ? 'Add to laundry' : 'Mark clean' }}</button></div></article><p v-if="!state.items.length" class="no-results">Add pieces to see their care status.</p></div>
        </section>
      </main>

      <Transition name="modal-fade"><div v-if="modal" class="modal-backdrop" @click.self="modal = ''">
        <section v-if="modal === 'look'" class="dialog outfit-dialog" role="dialog" aria-modal="true" aria-labelledby="look-title">
          <header class="dialog-header"><div><p class="eyebrow">{{ dateLabel }}</p><h2 id="look-title">{{ selectedLook ? 'Edit this look' : 'Build a look' }}</h2></div><button class="icon-button" aria-label="Close" @click="modal = ''"><IonIcon :icon="closeOutline" /></button></header>
          <div class="outfit-dialog-scroll">
            <label class="form-label">Give it a name<input v-model="lookForm.title" placeholder="e.g. Soft Sunday layers" maxlength="50" /></label>
            <label class="form-label">A note for later <small>OPTIONAL</small><textarea v-model="lookForm.note" placeholder="The feeling, the plan, the little detail…" rows="2"></textarea></label>
            <div class="form-row"><label class="form-label">Event or appointment <small>OPTIONAL</small><input v-model="lookForm.event" placeholder="e.g. Studio meeting" maxlength="70" /></label><label class="form-label">Time<input v-model="lookForm.eventTime" type="time" /></label></div>
            <section class="outfit-preview" aria-live="polite" aria-label="Live outfit preview">
              <div class="preview-heading">
                <div><small>3D OUTFIT CAROUSELS</small><strong>{{ previewItems.length ? `${previewItems.length} pieces · preview by category` : 'Build your look by category' }}</strong></div>
                <label v-if="weather && (weather.precipitation > 0 || weather.temperature < 12)" class="rain-filter carousel-rain-filter"><input v-model="weatherRainFilter" type="checkbox" />Weather-ready</label>
                <div v-if="hasAuraScore" class="aura-score" role="meter" :aria-valuenow="previewPalette.score" aria-valuemin="0" aria-valuemax="100" :aria-label="`Aura score: ${previewPalette.score}% color harmony`">
                  <small>OUTFIT AURA</small><strong>{{ previewPalette.score }}%</strong><span>{{ previewPalette.label }}</span>
                </div>
                <span v-else class="aura-empty">{{ previewItems.length ? 'Add another category to see Aura %' : 'Choose pieces to see Aura %' }}</span>
              </div>
              <div v-for="group in carouselGroups" :key="group.key" class="outfit-carousel-group">
                <div class="carousel-group-heading"><strong>{{ group.label }}</strong><span>{{ group.items[0].placeholder ? 'No clean options' : `${group.items.length} options · ${group.items.filter((item) => item.selected).length} selected` }}</span></div>
                <div class="preview-stage category-carousel-stage" @pointerdown="beginCarouselDrag($event, group.key)" @pointermove="rotateCarousel" @pointerup="endCarouselDrag" @pointercancel="endCarouselDrag" @lostpointercapture="endCarouselDrag">
                  <div class="outfit-carousel-track" :style="{ transform: `rotateY(${carouselRotations[group.key]}deg)` }" :aria-label="`Drag to rotate the ${group.label} carousel`">
                    <button v-for="item in group.items" :key="item.id" type="button" class="carousel-piece" :class="{ placeholder: item.placeholder, 'carousel-piece-active': activeCarouselItem(group)?.id === item.id, 'carousel-piece-selected': item.selected }" :style="{ '--carousel-angle': `${item.angle}deg` }" :aria-pressed="item.selected" :aria-label="item.placeholder ? `${group.label}: no clean options available` : `${item.name}, ${group.label}, ${item.selected ? 'selected' : 'not selected'}`" :disabled="item.placeholder" @pointerdown.stop @click="toggleCarouselItem(item)">
                      <template v-if="item.placeholder">
                        <span class="carousel-piece-icon"><IonIcon :icon="shirtOutline" /></span>
                        <strong>{{ group.label }}</strong>
                        <small>Add a clean piece to your closet</small>
                      </template>
                      <template v-else>
                        <span class="carousel-category">{{ group.label }}</span>
                        <img :src="item.image" :alt="item.name" draggable="false" />
                        <strong>{{ item.name }}</strong>
                        <small>{{ item.color }} · {{ item.status }}</small>
                        <span class="carousel-selection-state">{{ item.selected ? 'Selected · tap to remove' : 'Tap to add' }}</span>
                      </template>
                    </button>
                  </div>
                  <span class="carousel-floor" aria-hidden="true"></span>
                </div>
                <div class="carousel-controls" role="group" :aria-label="`${group.label} carousel controls`">
                  <button type="button" :disabled="group.items.length < 2 || group.items[0].placeholder" @pointerdown.stop @click="stepCarousel(group, -1)">Previous</button>
                  <span>{{ activeCarouselItem(group)?.placeholder ? 'No clean options' : activeCarouselItem(group)?.name }}</span>
                  <button type="button" class="carousel-select-button" :class="{ selected: activeCarouselItem(group)?.selected }" :disabled="activeCarouselItem(group)?.placeholder" @pointerdown.stop @click="toggleCarouselItem(activeCarouselItem(group))">{{ activeCarouselItem(group)?.selected ? 'Remove' : 'Add to look' }}</button>
                  <button type="button" :disabled="group.items.length < 2 || group.items[0].placeholder" @pointerdown.stop @click="stepCarousel(group, 1)">Next</button>
                </div>
              </div>
              <p v-if="!previewItems.length" class="carousel-hint">Use Previous or Next to preview each clean piece, then add it to your look. Add more clothes in My closet.</p>
              <p v-else class="carousel-hint">Preview each category, then add or remove pieces. Aura estimates color harmony across your selected outfit.</p>
              <div v-if="previewItems.length" class="preview-color-row"><i v-for="item in previewItems" :key="item.id" :style="{ backgroundColor: item.colorHex }" :title="item.color"></i><span>{{ previewPalette.label }}</span></div>
            </section>
          </div>
          <footer class="dialog-footer"><button v-if="selectedLook" class="text-danger" @click="deleteLook"><IonIcon :icon="trashOutline" />Remove look</button><span v-else></span><button class="primary-button" @click="saveLook"><IonIcon :icon="checkmarkCircle" />Save look</button></footer>
        </section>
        <section v-else-if="modal === 'item'" class="dialog item-dialog" role="dialog" aria-modal="true" aria-labelledby="item-title">
          <header class="dialog-header"><div><p class="eyebrow">Make room for something new</p><h2 id="item-title">Add to your closet</h2></div><button class="icon-button" aria-label="Close" @click="modal = ''"><IonIcon :icon="closeOutline" /></button></header>
          <form @submit.prevent="addItem">
            <label class="form-label">Piece name<input v-model="itemForm.name" placeholder="e.g. Cropped denim jacket" required maxlength="60" /></label>
            <div class="form-row"><label class="form-label">Category<select v-model="itemForm.category"><option v-for="category in categories.slice(1)" :key="category">{{ category }}</option></select></label><label class="form-label">Season<select v-model="itemForm.season"><option>All season</option><option>Spring / Summer</option><option>Fall / Winter</option></select></label></div>
            <div class="form-row"><label class="form-label">Brand<input v-model="itemForm.brand" placeholder="Optional" maxlength="50" /></label><label class="form-label">Color name<input v-model="itemForm.color" placeholder="sage" /></label></div>
            <div class="form-row"><label class="form-label">Color swatch<input v-model="itemForm.colorHex" class="color-input" type="color" aria-label="Choose piece color" /></label><label class="form-label">Wash cycle estimate<select v-model.number="itemForm.laundryDurationMinutes"><option :value="30">30 minutes</option><option :value="45">45 minutes</option><option :value="60">60 minutes</option><option :value="90">90 minutes</option></select></label></div>
            <label class="form-label">Tags <small>COMMA-SEPARATED · E.G. RAIN-READY, WARM</small><input v-model="itemForm.tags" placeholder="rain-ready, lightweight" /></label>
            <div class="gallery-picker"><label class="secondary-button" for="item-photo"><IonIcon :icon="imageOutline" />Choose photo</label><input id="item-photo" class="visually-hidden" type="file" accept="image/*" @change="chooseItemPhoto" /><label class="secondary-button" for="item-camera">Take photo</label><input id="item-camera" class="visually-hidden" type="file" accept="image/*" capture="environment" @change="chooseItemPhoto" /><span>{{ itemPhotoName || 'No photo selected' }}</span></div>
            <button v-if="itemForm.image.startsWith('data:image/')" class="secondary-button remove-background-button" type="button" @click="removePhotoBackground">Remove flat background</button>
            <img v-if="itemForm.image.startsWith('data:image/')" class="item-photo-preview" :src="itemForm.image" alt="Selected clothing photo preview" />
            <p v-if="itemPhotoError" class="photo-error" role="status">{{ itemPhotoError }}</p>
            <label class="form-label">Photo URL <small>OPTIONAL</small><input v-model="itemPhotoUrl" type="url" placeholder="https://…" @input="itemPhotoName = ''; itemForm.image = ''" /></label>
            <footer class="dialog-footer"><span></span><button class="primary-button" type="submit"><IonIcon :icon="addOutline" />Add piece</button></footer>
          </form>
        </section>
        <section v-else class="dialog settings-dialog" role="dialog" aria-modal="true" aria-labelledby="settings-title">
          <header class="dialog-header">
            <div><p class="eyebrow">Make it feel like yours</p><h2 id="settings-title">Profile & preferences</h2></div>
            <button class="icon-button" aria-label="Close" @click="modal = ''"><IonIcon :icon="closeOutline" /></button>
          </header>
          <div class="setting-row">
            <div><strong>Appearance</strong><small>Choose the theme that feels comfortable.</small></div>
            <div class="segmented" role="group" aria-label="Appearance">
              <button :class="{ active: state.settings.theme === 'light' }" :aria-pressed="state.settings.theme === 'light'" @click="state.settings.theme = 'light'">Light</button>
              <button :class="{ active: state.settings.theme === 'dark' }" :aria-pressed="state.settings.theme === 'dark'" @click="state.settings.theme = 'dark'">Dark</button>
            </div>
          </div>
          <div class="setting-row">
            <div><strong>Profile name</strong><small>Personalize your wardrobe space.</small></div>
            <input v-model="state.settings.profileName" class="setting-input" placeholder="Your name" maxlength="40" />
          </div>
          <div class="setting-row">
            <div><strong>Clothing style</strong><small>Optional style context; your closet stays inclusive.</small></div>
            <select v-model="state.settings.profileStyle" class="setting-select" aria-label="Clothing style preference">
              <option>All styles</option><option>Women's styles</option><option>Men's styles</option>
            </select>
          </div>
          <div class="setting-row">
            <div><strong>Style preference</strong><small>Used to guide outfit pairings.</small></div>
            <select v-model="state.settings.stylePreference" class="setting-select">
              <option>Everyday</option><option>Casual</option><option>Semi-casual</option><option>Work</option>
            </select>
          </div>
          <div class="setting-row">
            <div><strong>Local weather</strong><small>City used for current conditions and outfit tips.</small></div>
            <input v-model="state.settings.city" class="setting-input" placeholder="e.g. Manila" @change="refreshWeather" />
          </div>
          <p v-if="weatherError" class="settings-message" role="status">{{ weatherLoading ? 'Checking weather…' : weatherError }}</p>
          <section class="settings-analytics" aria-labelledby="analytics-title">
            <div class="settings-analytics-heading"><div><strong id="analytics-title">Wardrobe report & analytics</strong><small>A snapshot of your closet, care states, and planned outfits.</small></div><button class="secondary-button" @click="downloadWardrobeReport">Download CSV report</button></div>
            <div class="analytics-summary">
              <article><span>Total pieces</span><strong>{{ wardrobeAnalytics.totalItems }}</strong></article>
              <article><span>Planned looks</span><strong>{{ wardrobeAnalytics.plannedLooks }}</strong></article>
              <article><span>Ready to wear</span><strong>{{ wardrobeAnalytics.statusCounts.Clean }}</strong></article>
              <article><span>In laundry</span><strong>{{ wardrobeAnalytics.statusCounts.Laundry }}</strong></article>
            </div>
            <div class="analytics-category-list" aria-label="Pieces by category">
              <div v-for="category in categories.slice(1)" :key="category" class="analytics-category">
                <span>{{ category }}</span><div><i :style="{ width: `${wardrobeAnalytics.totalItems ? wardrobeAnalytics.categoryCounts[category] / wardrobeAnalytics.totalItems * 100 : 0}%` }"></i></div><strong>{{ wardrobeAnalytics.categoryCounts[category] }}</strong>
              </div>
            </div>
          </section>
          <div class="setting-row">
            <div><strong>Color accessibility</strong><small>Use labels and contrast cues alongside color.</small></div>
            <select v-model="state.settings.colorBlindMode" class="setting-select" aria-label="Color accessibility mode">
              <option>None</option><option>Deuteranopia</option><option>Protanopia</option><option>Tritanopia</option>
            </select>
          </div>
          <div class="setting-row">
            <div><strong>Aura intensity</strong><small>Adjust the color-responsive ambient glow.</small></div>
            <input v-model.number="state.settings.auraIntensity" type="range" min="0" max="100" aria-label="Aura intensity" />
          </div>
          <div class="setting-row">
            <div><strong>Gentle reminders</strong><small>{{ reminderMessage || 'Allow browser reminders while AuraShift is open.' }}</small></div>
            <button class="secondary-button" @click="enableReminders">{{ notificationsEnabled ? 'Enabled' : 'Enable' }}</button>
          </div>
          <div class="setting-row">
            <div><strong>Week begins on</strong><small>Choose the rhythm of your week.</small></div>
            <div class="segmented">
              <button :class="{ active: state.settings.weekStarts === 0 }" @click="state.settings.weekStarts = 0">Sunday</button>
              <button :class="{ active: state.settings.weekStarts === 1 }" @click="state.settings.weekStarts = 1">Monday</button>
            </div>
          </div>
          <div class="setting-row">
            <div><strong>Look names</strong><small>Show outfit names in calendar days.</small></div>
            <button class="toggle" :class="{ on: state.settings.showLookNames }" role="switch" :aria-checked="state.settings.showLookNames" @click="state.settings.showLookNames = !state.settings.showLookNames"><span></span></button>
          </div>
          <div class="setting-row">
            <div><strong>Calendar accent</strong><small>Choose your little color.</small></div>
            <div class="accent-options">
              <button v-for="(color, name) in { forest: '#59745c', cobalt: '#536f9c', coral: '#bd6858' }" :key="name" :aria-label="name" :title="name" :class="{ active: state.settings.accent === name }" :style="{ '--swatch': color }" @click="state.settings.accent = name"><IonIcon v-if="state.settings.accent === name" :icon="checkmarkCircle" /></button>
            </div>
          </div>
          <footer class="dialog-footer"><span></span><button class="primary-button" @click="modal = ''">Done</button></footer>
        </section>
      </div></Transition>
      <Transition name="modal-fade"><div v-if="tourOpen" class="tour-backdrop" @click.self="finishTour()">
        <section class="tour-dialog" role="dialog" aria-modal="true" aria-labelledby="tour-title">
          <div class="tour-visual"><img :src="tourSteps[tourIndex].image" :alt="tourSteps[tourIndex].imageAlt" /><div class="tour-visual-wash"></div><a class="tour-brand" href="#home"><span class="brand-mark"><img src="/aura-mark.png" alt="" /></span>AuraShift</a><span class="tour-visual-caption">A MORE THOUGHTFUL WAY TO GET DRESSED</span><div class="tour-photo-index">0{{ tourIndex + 1 }} <span>/ 0{{ tourSteps.length }}</span></div></div>
          <div class="tour-content"><button class="tour-close" aria-label="Skip walkthrough" @click="finishTour()"><IonIcon :icon="closeOutline" /></button><div class="tour-copy"><p class="eyebrow">{{ tourSteps[tourIndex].eyebrow }}</p><h2 id="tour-title">{{ tourSteps[tourIndex].title }}</h2><p class="tour-description">{{ tourSteps[tourIndex].description }}</p><div class="tour-progress" aria-label="Walkthrough progress"><button v-for="(_, index) in tourSteps" :key="index" :class="{ current: index === tourIndex, complete: index < tourIndex }" :aria-label="`Go to walkthrough step ${index + 1}`" @click="tourIndex = index"></button></div></div><div class="tour-footer"><button class="tour-skip" @click="finishTour()">{{ tourIndex === tourSteps.length - 1 ? 'Skip for now' : 'Skip tour' }}</button><div class="tour-actions"><button v-if="tourIndex > 0" class="tour-back" @click="tourIndex -= 1">Back</button><button class="primary-button" @click="continueTour">{{ tourIndex === tourSteps.length - 1 ? 'Finish tour' : 'Continue' }}<IonIcon :icon="arrowForwardOutline" /></button></div></div><button class="tour-visit" @click="visitTourFeature()">{{ tourSteps[tourIndex].action }} <IonIcon :icon="arrowForwardOutline" /></button></div>
        </section>
      </div></Transition>
    </div>
  </IonApp>
</template>
