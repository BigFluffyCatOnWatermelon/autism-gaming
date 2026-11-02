/**
 * DOM-интерфейс игры. Визуальные панели остаются HTML/CSS,
 * а вся игровая логика и данные принадлежат сцене Phaser.
 */
export class GameUI {
  constructor(game) {
    this.game = game;
    this.scene = null;
    this.root = document.getElementById('game-ui');
    this.root.innerHTML = this.template();

    this.root.addEventListener('click', (event) => this.handleClick(event));
    this.root.addEventListener('change', (event) => this.handleChange(event));
    this.root.addEventListener('keydown', (event) => event.stopPropagation());
    this.root.addEventListener('contextmenu', (event) => event.preventDefault());

    game.events.on('scene-ready', (scene) => {
      this.scene = scene;
      this.renderInventory(scene.getInventoryData());
      this.renderPlayer(scene.getPlayerData());
      this.renderSettings(scene.settings);
      this.appendLog({ time: 'READY', type: 'success', message: 'Интерфейс подключён' });
    });
    game.events.on('player-update', (data) => this.renderPlayer(data));
    game.events.on('inventory-update', (data) => this.renderInventory(data));
    game.events.on('hotbar-selection', (index) => this.markSelectedSlot(index));
    game.events.on('ui-toggle-inventory', () => this.togglePanel('inventory-panel'));
    game.events.on('ui-toggle-settings', () => this.togglePanel('settings-panel'));
    game.events.on('ui-close-overlays', () => this.closePanels());
    game.events.on('debug-toggle', (enabled) => this.setDebugVisible(enabled));
    game.events.on('debug-selection', (data) => this.renderDebugSelection(data));
    game.events.on('debug-hover', (label) => {
      const target = this.root.querySelector('#debug-hover');
      if (target) target.textContent = label ? `Наведение: ${label}` : 'Наведи на объект';
    });
    game.events.on('settings-update', (settings) => this.renderSettings(settings));
    game.events.on('logs-cleared', () => {
      const list = this.root.querySelector('#log-list');
      if (list) list.innerHTML = '';
    });

    window.addEventListener('game-log', (event) => this.appendLog(event.detail));
  }

  template() {
    return `
      <div class="hud-top">
        <div class="hud-brand"><span class="hud-mark">A</span><span>AUTISM GAMING</span></div>
        <div class="vitals">
          <div class="vital-row"><span>HP</span><div class="vital-track"><i id="hp-fill" class="hp-fill"></i></div><b id="hp-text">100 / 100</b></div>
          <div class="vital-row"><span>ST</span><div class="vital-track"><i id="stamina-fill" class="stamina-fill"></i></div><b id="stamina-text">100 / 100</b></div>
        </div>
        <div class="hud-actions">
          <button class="hud-button" data-action="inventory" title="Инвентарь (B)">Инвентарь <kbd>B</kbd></button>
          <button class="hud-button" data-action="settings" title="Настройки">Настройки</button>
          <button class="hud-button debug-button" data-action="debug" title="Отладка (F3)">DEBUG <kbd>F3</kbd></button>
        </div>
      </div>

      <div class="world-hint">WASD — движение · Shift — бег · Ctrl — присесть · Space — перекат · ЛКМ — атака · ПКМ — выпад · B — инвентарь</div>
      <div class="bottom-hud">
        <div class="selected-item" id="selected-item">Меч</div>
        <div class="hotbar" id="hotbar"></div>
        <div class="ammo-count" id="ammo-count">➶ 24</div>
      </div>

      <section class="game-panel inventory-panel is-hidden" id="inventory-panel">
        <header class="panel-header">
          <div><span class="panel-kicker">ПЕРСОНАЖ</span><h2>Инвентарь</h2></div>
          <button class="icon-button" data-action="close" aria-label="Закрыть">×</button>
        </header>
        <div class="inventory-layout">
          <div class="inventory-left">
            <h3>Экипировка</h3>
            <div class="equipment-grid" id="equipment-grid"></div>
            <div class="character-stats" id="character-stats"></div>
          </div>
          <div class="inventory-right">
            <div class="section-title"><h3>Рюкзак</h3><span id="bag-count">12 / 36</span></div>
            <div class="backpack-grid" id="backpack-grid"></div>
            <button class="secondary-button expand-button" data-action="expand-backpack">＋ Расширить рюкзак <small>+6 ячеек · магазин появится позже</small></button>
          </div>
        </div>
      </section>

      <section class="game-panel settings-panel is-hidden" id="settings-panel">
        <header class="panel-header">
          <div><span class="panel-kicker">ПАРАМЕТРЫ</span><h2>Настройки</h2></div>
          <button class="icon-button" data-action="close" aria-label="Закрыть">×</button>
        </header>
        <label class="setting-row"><span><b>Тряска камеры</b><small>Эффект при попадании и ударах</small></span><input type="checkbox" id="setting-shake"></label>
        <label class="setting-row"><span><b>Масштаб интерфейса</b><small>Настройка будет расширена позже</small></span><span class="setting-tag">AUTO</span></label>
        <div class="setting-row"><span><b>Музыка и звук</b><small>Аудиосистема ещё не подключена</small></span><span class="setting-tag">SOON</span></div>
        <p class="panel-note">Настройки камеры сохраняются в этом браузере.</p>
      </section>

      <section class="game-panel debug-panel is-hidden" id="debug-panel">
        <header class="panel-header">
          <div><span class="panel-kicker">DEVELOPER TOOLS · F3</span><h2>Отладчик</h2></div>
          <button class="icon-button" data-action="debug-close" aria-label="Выключить отладчик">×</button>
        </header>
        <div class="debug-status"><span class="debug-pulse"></span><span id="debug-hover">Наведи на объект</span></div>
        <div class="debug-section">
          <h3>Быстрый выбор параметров</h3>
          <div class="debug-presets">
            <button data-debug-target="player">Игрок</button>
            <button data-debug-target="weapon:sword">Меч</button>
            <button data-debug-target="weapon:axe">Топор</button>
            <button data-debug-target="weapon:pickaxe">Кирка</button>
            <button data-debug-target="weapon:bow">Лук</button>
            <button data-debug-target="config:camera">Камера</button>
            <button data-debug-target="config:world">Мир</button>
            <button data-debug-target="config:dodge">Перекат</button>
          </div>
        </div>
        <div class="debug-section">
          <h3>Инспектор объекта</h3>
          <div id="debug-target" class="debug-target">Включи DEBUG и нажми на персонажа или объект мира.</div>
          <div id="debug-fields" class="debug-fields"></div>
        </div>
        <div class="debug-section">
          <div class="section-title"><h3>Журнал событий</h3><button class="text-button" data-action="clear-logs">Очистить</button></div>
          <div id="log-list" class="log-list"></div>
        </div>
      </section>

      <div class="toast" id="toast" aria-live="polite"></div>
    `;
  }

