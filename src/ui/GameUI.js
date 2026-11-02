/**
 * DOM-based game HUD and panels.
 *
 * Keeping inventory/settings/debug panels in HTML makes them accessible,
 * responsive and easy to tweak without mixing interface layout into combat.
 */
import { GAME_CONFIG, DEBUG_FIELDS, DEBUG_SCOPES } from '../config/gameConfig.js';

const ITEM_INFO = {
  sword: { name: 'Меч', icon: 0, kind: 'Оружие', description: 'Два режима атаки: широкий режущий замах и быстрый колющий тычок.' },
  pickaxe: { name: 'Кирка', icon: 1, kind: 'Инструмент', description: 'Эффективна против камня. Тип урона: колющий.' },
  axe: { name: 'Топор', icon: 2, kind: 'Инструмент', description: 'Эффективен против деревьев и древесины. Тип урона: режущий.' },
  bow: { name: 'Лук', icon: 3, kind: 'Оружие', description: 'Выпускает стрелу в сторону указателя мыши.' },
  arrows: { name: 'Стрелы', icon: 4, kind: 'Боеприпасы', description: 'Боеприпасы для лука.' },
};

const DAMAGE_NAMES = {
  cutting: 'Режущий',
  piercing: 'Колющий',
  crushing: 'Дробящий',
};

/** A single safe helper for reading nested GAME_CONFIG values. */
function getPath(object, path) {
  return path.split('.').reduce((value, key) => value?.[key], object);
}

function getItemIcon(itemId) {
  const item = ITEM_INFO[itemId];
  if (!item) return '';
  return `<span class="pixel-item-icon" style="--icon-index:${item.icon}" aria-hidden="true"></span>`;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
}

export class GameUI {
  constructor(scene) {
    this.scene = scene;
    this.root = document.getElementById('game-ui');
    this.logs = [];
    this.debugScope = 'player';
    this.debugTarget = 'player';
    this.debugTargetLabel = 'Персонаж';
    this.inventoryOpen = false;
    this.settingsOpen = false;
    this.debugOpen = false;
    this.logsOpen = false;
    this.settings = this.loadSettings();

    this.mount();
    this.bindEvents();
    this.renderHotbar();
    this.renderInventory();
    this.renderSettings();
    this.renderDebug();
    this.updateHud();
    this.addLog('system', 'Мир создан. Добро пожаловать в тестовую сборку.');
  }

  loadSettings() {
    const defaults = { ...GAME_CONFIG.settings };
    try {
      const stored = localStorage.getItem('autism-gaming-settings');
      return stored ? { ...defaults, ...JSON.parse(stored) } : defaults;
    } catch {
      return defaults;
    }
  }

  saveSettings() {
    try {
      localStorage.setItem('autism-gaming-settings', JSON.stringify(this.settings));
    } catch (error) {
      this.addLog('warning', `Настройки не удалось сохранить: ${error.message}`);
    }
    this.scene.applySettings(this.settings);
  }

