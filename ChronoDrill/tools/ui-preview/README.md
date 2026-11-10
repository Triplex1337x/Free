# ui-preview — скриншоты интерфейса без Roblox Studio

Запускает настоящий Lua-код интерфейса игры (`src/`) на заглушках Roblox API (`roblox.lua`, Lua-машина fengari)
и рисует получившееся дерево GUI в браузере (Playwright + Chromium). Нужен, чтобы быстро посмотреть HUD, окна,
открытие яиц и полоску HP блока после правок.

```bash
cd ChronoDrill/tools/ui-preview
npm install fengari playwright three@0.149.0
ICON_ID=1 node emu.js sc/hud.lua hud.png                 # HUD (ICON_ID=1 — цветные иконки из атласа)
ICON_ID=1 node emu.js sc/hud_touch.lua phone.png 1150 650  # HUD на телефоне
ICON_ID=1 SC_WINDOW=Pets node emu.js sc/window.lua pets.png 1000 620
ICON_ID=1 node emu.js sc/egg.lua egg.png                 # обычное открытие яиц (EGG_N=1..8)
ICON_ID=1 node emu.js sc/mining.lua mining.png           # полоска HP и цифры урона
```

Ограничения: это приближение. 3D-модели во ViewportFrame рисуются кружком-заглушкой, твины сразу прыгают к
конечному значению, шрифт Nunito берётся из Google Fonts (папка `fonts/`, лицензия OFL).

## 3D-превью питомцев

```bash
PETS=HugeCloudCat,HugeStarWhale,Puppy node pet3d.js pets.png grid 4 360 360   # карточки
PETS=Puppy,DemonCat,HugeChronoDragon node pet3d.js lineup.png lineup 1 1300 520 # в ряд, реальный масштаб
PETS=Fox:4 node pet3d.js golden.png                                            # :4 — улучшение (золотой)
```

Модели собирает настоящий `PetBuilder` из игры (CFrame-математика в `roblox.lua`), рисует three.js.
Неон и стекло — приближение: в Roblox свечение сильнее.