  handleClick(event) {
    const button = event.target.closest('[data-action], [data-slot]');
    if (!button) return;

    if (button.dataset.debugTarget) {
      this.game.events.emit('ui-action', { type: 'debug-target', target: button.dataset.debugTarget });
      return;
    }
    if (button.dataset.slot !== undefined) {
      this.game.events.emit('ui-action', { type: 'select-slot', index: Number(button.dataset.slot) });
      return;
    }

    const action = button.dataset.action;
    if (action === 'inventory') this.togglePanel('inventory-panel');
    else if (action === 'settings') this.togglePanel('settings-panel');
    else if (action === 'debug') this.scene?.toggleDebug();
    else if (action === 'close') this.closePanels();
    else if (action === 'debug-close') this.scene?.toggleDebug();
    else if (action === 'expand-backpack') this.game.events.emit('ui-action', { type: 'expand-backpack' });
    else if (action === 'clear-logs') this.game.events.emit('ui-action', { type: 'clear-logs' });
  }

  handleChange(event) {
    const target = event.target;
    if (target.id === 'setting-shake') {
      this.game.events.emit('ui-action', {
        type: 'setting',
        key: 'cameraShake',
        value: target.checked,
      });
    }

    if (target.dataset.debugKey) {
      this.game.events.emit('ui-action', {
        type: 'debug-property',
        id: target.dataset.entityId,
        key: target.dataset.debugKey,
        value: target.value,
      });
    }
  }

  togglePanel(id) {
    const panel = this.root.querySelector(`#${id}`);
    const shouldOpen = panel.classList.contains('is-hidden');
    this.closePanels();
    if (shouldOpen) panel.classList.remove('is-hidden');
  }

  closePanels() {
    this.root.querySelectorAll('.game-panel').forEach((panel) => panel.classList.add('is-hidden'));
  }

  setDebugVisible(enabled) {
    const panel = this.root.querySelector('#debug-panel');
    const button = this.root.querySelector('.debug-button');
    panel.classList.toggle('is-hidden', !enabled);
    button.classList.toggle('is-active', enabled);
    if (enabled) this.showToast('Режим отладки включён · выбери объект кликом');
  }