  mount() {
    this.root.innerHTML = `
      <div class="hud-top">
        <div class="player-hud">
          <div class="hud-row"><span class="hud-label">ЗДОРОВЬЕ</span><strong id="health-text">100 / 100</strong></div>
          <div class="hud-bar health"><span id="health-fill"></span></div>
          <div class="hud-row stamina-row"><span class="hud-label">ВЫНОСЛИВОСТЬ</span><strong id="stamina-text">100 / 100</strong></div>
          <div class="hud-bar stamina"><span id="stamina-fill"></span></div>
        </div>
        <div class="hud-actions">
          <button class="ui-button" data-action="inventory" title="Инвентарь (B)">Рюкзак <kbd>B</kbd></button>
          <button class="ui-button" data-action="settings" title="Настройки">Настройки</button>
          <button class="ui-button debug-toggle" data-action="debug" title="Режим разработчика (F3)">DEBUG <kbd>F3</kbd></button>
          <button class="ui-button" data-action="logs" title="Журнал событий">Логи</button>
        </div>
      </div>

      <div class="world-status" id="world-status">ЛУГ · ДЕНЬ</div>

      <div class="hotbar-wrap">
        <div class="hotbar" id="hotbar" aria-label="Панель быстрого доступа"></div>
        <div class="hotbar-caption">1–9 ВЫБОР СЛОТА · ЛКМ АТАКА · ПКМ ОСОБАЯ АТАКА</div>
      </div>

      <section class="game-panel inventory-panel" id="inventory-panel" hidden>
        <div class="panel-heading">
          <div><span class="panel-eyebrow">ПЕРСОНАЖ</span><h2>Инвентарь</h2></div>
          <button class="panel-close" data-action="close-inventory" aria-label="Закрыть">×</button>
        </div>
        <div class="inventory-layout">
          <div class="inventory-column character-column">
            <div class="character-card">
              <div class="character-preview">✦</div>
              <div class="character-name">Путник <span>Уровень 1</span></div>
              <div class="character-bars">
                <div class="mini-stat"><span>Здоровье</span><b id="inventory-health">100 / 100</b></div>
                <div class="mini-stat"><span>Выносливость</span><b id="inventory-stamina">100 / 100</b></div>
              </div>
            </div>
            <h3>Характеристики</h3>
            <div class="attribute-list" id="attribute-list"></div>
            <h3>Броня</h3>
            <div class="armor-summary" id="armor-summary">Защита: 0</div>
          </div>

          <div class="inventory-column equipment-column">
            <h3>Слоты брони</h3>
            <div class="equipment-grid">
              <button class="equipment-slot" data-armor-slot="head"><span class="equipment-icon">⌑</span><b>Голова</b><small>Пусто</small></button>
              <button class="equipment-slot" data-armor-slot="body"><span class="equipment-icon">♢</span><b>Тело</b><small>Пусто</small></button>
              <button class="equipment-slot" data-armor-slot="legs"><span class="equipment-icon">∥</span><b>Ноги</b><small>Пусто</small></button>
              <button class="equipment-slot" data-armor-slot="feet"><span class="equipment-icon">⌁</span><b>Обувь</b><small>Пусто</small></button>
            </div>
            <div class="equipment-note">Броня появится среди предметов в будущих обновлениях.</div>
            <div class="selected-item-card" id="selected-item-card"></div>
          </div>

          <div class="inventory-column backpack-column">
            <div class="section-title-row"><h3>Рюкзак</h3><span id="bag-capacity">12 / 24</span></div>
            <div class="backpack-grid" id="backpack-grid"></div>
            <div class="locked-slots-note"><span>▣</span> Закрытые ячейки можно будет открывать за игровую валюту в магазине.</div>
          </div>
        </div>
        <div class="panel-footer"><span>Перетащить предметы между слотами — следующий этап.</span><span>Закрыть: <kbd>B</kbd> или <kbd>ESC</kbd></span></div>
      </section>

      <section class="game-panel settings-panel" id="settings-panel" hidden>
        <div class="panel-heading">
          <div><span class="panel-eyebrow">GAME OPTIONS</span><h2>Настройки</h2></div>
          <button class="panel-close" data-action="close-settings" aria-label="Закрыть">×</button>
        </div>
        <div class="settings-list">
          <label class="setting-row"><span><b>Тряска камеры</b><small>Отключить дрожание при ударах и перекатах.</small></span><input type="checkbox" data-setting="screenShake"></label>
          <label class="setting-row"><span><b>Эффекты камеры</b><small>Плавное изменение зума при беге и приседе.</small></span><input type="checkbox" data-setting="cameraEffects"></label>
          <label class="setting-row"><span><b>Показывать FPS</b><small>Счётчик кадров в левом верхнем углу.</small></span><input type="checkbox" data-setting="showFps"></label>
          <label class="setting-row volume-setting"><span><b>Громкость</b><small>Будет использоваться после добавления звука.</small></span><input type="range" min="0" max="1" step="0.05" data-setting-range="masterVolume"><output id="volume-value">70%</output></label>
        </div>
        <div class="panel-footer"><span>Настройки сохраняются в этом браузере.</span><button class="text-button" data-action="reset-settings">Сбросить</button></div>
      </section>

      <section class="game-panel debug-panel" id="debug-panel" hidden>
        <div class="panel-heading">
          <div><span class="panel-eyebrow">DEVELOPER TOOLS · F3</span><h2>Отладчик</h2><small id="debug-target-label">Объект: Персонаж</small></div>
          <button class="panel-close" data-action="close-debug" aria-label="Закрыть">×</button>
        </div>
        <div class="debug-targets">
          <button data-debug-target="player" class="active">Персонаж</button>
          <button data-debug-target="camera">Камера</button>
          <button data-debug-target="world">Мир</button>
          <button data-debug-target="weapons">Оружие</button>
        </div>
        <nav class="debug-tabs" id="debug-tabs"></nav>
        <div class="debug-fields" id="debug-fields"></div>
        <div class="debug-footnote">Изменения применяются сразу. Для добавления нового редактируемого параметра опиши его в src/config/gameConfig.js → DEBUG_FIELDS.</div>
      </section>

      <section class="game-panel logs-panel" id="logs-panel" hidden>
        <div class="panel-heading">
          <div><span class="panel-eyebrow">EVENT STREAM</span><h2>Журнал событий</h2></div>
          <button class="panel-close" data-action="close-logs" aria-label="Закрыть">×</button>
        </div>
        <div class="logs-list" id="logs-list"></div>
        <div class="panel-footer"><span>Последние 60 записей · также выводятся в консоль.</span><button class="text-button" data-action="clear-logs">Очистить</button></div>
      </section>

      <div class="fps-counter" id="fps-counter" hidden>FPS: --</div>
      <div class="debug-crosshair" id="debug-crosshair" hidden></div>
      <div class="game-toast" id="game-toast" hidden></div>
    `;
  }

