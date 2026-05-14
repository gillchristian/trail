import './styles/app.css'
import { Elm } from './Main.elm'

Elm.Main.init({
  node: document.getElementById('app'),
  flags: { width: window.innerWidth },
})
