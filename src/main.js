import { createApp } from 'vue'
import { IonicVue } from '@ionic/vue'
import '@ionic/vue/css/core.css'
import '@ionic/vue/css/normalize.css'
import '@ionic/vue/css/structure.css'
import '@ionic/vue/css/typography.css'
import './wardrobe.css'
import AuthGate from './AuthGate.vue'

createApp(AuthGate).use(IonicVue).mount('#app')