  bindEvents() {
    this.root.addEventListener('click', event => {
      const action = event.target.closest('[data-action]')?.dataset.action;
      if (action) {
        this.handleAction(action);
        return;
      }

      const hotbarButton = event.target.closest('[data-hotbar-index]');
      if (hotbarButton) {
        this.scene.selectHotbar(Number(hotbarButton.dataset.hotbarIndex));
        return;
      }

      const bagButton = event.target.closest('[data-bag-index]');
      if (bagButton && bagButton.dataset.itemId) {
        this.scene.selectItem(bagButton.dataset.itemId);
        this.renderInventory();
        return;
      }

      const targetButton = event.target.closest('[data-debug-target]');
      if (targetButton) {
        this.setDebugTarget(targetButton.dataset.debugTarget);
        return;
      }

      const scopeButton = event.target.closest('[data-debug-scope]');
      if (scopeButton) {
        this.debugScope = scopeButton.dataset.debugScope;
        this.renderDebug();
      }
    });

    this.root.addEventListener('change', event => {
      const field = event.target.closest('[data-debug-path]');
      if (field) {
        const path = field.dataset.debugPath;
        const value = Number(field.value);
        if (!Number.isFinite(value)) return;
        this.setConfigValue(path, value);
        return;
      }

      const checkbox = event.target.closest('[data-setting]');
      if (checkbox) {
        this.settings[checkbox.dataset.setting] = checkbox.checked;
        this.saveSettings();
        return;
      }

      const range = event.target.closest('[data-setting-range]');
      if (range) {
        this.settings[range.dataset.settingRange] = Number(range.value);
        this.saveSettings();
      }
    });

    this.root.addEventListener('input', event => {
      const range = event.target.closest('[data-setting-range]');
      if (range) {
        this.settings[range.dataset.settingRange] = Number(range.value);
        this.root.querySelector('#volume-value').textContent = `${Math.round(Number(range.value) * 100)}%`;
        this.scene.applySettings(this.settings);
      }
    });
  }

  handleAction(action) {
    switch (action) {
      case 'inventory': this.toggleInventory(); break;
      case 'close-inventory': this.setInventoryOpen(false); break;
      case 'settings': this.toggleSettings(); break;
      case 'close-settings': this.setSettingsOpen(false); break;
      case 'debug': this.toggleDebug(); break;
      case 'close-debug': this.setDebugOpen(false); break;
      case 'logs': this.toggleLogs(); break;
      case 'close-logs': this.setLogsOpen(false); break;
      case 'clear-logs': this.logs = []; this.renderLogs(); this.addLog('system', 'Журнал очищен.'); break;
      case 'reset-settings':
        this.settings = { ...GAME_CONFIG.settings };
        this.saveSettings();
        this.renderSettings();
        this.addLog('system', 'Настройки сброшены.');
        break;
    }
  }