  renderPlayer(data) {
    const hp = Math.max(0, Math.min(100, (data.health / data.maxHealth) * 100));
    const stamina = Math.max(0, Math.min(100, (data.stamina / data.maxStamina) * 100));
    this.root.querySelector('#hp-fill').style.width = `${hp}%`;
    this.root.querySelector('#stamina-fill').style.width = `${stamina}%`;
    this.root.querySelector('#hp-text').textContent = `${Math.ceil(data.health)} / ${data.maxHealth}`;
    this.root.querySelector('#stamina-text').textContent = `${Math.ceil(data.stamina)} / ${data.maxStamina}`;
    this.root.querySelector('#selected-item').textContent = data.selectedItem;
    this.root.querySelector('#ammo-count').textContent = `➶ ${data.arrows}`;

    const weaponStats = data.weapon
      ? `<div class="stat-line"><span>Оружие</span><b>${data.weapon.name}</b></div>
         <div class="stat-line"><span>Тип урона</span><b>${data.weapon.damageType}</b></div>`
      : '';
    const stats = this.root.querySelector('#character-stats');
    if (stats) {
      stats.innerHTML = `
        <div class="section-title"><h3>Характеристики</h3><span>Ур. ${data.level}</span></div>
        <div class="stat-line"><span>Здоровье</span><b>${Math.round(data.health)} / ${data.maxHealth}</b></div>
        <div class="stat-line"><span>Выносливость</span><b>${Math.round(data.stamina)} / ${data.maxStamina}</b></div>
        <div class="stat-line"><span>Броня</span><b>${data.armor}</b></div>
        <div class="stat-line"><span>Стрелы</span><b>${data.arrows}</b></div>
        ${weaponStats}
        <div class="stat-line"><span>Скорость</span><b>${data.running ? 'Бег' : data.crouching ? 'Присед' : 'Ходьба'}</b></div>
      `;
    }
  }

  renderInventory(data) {
    const hotbar = this.root.querySelector('#hotbar');
    hotbar.innerHTML = Array.from({ length: 9 }, (_, index) => {
      const item = data.hotbar.find((entry) => entry.slot === index);
      return `<button class="hotbar-slot ${index === data.selectedSlot ? 'is-selected' : ''}" data-slot="${index}" title="${item?.name ?? 'Пустая ячейка'}">
        <span class="slot-number">${index + 1}</span><span class="slot-icon">${item?.icon ?? ''}</span>
      </button>`;
    }).join('');

    this.root.querySelector('#equipment-grid').innerHTML = data.equipment.map((item) =>
      `<div class="equipment-slot"><span class="equipment-icon">${item.icon}</span><span><b>${item.name}</b><small>Пусто</small></span></div>`,
    ).join('');

    this.root.querySelector('#backpack-grid').innerHTML = Array.from({ length: data.backpackSlots }, (_, i) =>
      `<div class="backpack-slot"><span>${i + 1}</span></div>`,
    ).join('');
    this.root.querySelector('#bag-count').textContent = `${data.backpackSlots} / ${data.maxBackpackSlots}`;

    const expand = this.root.querySelector('[data-action="expand-backpack"]');
    expand.disabled = data.backpackSlots >= data.maxBackpackSlots;
  }

  markSelectedSlot(index) {
    this.root.querySelectorAll('.hotbar-slot').forEach((slot, i) => {
      slot.classList.toggle('is-selected', i === index);
    });
  }

  renderSettings(settings) {
    const shake = this.root.querySelector('#setting-shake');
    if (shake) shake.checked = Boolean(settings.cameraShake);
  }

  renderDebugSelection(data) {
    const target = this.root.querySelector('#debug-target');
    const fields = this.root.querySelector('#debug-fields');
    if (!data) {
      target.textContent = 'Включи DEBUG и нажми на персонажа или объект мира.';
      fields.innerHTML = '';
      return;
    }

    target.textContent = `${data.label} · ${data.type} · ID: ${data.id}`;
    fields.innerHTML = Object.entries(data.properties).map(([key, value]) =>
      `<label class="debug-field"><span>${key}</span><input type="number" step="any" data-debug-key="${key}" data-entity-id="${data.id}" value="${Number(value).toFixed(2).replace(/\.00$/, '')}"></label>`,
    ).join('');
  }

  appendLog(entry) {
    const list = this.root.querySelector('#log-list');
    if (!list) return;
    const row = document.createElement('div');
    row.className = `log-entry log-${entry.type || 'info'}`;
    const time = document.createElement('time');
    time.textContent = entry.time || '';
    const message = document.createElement('span');
    message.textContent = entry.message || '';
    row.append(time, message);
    list.prepend(row);
    while (list.children.length > 45) list.lastElementChild.remove();
  }

  showToast(message) {
    const toast = this.root.querySelector('#toast');
    toast.textContent = message;
    toast.classList.add('is-visible');
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => toast.classList.remove('is-visible'), 2300);
  }
}
