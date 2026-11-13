export async function removeFlatBackground(source, tolerance = 38) {
  const image = new Image()
  image.src = source
  await new Promise((resolve, reject) => {
    image.onload = resolve
    image.onerror = () => reject(new Error('That photo could not be opened.'))
  })

  const scale = Math.min(1, 900 / Math.max(image.naturalWidth, image.naturalHeight))
  const canvas = document.createElement('canvas')
  canvas.width = Math.max(1, Math.round(image.naturalWidth * scale))
  canvas.height = Math.max(1, Math.round(image.naturalHeight * scale))
  const context = canvas.getContext('2d', { willReadFrequently: true })
  if (!context) throw new Error('Photo editing is not supported by this browser.')
  context.drawImage(image, 0, 0, canvas.width, canvas.height)

  const imageData = context.getImageData(0, 0, canvas.width, canvas.height)
  const { data, width, height } = imageData
  const corners = [
    0,
    (width - 1) * 4,
    (height - 1) * width * 4,
    (height * width - 1) * 4,
  ]
  const background = [0, 0, 0].map((channel) => corners.reduce((sum, index) => sum + data[index + channel], 0) / corners.length)
  const visited = new Uint8Array(width * height)
  const queue = new Int32Array(width * height)
  let head = 0
  let tail = 0
  const add = (pixel) => {
    if (pixel < 0 || pixel >= width * height || visited[pixel]) return
    const offset = pixel * 4
    const distance = Math.hypot(data[offset] - background[0], data[offset + 1] - background[1], data[offset + 2] - background[2])
    if (distance > tolerance) return
    visited[pixel] = 1
    queue[tail++] = pixel
  }
  for (let x = 0; x < width; x += 1) {
    add(x)
    add((height - 1) * width + x)
  }
  for (let y = 1; y < height - 1; y += 1) {
    add(y * width)
    add(y * width + width - 1)
  }
  while (head < tail) {
    const pixel = queue[head++]
    data[pixel * 4 + 3] = 0
    const x = pixel % width
    if (x > 0) add(pixel - 1)
    if (x + 1 < width) add(pixel + 1)
    add(pixel - width)
    add(pixel + width)
  }
  context.putImageData(imageData, 0, 0)
  return canvas.toDataURL('image/png')
}