  isOverlayOpen() {
    return this.inventoryOpen || this.settingsOpen || this.debugOpen || this.logsOpen;
  }

  toggleInventory() { this.setInventoryOpen(!this.inventoryOpen); }
  setInventoryOpen(open) {
    this.inventoryOpen = open;
    this.root.querySelector('#inventory-panel').hidden = !open;
    if (open) {
      this.setSettingsOpen(false);
      this.setDebugOpen(false);
      this.setLogsOpen(false);
      this.renderInventory();
      this.addLog('ui', 'Открыт инвентарь.');
    } else {
      this.addLog('ui', 'Инвентарь закрыт.');
    }
  }

  toggleSettings() { this.setSettingsOpen(!this.settingsOpen); }
  setSettingsOpen(open) {
    this.settingsOpen = open;
    this.root.querySelector('#settings-panel').hidden = !open;
    if (open) {
      this.setInventoryOpen(false);
      this.setDebugOpen(false);
      this.setLogsOpen(false);
      this.renderSettings();
      this.addLog('ui', 'Открыты настройки.');
    }
  }

  toggleDebug() { this.setDebugOpen(!this.debugOpen); }
  setDebugOpen(open) {
    this.debugOpen = open;
    this.root.querySelector('#debug-panel').hidden = !open;
    this.root.querySelector('.debug-toggle').classList.toggle('active', open);
    this.root.querySelector('#debug-crosshair').hidden = !open;
    if (open) {
      this.setInventoryOpen(false);
      this.setSettingsOpen(false);
      this.setLogsOpen(false);
      this.renderDebug();
      this.addLog('debug', 'Режим разработчика включён.');
    } else {
      this.addLog('debug', 'Режим разработчика выключен.');
    }
  }

  toggleLogs() { this.setLogsOpen(!this.logsOpen); }
  setLogsOpen(open) {
    this.logsOpen = open;
    this.root.querySelector('#logs-panel').hidden = !open;
    if (open) {
      this.setInventoryOpen(false);
      this.setSettingsOpen(false);
      this.setDebugOpen(false);
      this.renderLogs();
    }
  }

  setDebugTarget(target, label = null) {
    this.debugTarget = target;
    const targetLabels = {
      player: 'Персонаж',
      camera: 'Камера',
      world: 'Мир',
      weapons: 'Оружие',
    };
    this.debugTargetLabel = label || targetLabels[target] || target;
    if (['player', 'camera', 'world', 'weapons'].includes(target)) {
      this.debugScope = target;
    }
    this.renderDebug();
  }

  setConfigValue(path, value) {
    const parts = path.split('.');
    let target = GAME_CONFIG;
    for (const part of parts.slice(0, -1)) target = target[part];
    const key = parts.at(-1);
    const descriptor = DEBUG_FIELDS.find(field => field.path === path);
    const next = Math.max(descriptor?.min ?? -Infinity, Math.min(descriptor?.max ?? Infinity, value));
    target[key] = next;
    this.scene.onConfigChanged(path, next);
    this.addLog('debug', `${path} = ${next}`);
    // Refresh only the inspector fields; other UI remains untouched.
    this.renderDebug();
  }

  renderHotbar() {
    const hotbar = this.root.querySelector('#hotbar');
    const slots = Array.from({ length: GAME_CONFIG.inventory.hotbarSlots }, (_, index) => {
      const itemId = this.scene.hotbar[index];
      const item = ITEM_INFO[itemId];
      const selected = this.scene.selectedHotbarIndex === index;
      return `
        <button class="hotbar-slot ${selected ? 'selected' : ''} ${item ? '' : 'empty'}"
          data-hotbar-index="${index}" title="${item ? escapeHtml(item.name) : 'Пустая ячейка'}">
          <span class="slot-number">${index + 1}</span>
          ${item ? getItemIcon(itemId) : '<span class="empty-slot-mark">·</span>'}
          ${itemId === 'arrows' ? `<span class="slot-count">${this.scene.arrowCount}</span>` : ''}
        </button>`;
    }).join('');
    hotbar.innerHTML = slots;
  }

  renderInventory() {
    const stats = this.scene.stats;
    const playerFields = [
      ['Сила', stats.strength],
      ['Ловкость', stats.agility],
      ['Защита', this.scene.getArmorDefense()],
      ['Скорость', Math.round(GAME_CONFIG.player.walkSpeed)],
    ];
    this.root.querySelector('#attribute-list').innerHTML = playerFields
      .map(([label, value]) => `<div><span>${label}</span><b>${value}</b></div>`).join('');

    this.root.querySelector('#armor-summary').textContent = `Защита: ${this.scene.getArmorDefense()} · Слотов занято: ${this.scene.equippedArmorCount}`;
    this.root.querySelector('#bag-capacity').textContent =
      `${Math.min(this.scene.backpack.filter(Boolean).length, GAME_CONFIG.inventory.baseBackpackSlots)} / ${GAME_CONFIG.inventory.maxBackpackSlots}`;

    const activeSlots = GAME_CONFIG.inventory.baseBackpackSlots;
    const maxSlots = GAME_CONFIG.inventory.maxBackpackSlots;
    const grid = this.root.querySelector('#backpack-grid');
    const slots = [];
    for (let index = 0; index < maxSlots; index++) {
      const isUnlocked = index < activeSlots;
      const itemId = isUnlocked ? this.scene.backpack[index] : null;
      const item = ITEM_INFO[itemId];
      slots.push(`
        <button class="backpack-slot ${isUnlocked ? '' : 'locked'} ${item ? 'filled' : ''}"
          ${isUnlocked ? `data-bag-index="${index}" data-item-id="${itemId || ''}"` : 'disabled'}
          title="${item ? escapeHtml(item.name) : isUnlocked ? 'Пустая ячейка' : 'Откроется в магазине'}">
          ${item ? getItemIcon(itemId) : isUnlocked ? '<span class="empty-slot-mark">+</span>' : '<span class="lock-mark">▣</span>'}
          ${itemId === 'arrows' ? `<small>${this.scene.arrowCount}</small>` : ''}
        </button>`);
    }
    grid.innerHTML = slots.join('');

    const selectedId = this.scene.hotbar[this.scene.selectedHotbarIndex];
    const info = ITEM_INFO[selectedId];
    const weapon = GAME_CONFIG.weapons[selectedId];
    const card = this.root.querySelector('#selected-item-card');
    if (!info) {
      card.innerHTML = '<span class="panel-eyebrow">ВЫБРАННЫЙ ПРЕДМЕТ</span><p>Выбери предмет в рюкзаке или на панели быстрого доступа.</p>';
    } else {
      const statsHtml = weapon ? [
        ['Базовый урон', weapon.damage],
        ['Тип урона', DAMAGE_NAMES[weapon.damageType] || '—'],
        ['Перезарядка', `${weapon.cooldownMs ?? 'особая'} мс`],
        ['Дальность', weapon.reach ?? weapon.projectileSpeed ?? '—'],
      ].map(([label, value]) => `<div><span>${label}</span><b>${value}</b></div>`).join('') : '';
      const details = selectedId === 'sword'
        ? `<div><span>Размашистый удар</span><b>${weapon.slash.damage} · режущий</b></div><div><span>Тычок</span><b>${weapon.thrust.damage} · колющий</b></div>`
        : selectedId === 'axe'
          ? `<div><span>Бонус по дереву</span><b>×${weapon.woodMultiplier}</b></div>`
          : selectedId === 'pickaxe'
            ? `<div><span>Бонус по камню</span><b>×${weapon.stoneMultiplier}</b></div>`
            : selectedId === 'bow'
              ? `<div><span>Боеприпасы</span><b>${this.scene.arrowCount} стрел</b></div>`
              : '';
      card.innerHTML = `
        <span class="panel-eyebrow">ВЫБРАННЫЙ ПРЕДМЕТ</span>
        <div class="selected-item-title">${getItemIcon(selectedId)}<div><b>${escapeHtml(info.name)}</b><small>${escapeHtml(info.kind)}</small></div></div>
        <p>${escapeHtml(info.description)}</p>
        <div class="selected-item-stats">${statsHtml}${details}</div>`;
    }
    this.updateHud();
  }

  renderSettings() {
    const panel = this.root.querySelector('#settings-panel');
    for (const input of panel.querySelectorAll('[data-setting]')) {
      input.checked = Boolean(this.settings[input.dataset.setting]);
    }
    const range = panel.querySelector('[data-setting-range]');
    range.value = this.settings.masterVolume;
    panel.querySelector('#volume-value').textContent = `${Math.round(this.settings.masterVolume * 100)}%`;
  }

  renderDebug() {
    const targetLabel = this.root.querySelector('#debug-target-label');
    targetLabel.textContent = `Объект: ${this.debugTargetLabel}`;

    const targetButtons = this.root.querySelectorAll('[data-debug-target]');
    targetButtons.forEach(button => button.classList.toggle('active', button.dataset.debugTarget === this.debugTarget));

    const tabs = this.root.querySelector('#debug-tabs');
    tabs.innerHTML = DEBUG_SCOPES.map(scope => `
      <button data-debug-scope="${scope.id}" class="${scope.id === this.debugScope ? 'active' : ''}">${escapeHtml(scope.label)}</button>
    `).join('');

    const fields = DEBUG_FIELDS.filter(field => field.scope === this.debugScope);
    const host = this.root.querySelector('#debug-fields');
    if (!fields.length) {
      host.innerHTML = '<p class="debug-empty">Для этой категории пока нет параметров.</p>';
      return;
    }
    host.innerHTML = fields.map(field => {
      const value = getPath(GAME_CONFIG, field.path);
      return `
        <label class="debug-field">
          <span class="debug-field-info"><b>${escapeHtml(field.label)}</b><small>${escapeHtml(field.description)}</small></span>
          <input type="number" data-debug-path="${field.path}" min="${field.min}" max="${field.max}" step="${field.step}" value="${value}">
        </label>`;
    }).join('');
  }

  updateHud() {
    if (!this.root) return;
    const stats = this.scene.stats;
    const health = Math.max(0, Math.min(100, (stats.health / GAME_CONFIG.player.maxHealth) * 100));
    const stamina = Math.max(0, Math.min(100, (stats.stamina / GAME_CONFIG.player.maxStamina) * 100));
    this.root.querySelector('#health-fill').style.width = `${health}%`;
    this.root.querySelector('#stamina-fill').style.width = `${stamina}%`;
    this.root.querySelector('#health-text').textContent = `${Math.ceil(stats.health)} / ${GAME_CONFIG.player.maxHealth}`;
    this.root.querySelector('#stamina-text').textContent = `${Math.ceil(stats.stamina)} / ${GAME_CONFIG.player.maxStamina}`;
    this.root.querySelector('#inventory-health').textContent = `${Math.ceil(stats.health)} / ${GAME_CONFIG.player.maxHealth}`;
    this.root.querySelector('#inventory-stamina').textContent = `${Math.ceil(stats.stamina)} / ${GAME_CONFIG.player.maxStamina}`;
    this.root.querySelector('#fps-counter').hidden = !this.settings.showFps;
  }

  updateFps(value) {
    if (this.settings.showFps) {
      this.root.querySelector('#fps-counter').textContent = `FPS: ${Math.round(value)}`;
    }
  }

  updateHotbarSelection() {
    this.renderHotbar();
  }

  addLog(type, message) {
    const time = new Date().toLocaleTimeString('ru-RU', { hour12: false });
    const entry = { type, message, time };
    this.logs.unshift(entry);
    this.logs.length = Math.min(this.logs.length, 60);
    // The same event stream is available in DevTools for more detailed debugging.
    console.log(`[game:${type}] ${time} ${message}`);
    if (this.logsOpen) this.renderLogs();
  }

  renderLogs() {
    const list = this.root.querySelector('#logs-list');
    list.innerHTML = this.logs.map(entry => `
      <div class="log-entry ${escapeHtml(entry.type)}">
        <time>${escapeHtml(entry.time)}</time><b>${escapeHtml(entry.type.toUpperCase())}</b><span>${escapeHtml(entry.message)}</span>
      </div>`).join('') || '<p class="debug-empty">Событий пока нет.</p>';
  }

  showToast(message, type = 'info') {
    const toast = this.root.querySelector('#game-toast');
    toast.textContent = message;
    toast.dataset.type = type;
    toast.hidden = false;
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => { toast.hidden = true; }, 1800);
  }
}
