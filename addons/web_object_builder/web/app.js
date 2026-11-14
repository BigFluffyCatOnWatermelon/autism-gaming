"use strict";

/* Object Workshop UI. All persistent data and validation live in the Web Object Builder backend and shared Object System. */
const $ = id => document.getElementById(id);
const host = window.ObjectBuilderHost;
const ROOT_TYPES = ["Node2D","StaticBody2D","Area2D","CharacterBody2D","RigidBody2D","AnimatableBody2D"];
const NODE_TYPES = ["Node2D","Sprite2D","AnimatedSprite2D","Polygon2D","Line2D","Marker2D","Area2D","StaticBody2D","CollisionShape2D","CollisionPolygon2D","AudioStreamPlayer2D","AnimationPlayer"];
let CATALOG = [];
let COMPONENTS = [];
let creationProfiles = [];
let physicsLayers = [];
let templates = [];
let projectObjects = [];
let openDocuments = [];
let categories = [];
let subcategories = {};
let favoriteIds = [];
let recentIds = [];
let collections = {};
let state = null;
let activeView = "workspace";
let inspectorTab = "Объект";
let leftEditorTab = "Части";
let spriteEditorAnimationIndex = -1;
let spriteEditorImage = null;
let selectedPartId = "root";
let selectedCapabilityId = "";
let capSearch = "";
let templateSearch = "";
let templateCategory = "Все";
let templateType = "Все";
let templateSubcategory = "Все";
let projectSearch = "";
let capFilter = "Все";
let projectCategory = "Все";
let projectType = "Все";
let projectSubcategory = "Все";
let projectSort = "name";
let projectRelation = "Все";
let projectMechanic = "Все";
let projectCollection = "Все";
let projectMode = "Все";
let selectedProfileId = "other";
let pendingFormCallback = null;
let undoStack = [];
let redoStack = [];
let syncTimer = 0;
let isApplyingSnapshot = false;
let statusMessage = "";
let statusError = false;

function clone(value) {
  return value == null ? value : JSON.parse(JSON.stringify(value));
}
function esc(value) {
  return String(value ?? "").replace(/[&<>"']/g, ch => ({
    "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"
  })[ch]);
}
function textArray(value) {
  return Array.isArray(value) ? value.map(x => String(x)).filter(Boolean) : [];
}
function setStatus(message, isError = false) {
  statusMessage = String(message || "");
  statusError = !!isError;
  const el = $("saveState");
  if (el) {
    el.textContent = statusMessage || (state ? (state.saved ? "Сохранено" : "Есть изменения") : "Нет объекта");
    el.style.color = statusError ? "var(--red)" : "";
  }
}
function toast(message, isError = false) {
  const el = $("toast");
  if (!el) return;
  el.textContent = String(message || "");
  el.classList.toggle("error", !!isError);
  el.classList.add("show");
  window.clearTimeout(window._obToastTimer);
  window._obToastTimer = window.setTimeout(() => el.classList.remove("show"), 2600);
  if (isError) setStatus(message, true);
}
async function api(kind, payload = {}) {
  if (!host || !host.isEmbedded) throw new Error("Открой Web Object Builder внутри Godot.");
  const result = await host.request(kind, payload);
  if (!result) throw new Error("Операция не выполнена: backend не вернул ответ.");
  // Failed bundle saves can still include a fresh workspace snapshot when some
  // related definitions were committed before the main object failed. Apply that
  // snapshot before surfacing the error so the library never hides partial saves.
  if (result.workspace) applyWorkspace(result.workspace);
  if (result.working !== undefined) applyWorking(result.working);
  if (result.ok === false) throw new Error(result.error || "Операция не выполнена.");
  return result;
}
function sendSync() {
  if (!state || !host?.isEmbedded || isApplyingSnapshot) return false;
  state.saved = false;
  setStatus("Черновик изменён");
  return host.send("workspace_sync", { working: state });
}
function scheduleSync() {
  if (!state || isApplyingSnapshot) return;
  window.clearTimeout(syncTimer);
  syncTimer = window.setTimeout(sendSync, 120);
}
async function syncNow() {
  window.clearTimeout(syncTimer);
  if (!state) return null;
  return api("workspace_sync", { working: state });
}
function normalizeRecord(record) {
  if (!record || typeof record !== "object") return null;
  const item = clone(record);
  item.objectId = String(item.objectId || "");
  item.name = String(item.name || "Без названия");
  item.type = String(item.type || "Другой объект");
  item.emoji = String(item.emoji || "◆");
  item.description = String(item.description || "");
  item.category = String(item.category || "Other");
  item.subcategory = String(item.subcategory || "");
  item.nativeRootType = String(item.nativeRootType || "Node2D");
  item.nativeObjectType = String(item.nativeObjectType || "other");
  item.tags = textArray(item.tags);
  item.previewDataUrl = String(item.previewDataUrl || "");
  item.previewHash = String(item.previewHash || "");
  const sprite = item.sprite && typeof item.sprite === "object" ? item.sprite : {};
  const spriteScale = sprite.scale && typeof sprite.scale === "object" ? sprite.scale : {};
  const spriteOffset = sprite.offset && typeof sprite.offset === "object" ? sprite.offset : {};
  const textureSize = sprite.textureSize && typeof sprite.textureSize === "object" ? sprite.textureSize : {};
  const objectSize = item.objectSize && typeof item.objectSize === "object" ? item.objectSize : {};
  const collision = item.collision && typeof item.collision === "object" ? item.collision : {};
  const numberOr = (value,fallback,min,max) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.max(min,Math.min(max,parsed)) : fallback;
  };
  const collisionSize = collision.size && typeof collision.size === "object" ? collision.size : {};
  const collisionOffset = collision.offset && typeof collision.offset === "object" ? collision.offset : {};
  item.objectSize = {
    x:numberOr(objectSize.x,32,1,8192),
    y:numberOr(objectSize.y,32,1,8192)
  };
  item.sprite = {
    scale:{x:numberOr(spriteScale.x,1,0.05,16),y:numberOr(spriteScale.y,1,0.05,16)},
    offset:{x:numberOr(spriteOffset.x,0,-8192,8192),y:numberOr(spriteOffset.y,0,-8192,8192)},
    rotation:numberOr(sprite.rotation,0,-36000,36000),
    textureSize:{x:numberOr(textureSize.x,0,0,8192),y:numberOr(textureSize.y,0,0,8192)},
    zIndex:numberOr(sprite.zIndex,0,-4096,4096)
  };
  item.spriteSheetDataUrl = String(item.spriteSheetDataUrl || "");
  item.spriteSheetHash = String(item.spriteSheetHash || "");
  item.spriteLayers = Array.isArray(item.spriteLayers) ? item.spriteLayers.map((layer,index) => {
    const position = layer.position && typeof layer.position === "object" ? layer.position : {};
    const scale = layer.scale && typeof layer.scale === "object" ? layer.scale : {};
    return {
      id:String(layer.id || "sprite_" + index),
      name:String(layer.name || "Спрайт " + (index + 1)),
      textureHash:String(layer.textureHash || ""),
      textureDataUrl:String(layer.textureDataUrl || ""),
      textureSize:{
        x:numberOr(layer.textureSize?.x,0,0,8192),
        y:numberOr(layer.textureSize?.y,0,0,8192)
      },
      position:{x:numberOr(position.x,0,-8192,8192),y:numberOr(position.y,0,-8192,8192)},
      scale:{x:numberOr(scale.x,1,0.05,16),y:numberOr(scale.y,1,0.05,16)},
      rotation:numberOr(layer.rotation,0,-36000,36000),
      zIndex:numberOr(layer.zIndex,0,-4096,4096),
      visible:layer.visible !== false,
      runtimeVisible:layer.runtimeVisible !== false,
      embeddedRelationId:String(layer.embeddedRelationId || ""),
      embeddedObjectId:String(layer.embeddedObjectId || ""),
      embeddedSourceName:String(layer.embeddedSourceName || "")
    };
  }) : [];
  item.spriteAnimations = Array.isArray(item.spriteAnimations) ? item.spriteAnimations.map((animation,index) => ({
    name:String(animation.name || "animation_" + (index + 1)),
    rows:Math.max(1,Math.min(256,Number(animation.rows) || 1)),
    columns:Math.max(1,Math.min(256,Number(animation.columns) || 1)),
    row:Math.max(0,Number(animation.row) || 0),
    start_column:Math.max(0,Number(animation.start_column) || 0),
    frame_count:Math.max(1,Number(animation.frame_count) || Number(animation.columns) || 1),
    margin_x:Math.max(0,Math.min(8192,Number(animation.margin_x) || 0)),
    margin_y:Math.max(0,Math.min(8192,Number(animation.margin_y) || 0)),
    separation_x:Math.max(0,Math.min(8192,Number(animation.separation_x) || 0)),
    separation_y:Math.max(0,Math.min(8192,Number(animation.separation_y) || 0)),
    fps:Math.max(0.1,Math.min(60,Number(animation.fps) || 8)),
    loop:animation.loop !== false
  })) : [];
  item.collision = {
    enabled:!!collision.enabled,
    mode:collision.mode === "area" ? "area" : "solid",
    shape:["rectangle","circle","capsule"].includes(collision.shape) ? collision.shape : "rectangle",
    size:{x:numberOr(collisionSize.x,32,1,8192),y:numberOr(collisionSize.y,32,1,8192)},
    radius:numberOr(collision.radius,16,1,4096),
    height:numberOr(collision.height,32,2,8192),
    offset:{x:numberOr(collisionOffset.x,0,-8192,8192),y:numberOr(collisionOffset.y,0,-8192,8192)},
    layer:numberOr(collision.layer,2,0,4294967295),
    mask:numberOr(collision.mask,1,0,4294967295)
  };
  item.parts = Array.isArray(item.parts) ? item.parts.map(x => clone(x)) : [];
  if (!item.parts.some(x => x.id === "root")) {
    item.parts.unshift({ id:"root", name:item.name, kind:"root", nodeType:item.nativeRootType, parentId:"" });
  }
  item.caps = textArray(item.caps);
  item.autoCaps = textArray(item.autoCaps);
  item.mechanicSettings = item.mechanicSettings && typeof item.mechanicSettings === "object" ? item.mechanicSettings : {};
  item.relations = Array.isArray(item.relations) ? item.relations.map(r => ({
    ...r,
    relation_id: String(r.relation_id || r.id || ""),
    target_object_id: String(r.target_object_id || r.targetId || ""),
    mechanic_id: String(r.mechanic_id || r.mechanicId || ""),
    kind: String(r.kind || "related"),
    label: String(r.label || ""),
    quantity: Math.max(1, Number(r.quantity) || 1),
    settings: r.settings && typeof r.settings === "object" ? r.settings : {}
  })) : [];
  item.properties = Array.isArray(item.properties) ? item.properties : [];
  item.components = Array.isArray(item.components) ? item.components : [];
  item.scenePath = String(item.scenePath || "");
  item.isTemplate = !!item.isTemplate;
  item.saved = item.saved !== false;
  return item;
}
function applyWorking(record) {
  state = record ? normalizeRecord(record) : null;
  selectedPartId = state?.parts?.some(x => x.id === selectedPartId) ? selectedPartId : "root";
  if (!state) inspectorTab = "Объект";
  if (state) {
    selectedCapabilityId = state.caps[0] || "";
    if (!undoStack.length) undoStack = [clone(state)];
  } else {
    undoStack = [];
    redoStack = [];
  }
  renderAll();
}
function applyWorkspace(workspace) {
  if (!workspace || typeof workspace !== "object") return;
  isApplyingSnapshot = true;
  projectObjects = (workspace.objects || []).map(normalizeRecord).filter(Boolean);
  openDocuments = (workspace.open_documents || []).map(normalizeRecord).filter(Boolean);
  templates = (workspace.templates || []).map(normalizeRecord).filter(Boolean);
  CATALOG = Array.isArray(workspace.capabilities) ? workspace.capabilities : [];
  COMPONENTS = Array.isArray(workspace.components) ? workspace.components : [];
  creationProfiles = Array.isArray(workspace.creation_profiles) ? workspace.creation_profiles : [];
  physicsLayers = textArray(workspace.physics_layers);
  categories = textArray(workspace.categories);
  subcategories = workspace.subcategories && typeof workspace.subcategories === "object" ? workspace.subcategories : {};
  favoriteIds = textArray(workspace.favorites);
  recentIds = textArray(workspace.recent_ids);
  collections = workspace.collections && typeof workspace.collections === "object" ? workspace.collections : {};
  if (workspace.working !== undefined && workspace.working !== null) {
    state = normalizeRecord(workspace.working);
  } else if (!state || !openDocuments.some(item => item.objectId === state.objectId)) {
    state = null;
  }
  isApplyingSnapshot = false;
  renderAll();
}
function mergeExternalSceneProfiles(target, externalDefinition) {
  if (!target || !externalDefinition) return;
  if (externalDefinition.collision && typeof externalDefinition.collision === "object") {
    target.collision = clone(externalDefinition.collision);
  }
  if (externalDefinition.sprite && typeof externalDefinition.sprite === "object") {
    target.sprite = clone(externalDefinition.sprite);
  }
  if (Object.prototype.hasOwnProperty.call(externalDefinition, "previewDataUrl")) {
    target.previewDataUrl = String(externalDefinition.previewDataUrl || "");
  }
  if (Object.prototype.hasOwnProperty.call(externalDefinition, "previewHash")) {
    target.previewHash = String(externalDefinition.previewHash || "");
  }
  if (Array.isArray(externalDefinition.spriteLayers)) {
    target.spriteLayers = clone(externalDefinition.spriteLayers);
  }

  // Godot-owned scene nodes and their Inspector properties are serialized as
  // external parts. Replacing only collision/sprite profiles left the tree and
  // the properties inspector permanently stale in an already-open document.
  if (Array.isArray(externalDefinition.parts)) {
    const currentParts = Array.isArray(target.parts) ? target.parts : [];
    const incomingParts = externalDefinition.parts;
    const currentRoot = currentParts.find(part => part?.id === "root") || null;
    const incomingRoot = incomingParts.find(part => part?.id === "root") || null;
    const currentBuilderParts = currentParts.filter(
      part => part && part.id !== "root" && part.external !== true
    );
    const incomingBuilderParts = incomingParts.filter(
      part => part && part.id !== "root" && part.external !== true
    );
    const incomingBuilderById = new Map(incomingBuilderParts.map(part => [String(part.id), part]));
    const mergedBuilderParts = currentBuilderParts.map(part => {
      const fresh = incomingBuilderById.get(String(part.id));
      if (!fresh) return clone(part);
      incomingBuilderById.delete(String(part.id));
      return { ...clone(part), ...clone(fresh) };
    });
    for (const fresh of incomingBuilderById.values()) {
      mergedBuilderParts.push(clone(fresh));
    }
    const freshExternalParts = incomingParts.filter(
      part => part && part.id !== "root" && part.external === true
    );

    let rootPart = currentRoot ? clone(currentRoot) : (incomingRoot ? clone(incomingRoot) : null);
    if (rootPart && incomingRoot) {
      rootPart.nodeType = incomingRoot.nodeType || rootPart.nodeType;
      rootPart.properties = incomingRoot.properties && typeof incomingRoot.properties === "object"
        ? clone(incomingRoot.properties)
        : {};
    }
    target.parts = [
      ...(rootPart ? [rootPart] : []),
      ...mergedBuilderParts,
      ...freshExternalParts.map(part => clone(part))
    ];

    if (
      typeof selectedPartId !== "undefined" &&
      !target.parts.some(part => part.id === selectedPartId)
    ) {
      selectedPartId = "root";
    }
  }
}
function applyExternalWorkspace(workspace, externalDefinition = null) {
  const activeObjectId = String(state?.objectId || "");
  const protectedDrafts = new Map();
  for (const document of openDocuments) {
    if (document && document.saved === false && document.objectId) {
      protectedDrafts.set(document.objectId, clone(document));
    }
  }
  if (state && state.saved === false && state.objectId) {
    protectedDrafts.set(state.objectId, clone(state));
  }

  applyWorkspace(workspace);

  for (const [objectId, draft] of protectedDrafts) {
    const documentIndex = openDocuments.findIndex(item => item.objectId === objectId);
    if (documentIndex >= 0) openDocuments[documentIndex] = draft;
    else openDocuments.push(draft);
    if (activeObjectId === objectId) state = draft;
  }

  // Godot sends every scene reconciled from disk on workspace activation,
  // not only the currently selected object. Apply each scene-owned profile
  // after restoring local Web Builder drafts.
  const externalDefinitions = Array.isArray(externalDefinition)
    ? externalDefinition
    : (externalDefinition && typeof externalDefinition === "object" ? [externalDefinition] : []);
  for (const freshDefinition of externalDefinitions) {
    const externalId = String(freshDefinition?.objectId || "");
    if (!externalId) continue;
    for (const document of openDocuments) {
      if (document?.objectId === externalId) {
        mergeExternalSceneProfiles(document, freshDefinition);
      }
    }
    if (state?.objectId === externalId) {
      mergeExternalSceneProfiles(state, freshDefinition);
    }
  }

  if (protectedDrafts.size || externalDefinitions.length) renderAll();
  return new Set(protectedDrafts.keys());
}

host?.on("workspace_snapshot", payload => {
  if (!payload.workspace) return;
  applyExternalWorkspace(
    payload.workspace,
    payload.external_definitions || payload.external_definition || null
  );
  setStatus(state?.saved === false ? "Есть несохранённые изменения" : "Данные обновлены из Godot");
});

host?.on("library_filesystem_updated", payload => {
  if (payload.workspace) applyExternalWorkspace(payload.workspace);
  const importedNames = textArray(payload.imported_names);
  if (importedNames.length) {
    toast("Из файловой системы добавлены объекты: " + importedNames.join(", "));
  }
});

host?.on("external_scene_updated", payload => {
  const externalObjectId = String(payload.external_definition?.objectId || "");
  const protectedDraftIds = payload.workspace
    ? applyExternalWorkspace(
        payload.workspace,
        payload.external_definitions || payload.external_definition || null
      )
    : new Set();
  const localConflict = protectedDraftIds.has(externalObjectId);

  if (payload.conflict || localConflict) {
    toast(
      "Спрайты и коллизия обновлены из Godot. Остальные несохранённые изменения Web Builder сохранены.",
      true
    );
    return;
  }
  toast("Сохранённая в Godot сцена синхронизирована с Web Object Builder.");
});
host?.on("external_definition_updated", payload => {
  const externalObjectId = String(payload.external_definition?.objectId || "");
  const protectedDraftIds = payload.workspace
    ? applyExternalWorkspace(payload.workspace, payload.external_definition)
    : new Set();
  const localConflict = protectedDraftIds.has(externalObjectId);

  if (payload.conflict || localConflict) {
    toast(
      "ObjectDefinition сохранён в Godot, но в Web Builder есть несохранённые изменения. Черновик оставлен без перезаписи.",
      true
    );
    return;
  }
  toast("Изменения ObjectDefinition из Godot обновлены в Web Object Builder.");
});

host?.on("editor_scene_reload_skipped", payload => {
  const scenePath = String(payload.scene_path || "");
  toast(
    "Объект сохранён и обновлён, но сцена «" + (scenePath.split("/").pop() || scenePath) +
    "» имеет несохранённые правки Godot. Она оставлена открытой без перезагрузки.",
    true
  );
});

function captureUndo() {
  if (!state) return;
  const snapshot = clone(state);
  const previous = undoStack[undoStack.length - 1];
  if (previous && JSON.stringify(previous) === JSON.stringify(snapshot)) return;
  undoStack.push(snapshot);
  if (undoStack.length > 100) undoStack.shift();
  redoStack = [];
  updateUndoButtons();
}
function updateUndoButtons() {
  const undo = $("undo"), redo = $("redo");
  if (undo) undo.disabled = undoStack.length < 2;
  if (redo) redo.disabled = redoStack.length === 0;
}
function hydrateWorking(record) {
  state = normalizeRecord(record);
  if (!state) return;
  if (!undoStack.length) undoStack = [clone(state)];
  renderAll();
}
async function openObject(objectId) {
  try {
    if (state && state.objectId !== objectId) await syncNow();
    const result = await api("object_open", { object_id: objectId });
    hydrateWorking(result.working);
    activeView = "workspace";
    setView("workspace");
    setStatus("Открыт объект: " + state.name);
  } catch (error) { toast(error.message, true); }
}
async function closeObjectTab(objectId) {
  const index = openDocuments.findIndex(item => item.objectId === objectId);
  if (index < 0) return;
  const document = openDocuments[index];
  const existsInLibrary = projectObjects.some(item => item.objectId === objectId);
  const referencedBy = allRelationObjects().filter(source =>
    source.objectId !== objectId && (source.relations || []).some(relation => relation.target_object_id === objectId)
  );
  if (!existsInLibrary && referencedBy.length) {
    return toast(
      "Нельзя закрыть черновик «" + document.name + "»: на него ссылаются " +
      referencedBy.map(item => "«" + item.name + "»").join(", ") +
      ". Сначала сохрани связанный объект или удали эти связи.",
      true
    );
  }
  const isUnsaved = state?.objectId === objectId ? !state.saved : !document.saved;
  if (isUnsaved && !window.confirm("Вкладка «" + document.name + "» содержит несохранённые изменения. Закрыть черновик и удалить только его временную сцену?")) return;
  const wasActive = state?.objectId === objectId;
  const remaining = openDocuments.filter(item => item.objectId !== objectId);
  const nextId = wasActive ? (remaining[Math.min(index, remaining.length - 1)]?.objectId || "") : "";
  try {
    if (wasActive) await syncNow();
    await api("object_close", { object_id: objectId, next_object_id: nextId });
    toast("Вкладка закрыта. Запись библиотеки не удалена.");
  } catch (error) { toast(error.message, true); }
}
async function createFromProfile(profileId, name) {
  const profile = creationProfiles.find(x => x.id === profileId);
  try {
    if (state) await syncNow();
    const result = await api("object_create", {
      mode: "new",
      profile_id: profileId,
      name: name || (profile?.name || "Новый объект"),
      category: profile?.category || "Other",
      description: ""
    });
    hydrateWorking(result.working);
    undoStack = [clone(state)];
    redoStack = [];
    $("createModal")?.classList.remove("open");
    setView("workspace");
    toast("Создан черновик: " + state.name);
  } catch (error) { toast(error.message, true); }
}
async function createFromTemplate(templateId) {
  const template = templates.find(x => x.objectId === templateId);
  if (!template) return toast("Шаблон не найден.", true);
  try {
    if (state) await syncNow();
    const result = await api("object_create", {
      mode: "template",
      source_id: templateId,
      name: template.name,
      category: template.category,
      description: template.description,
      tags: template.tags
    });
    hydrateWorking(result.working);
    undoStack = [clone(state)];
    redoStack = [];
    setView("workspace");
    toast("Создана независимая копия шаблона.");
  } catch (error) { toast(error.message, true); }
}
async function duplicateObject(objectId) {
  try {
    if (state) await syncNow();
    const result = await api("object_duplicate", { object_id: objectId });
    hydrateWorking(result.working);
    undoStack = [clone(state)];
    redoStack = [];
    setView("workspace");
    toast("Копия создана и добавлена в нативную библиотеку.");
  } catch (error) { toast(error.message, true); }
}
async function createTemplate(objectId) {
  try {
    await api("object_create_template", { object_id: objectId });
    toast("Шаблон сохранён в нативную библиотеку.");
  } catch (error) { toast(error.message, true); }
}
async function deleteObject(objectId) {
  const target = projectObjects.find(x => x.objectId === objectId);
  if (!target) return;
  const referencedBy = projectObjects.filter(x => x.relations.some(r => r.target_object_id === objectId));
  const note = referencedBy.length
    ? "\nНа объект ссылаются: " + referencedBy.map(x => x.name).join(", ") + ". Эти объекты и их данные не будут удалены."
    : "\nСвязанные объекты не удаляются вместе с ним.";
  if (!window.confirm("Удалить запись «" + target.name + "» из библиотеки?" + note)) return;
  try {
    const result = await api("object_delete", { object_id: objectId });
    if (state?.objectId === objectId) applyWorking(null);
    toast(result.message || "Объект удалён.");
  } catch (error) { toast(error.message, true); }
}
function collectRelatedSavePlan() {
  if (!state) return {drafts:[],saved:[],missing:[]};
  const objects = allRelationObjects();
  const byId = new Map(objects.map(object => [object.objectId, object]));
  const persistedIds = new Set(projectObjects.map(object => object.objectId));
  templates.forEach(template => { if (!byId.has(template.objectId)) byId.set(template.objectId,template); });
  const visited = new Set([state.objectId]);
  const queue = [state.objectId];
  const drafts = new Map(), saved = new Map(), missing = new Map();
  const addPath = (map,id,value,path) => {
    if (!map.has(id)) map.set(id,{object:value,via:[]});
    const entry=map.get(id);
    if (!entry.via.some(item=>item.sourceId===path.sourceId&&item.kind===path.kind)) entry.via.push(path);
  };
  while (queue.length) {
    const currentId = queue.shift();
    const current = byId.get(currentId);
    if (!current) continue;
    for (const relation of current.relations || []) {
      const targetId = String(relation.target_object_id || "");
      if (!targetId) continue;
      const path={sourceId:currentId,sourceName:current.name,kind:relation.kind||"related"};
      const target = byId.get(targetId);
      if (!target) {
        addPath(missing,targetId,{objectId:targetId,name:"Объект не найден"},path);
        continue;
      }
      if (target.saved && persistedIds.has(targetId)) {
        addPath(saved,targetId,target,path);
      } else {
        addPath(drafts,targetId,target,path);
        const existingMatch = findSavedObjectByIdentity(target.name,target.category,target.templateId);
        if (existingMatch) drafts.get(targetId).reuse = existingMatch;
      }
      if (visited.has(targetId)) continue;
      visited.add(targetId);
      queue.push(targetId);
    }
  }
  return {drafts:[...drafts.values()],saved:[...saved.values()],missing:[...missing.values()]};
}
function openLibrarySaveDialog(plan) {
  const modal = $("librarySaveModal");
  const list = $("librarySaveObjects");
  if (!modal || !list) return false;
  const drafts = plan.drafts || [];
  const alreadySaved = plan.saved || [];
  const missing = plan.missing || [];
  const describePaths = entry => [...new Set((entry.via||[]).map(path =>
    (path.sourceName || "Объект") + " · " + (RELATION_KIND_LABELS[path.kind] || path.kind)
  ))].join(" / ");
  $("librarySaveTitle").textContent = "Сохранить комплект объектов";
  $("librarySaveSummary").textContent =
    "Основной объект «" + state.name + "» будет сохранён обязательно. Отметь связанные черновики: если такой объект уже есть в библиотеке, связь будет направлена на существующую запись без создания копии. Снятые галочки оставят черновики открытыми.";
  const draftRows = drafts.map(entry => {
    const object=entry.object;
    return '<label class="library-save-item"><input type="checkbox" data-save-related="' + esc(object.objectId) + '" checked>' +
      '<span class="library-save-preview">' + esc(object.emoji || "📦") + '</span><span class="library-save-copy"><b>' + esc(object.name) +
      '</b><small>' + esc(describePaths(entry)) + ' · ' + esc(object.type || object.category || "Объект") +
      ' · ' + (object.relations || []).length + ' вложенных связей' +
      (entry.reuse ? ' · Совпадает с существующим объектом «' + esc(entry.reuse.name) + '»' : '') +
      '</small></span>' +
      '<span class="library-save-status">' + (entry.reuse ? 'Без копии' : 'Будет добавлен') + '</span></label>';
  }).join("");
  const savedRows = alreadySaved.map(entry => {
    const object=entry.object;
    return '<div class="library-save-item library-save-existing"><span class="library-save-preview">' + esc(object.emoji || "📦") +
      '</span><span class="library-save-copy"><b>' + esc(object.name) + '</b><small>' + esc(describePaths(entry)) +
      ' · ' + esc(object.type || object.category || "Объект") + '</small></span><span class="library-save-status">Уже в библиотеке</span></div>';
  }).join("");
  const missingRows = missing.map(entry => {
    const sourceNames=[...new Set((entry.via||[]).map(path=>path.sourceName))].join(", ");
    const kinds=[...new Set((entry.via||[]).map(path=>RELATION_KIND_LABELS[path.kind]||path.kind))].join(" / ");
    return '<div class="library-save-item library-save-missing"><span class="library-save-preview">⚠</span><span class="library-save-copy"><b>' +
      esc(entry.object.name) + '</b><small>Связь из «' + esc(sourceNames) + '» · ' + esc(kinds) + ' · ID: ' + esc(entry.objectId) +
      '</small></span><span class="library-save-status">Не найден</span></div>';
  }).join("");
  list.innerHTML =
    (drafts.length ? '<div class="library-save-bulk"><button class="btn small" type="button" id="librarySaveSelectAll">Выбрать все</button><button class="btn small" type="button" id="librarySaveSelectNone">Снять все</button></div>' + draftRows : '') +
    savedRows + missingRows ||
    '<div class="empty compact-empty">У объекта пока нет связанных целей.</div>';
  const confirm = $("confirmLibrarySave");
  confirm.disabled = missing.length > 0;
  confirm.title = missing.length ? "Сначала исправь отсутствующие связанные объекты." : "";
  if (missing.length) {
    $("librarySaveSummary").textContent += " Сохранение заблокировано: " + missing.length + " связанный объект отсутствует в черновиках и библиотеке. Исправь или удали эту связь.";
  }
  $("librarySaveSelectAll")?.addEventListener("click",() => list.querySelectorAll("[data-save-related]").forEach(input => { input.checked = true; }));
  $("librarySaveSelectNone")?.addEventListener("click",() => list.querySelectorAll("[data-save-related]").forEach(input => { input.checked = false; }));
  modal.classList.add("open");
  return true;
}
async function persistCurrentObject(relatedIds = []) {
  await syncNow();
  const result = await api("object_save", { related_object_ids: relatedIds });
  if (result.workspace) applyWorkspace(result.workspace);
  if (result.working) hydrateWorking(result.working);
  if (state) state.saved = true;
  const relatedNames = textArray(result.saved_related_names);
  const reusedNames = textArray(result.reused_related_names);
  setStatus("Объект и выбранные связи сохранены.");
  const savedLabel = relatedNames.length
    ? "Сохранено: " + [state?.name || "Объект", ...relatedNames].join(", ")
    : "Объект сохранён в библиотеку.";
  toast(reusedNames.length
    ? savedLabel + " Уже существующие записи использованы без дублирования: " + reusedNames.join(", ") + "."
    : savedLabel);
}
async function saveCurrentObject() {
  if (!state) return toast("Сначала создай или открой объект.");
  try {
    await syncNow();
    const relatedPlan = collectRelatedSavePlan();
    if (relatedPlan.drafts.length || relatedPlan.saved.length || relatedPlan.missing.length) {
      openLibrarySaveDialog(relatedPlan);
      return;
    }
    await persistCurrentObject([]);
  } catch (error) { toast(error.message, true); }
}
async function saveCurrentObjectAs() {
  if (!state) return toast("Сначала создай или открой объект.");
  const sourceName = state.name;
  openForm({
    eyebrow:"СОХРАНИТЬ КАК",
    title:"Создать отдельную копию",
    description:"Будет создан новый объект с отдельным ID и собственной сценой. Исходный объект останется в библиотеке без изменений; существующие связи будут сохранены.",
    fields:[
      {key:"name",label:"Название новой копии",value:sourceName + " — копия"}
    ],
    submitLabel:"Создать копию",
    onSubmit:async values => {
      const name = String(values.name || "").trim();
      if (!name) throw new Error("Укажи название новой копии.");
      await syncNow();
      const result = await api("object_save_as",{name});
      if (result.workspace) applyWorkspace(result.workspace);
      if (result.working) hydrateWorking(result.working);
      if (state) state.saved = true;
      undoStack = state ? [clone(state)] : [];
      redoStack = [];
      setView("workspace");
      toast(result.message || ("Создана отдельная копия «" + (state?.name || name) + "». Исходник не изменён."));
      return true;
    }
  });
}
async function confirmLibrarySave() {
  const button = $("confirmLibrarySave");
  if (!button || button.disabled) return;
  if (button.disabled) return;
  const relatedIds = [...$("librarySaveObjects").querySelectorAll("[data-save-related]:checked")]
    .map(input => input.dataset.saveRelated);
  const originalText = button.textContent;
  button.disabled = true;
  button.textContent = "Сохранение…";
  try {
    await persistCurrentObject(relatedIds);
    $("librarySaveModal").classList.remove("open");
  } catch (error) {
    toast(error.message, true);
    setStatus("Сохранение не завершено. Исправь ошибки и повтори попытку.", true);
  } finally {
    button.disabled = false;
    button.textContent = originalText || "Сохранить выбранное";
  }
}
async function toggleCapability(capabilityId, enabled) {
  if (!state) return toast("Сначала создай объект.");
  try {
    await syncNow();
    const plan = await api("capability_plan", { capability_id: capabilityId, enabled });
    const lines = textArray(plan.summary_lines);
    if (plan.requires_confirmation && !window.confirm(lines.join("\n"))) return;
    const committed = await api("capability_commit");
    hydrateWorking(committed.working);
    captureUndo();
    toast(enabled ? "Механика подключена." : "Механика отключена.");
  } catch (error) { toast(error.message, true); }
}
async function saveCapabilitySettings(capabilityId, fields) {
  try {
    const settings = fields.map(field => ({
      component_id: field.componentId,
      setting_key: field.key,
      value: field.value
    }));
    const result = await api("capability_settings_save", { capability_id: capabilityId, settings });
    hydrateWorking(result.working);
    captureUndo();
    toast("Параметры механики обновлены.");
    return true;
  } catch (error) {
    toast(error.message, true);
    return false;
  }
}
async function addProperty(values) {
  try {
    const result = await api("property_add", values);
    hydrateWorking(result.working);
    captureUndo();
    toast("Свойство добавлено.");
  } catch (error) { toast(error.message, true); }
}
async function updateProperty(values) {
  try {
    const result = await api("property_update", values);
    hydrateWorking(result.working);
    captureUndo();
    toast("Свойство обновлено.");
  } catch (error) { toast(error.message, true); }
}
async function removeProperty(propertyId) {
  if (!window.confirm("Удалить свойство «" + propertyId + "»?")) return;
  try {
    const result = await api("property_remove", { property_id: propertyId });
    hydrateWorking(result.working);
    captureUndo();
    toast("Свойство удалено.");
  } catch (error) { toast(error.message, true); }
}
async function addPart(values) {
  try {
    const result = await api("part_add", values);
    hydrateWorking(result.working);
    captureUndo();
    toast("Узел добавлен в структуру.");
  } catch (error) { toast(error.message, true); }
}
async function updatePart(values) {
  try {
    const result = await api("part_update", values);
    hydrateWorking(result.working);
    captureUndo();
    toast("Узел обновлён.");
  } catch (error) { toast(error.message, true); }
}
async function removePart(partId) {
  const target = state?.parts?.find(x => x.id === partId);
  if (!target) return;
  const childCount = state.parts.filter(x => x.parentId === partId).length;
  const note = childCount ? "\nДочерние узлы сохранятся и будут перенесены на уровень выше." : "";
  if (!window.confirm("Удалить узел «" + target.name + "»?" + note)) return;
  try {
    const result = await api("part_remove", { part_id: partId });
    hydrateWorking(result.working);
    captureUndo();
    toast("Узел удалён. Дочерние узлы не удалялись.");
  } catch (error) { toast(error.message, true); }
}
async function addRelation(values,options = {}) {
  try {
    const result = await api("relation_add", values);
    hydrateWorking(result.working);
    captureUndo();
    if (!options.silent) toast("Связь добавлена. Целевой объект остался отдельной записью библиотеки.");
    return true;
  } catch (error) {
    toast(error.message, true);
    return false;
  }
}
async function updateRelation(values) {
  try {
    const result = await api("relation_update", values);
    hydrateWorking(result.working);
    captureUndo();
    toast("Связь обновлена.");
  } catch (error) { toast(error.message, true); }
}
async function removeRelation(relationId) {
  if (!window.confirm("Удалить только связь? Целевой объект останется в библиотеке.")) return;
  try {
    const result = await api("relation_remove", { relation_id: relationId });
    hydrateWorking(result.working);
    captureUndo();
    toast("Удалена только связь.");
  } catch (error) { toast(error.message, true); }
}
async function addComponent(componentId) {
  try {
    const result = await api("component_add", { component_id: componentId });
    hydrateWorking(result.working);
    captureUndo();
    toast("Нативный компонент добавлен.");
  } catch (error) { toast(error.message, true); }
}
async function removeComponent(componentId) {
  if (!window.confirm("Удалить компонент «" + componentId + "»?")) return;
  try {
    const result = await api("component_remove", { component_id: componentId });
    hydrateWorking(result.working);
    captureUndo();
    toast("Компонент удалён.");
  } catch (error) { toast(error.message, true); }
}
async function saveComponentSettings(componentId, settings) {
  try {
    const result = await api("component_settings_save", { component_id: componentId, settings });
    hydrateWorking(result.working);
    captureUndo();
    toast("Настройки компонента сохранены.");
  } catch (error) { toast(error.message, true); }
}
async function toggleFavorite(objectId) {
  try { await api("favorite_toggle", { object_id: objectId }); }
  catch (error) { toast(error.message, true); }
}
async function addCategory(name) {
  try { await api("category_add", { name }); toast("Категория добавлена."); }
  catch (error) { toast(error.message, true); }
}
async function renameCategory(oldName) {
  const name = window.prompt("Новое название категории:", oldName);
  if (!name || !name.trim()) return;
  try { await api("category_rename", { old_name: oldName, new_name: name.trim() }); toast("Категория переименована."); }
  catch (error) { toast(error.message, true); }
}
async function deleteCategory(category) {
  const used = projectObjects.filter(x => x.category === category).length + templates.filter(x => x.category === category).length;
  if (!window.confirm("Удалить категорию «" + category + "»? Записи (" + used + ") перейдут в Other; сами объекты и шаблоны останутся.")) return;
  try { await api("category_delete", { category }); toast("Категория удалена, записи сохранены."); }
  catch (error) { toast(error.message, true); }
}
async function classifyTemplate(templateId) {
  const template = templates.find(x => x.objectId === templateId);
  if (!template) return;
  const category = window.prompt("Категория:", template.category);
  if (category == null) return;
  const subcategory = window.prompt("Подкатегория:", template.subcategory || "");
  if (subcategory == null) return;
  try { await api("template_classify", { template_id: templateId, category, subcategory }); toast("Классификация шаблона сохранена."); }
  catch (error) { toast(error.message, true); }
}
async function createCollection(name) {
  try { await api("collection_create", { name }); toast("Коллекция создана."); }
  catch (error) { toast(error.message, true); }
}
async function updateCollection(collectionId, payload) {
  try {
    await api("collection_update", { collection_id: collectionId, ...payload });
    return true;
  } catch (error) {
    toast(error.message, true);
    throw error;
  }
}
async function deleteCollection(collectionId) {
  if (!window.confirm("Удалить коллекцию? Объекты останутся в библиотеке.")) return;
  try { await api("collection_delete", { collection_id: collectionId }); }
  catch (error) { toast(error.message, true); }
}
function valueForSetting(capabilityId, descriptor) {
  const group = state?.mechanicSettings?.[capabilityId] || {};
  const componentSettings = group[descriptor.component_id] || {};
  const key = descriptor.setting_key || descriptor.key;
  return componentSettings[key] !== undefined ? componentSettings[key] : descriptor.default_value;
}
function fieldType(valueType) {
  return ({String:"text",Integer:"number",Float:"number",Boolean:"checkbox",Vector2:"text"})[valueType] || "text";
}
function parseVector2Value(value) {
  if (value && typeof value === "object" && value.__type === "Vector2") {
    return {__type:"Vector2",x:Number(value.x) || 0,y:Number(value.y) || 0};
  }
  const raw = String(value ?? "").trim();
  if (raw.startsWith("{")) {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object" && (parsed.__type === "Vector2" || ("x" in parsed && "y" in parsed))) {
      return {__type:"Vector2",x:Number(parsed.x) || 0,y:Number(parsed.y) || 0};
    }
  }
  const parts = raw.split(",").map(x => Number(x.trim()));
  if (parts.length !== 2 || parts.some(x => !Number.isFinite(x))) {
    throw new Error("Для Vector2 введи два числа через запятую: X, Y.");
  }
  return {__type:"Vector2",x:parts[0],y:parts[1]};
}
function fieldMarkup(label, key, value, type = "text", extra = "") {
  if (type === "textarea") {
    return '<div class="field"><label>' + esc(label) + '</label><textarea data-field="' + esc(key) + '" ' + extra + '>' + esc(value) + '</textarea></div>';
  }
  if (type === "select") {
    return '<div class="field"><label>' + esc(label) + '</label><select data-field="' + esc(key) + '" ' + extra + '></select></div>';
  }
  return '<div class="field"><label>' + esc(label) + '</label><input data-field="' + esc(key) + '" type="' + type + '" value="' + esc(value) + '" ' + extra + '></div>';
}
function dialogFieldMarkup(field) {
  const key = String(field.key || "");
  const disabled = !!field.disabled;
  const required = !!field.required;
  const value = field.value ?? "";
  const label = esc(field.label || "");
  const requiredMark = required ? '<span class="field-required" aria-label="Обязательное поле"> *</span>' : "";
  const unitMark = field.unit ? '<small class="setting-unit">' + esc(field.unit) + '</small>' : "";
  const help = field.description ? '<small class="field-help">' + esc(field.description) + '</small>' : "";
  const disabledAttr = disabled ? "disabled" : "";
  const requiredAttr = required ? "required" : "";
  if (field.type === "unavailable") {
    return '<div class="field setting-unavailable-field"><label>' + label + requiredMark + unitMark + '</label>' +
      '<div class="setting-unavailable">' + esc(field.unavailableMessage || "Для этого параметра ещё не подключён подходящий визуальный редактор.") + '</div>' +
      help + '</div>';
  }
  if (field.type === "checkbox") {
    return '<div class="field dialog-checkbox-field"><label><input data-dialog-field="' + esc(key) + '" type="checkbox" ' +
      (value ? "checked" : "") + ' ' + disabledAttr + ' ' + requiredAttr + '> ' + label + requiredMark + unitMark + '</label>' + help + '</div>';
  }
  if (field.type === "select" || field.type === "catalog_reference") {
    const options = Array.isArray(field.options) ? field.options : [];
    const currentValue = String(value ?? "");
    const currentExists = options.some(option => String(option.value) === currentValue);
    let optionMarkup = '<option value="" ' + (!currentValue ? "selected" : "") + ' disabled>' +
      esc(field.placeholder || (field.type === "catalog_reference" ? "Выбери предмет…" : "Выбери значение…")) + '</option>';
    if (currentValue && !currentExists) {
      optionMarkup += '<option value="' + esc(currentValue) + '" selected disabled>Не найдено в каталоге: ' + esc(currentValue) + '</option>';
    }
    optionMarkup += options.map(option => {
      const optionValue = String(option.value ?? "");
      const optionLabel = String(option.label ?? optionValue);
      const fullLabel = option.category ? optionLabel + " · " + String(option.category) : optionLabel;
      return '<option value="' + esc(optionValue) + '" ' +
        (optionValue === currentValue ? "selected" : "") + '>' + esc(fullLabel) + '</option>';
    }).join("");
    const search = field.searchable
      ? '<input class="catalog-option-search" type="search" data-dialog-search-for="' + esc(key) + '" placeholder="Поиск по каталогу…" ' + disabledAttr + '>'
      : "";
    return '<div class="field setting-select-field"><label>' + label + requiredMark + unitMark + '</label>' + search +
      '<select data-dialog-field="' + esc(key) + '" ' + disabledAttr + ' ' + requiredAttr + '>' + optionMarkup + '</select>' + help + '</div>';
  }
  if (field.type === "vector2") {
    const x = value && typeof value === "object" ? Number(value.x) || 0 : 0;
    const y = value && typeof value === "object" ? Number(value.y) || 0 : 0;
    return '<div class="field"><label>' + label + requiredMark + unitMark + '</label>' +
      '<div class="setting-vector2"><label>X<input type="number" data-dialog-vector-x="' + esc(key) + '" value="' + esc(x) + '" step="' + esc(field.step ?? 0.1) + '" ' + disabledAttr + ' ' + requiredAttr + '></label>' +
      '<label>Y<input type="number" data-dialog-vector-y="' + esc(key) + '" value="' + esc(y) + '" step="' + esc(field.step ?? 0.1) + '" ' + disabledAttr + ' ' + requiredAttr + '></label></div>' + help + '</div>';
  }
  if (field.type === "slider") {
    return '<div class="field setting-slider-field"><label>' + label + requiredMark + unitMark + '</label>' +
      '<div class="setting-slider-row"><input data-dialog-field="' + esc(key) + '" type="range" value="' + esc(value) + '" ' +
      (field.min !== undefined ? 'min="' + esc(field.min) + '"' : "") + ' ' +
      (field.max !== undefined ? 'max="' + esc(field.max) + '"' : "") + ' ' +
      (field.step !== undefined ? 'step="' + esc(field.step) + '"' : "") + ' ' + disabledAttr + ' ' + requiredAttr + '>' +
      '<output data-dialog-range-output="' + esc(key) + '">' + esc(value) + (field.unit ? " " + esc(field.unit) : "") + '</output></div>' + help + '</div>';
  }
  if (field.type === "textarea") {
    return '<div class="field"><label>' + label + requiredMark + unitMark + '</label><textarea data-dialog-field="' + esc(key) + '" ' +
      disabledAttr + ' ' + requiredAttr + '>' + esc(value) + '</textarea>' + help + '</div>';
  }
  if (field.type === "resource_path") {
    return '<div class="field"><label>' + label + requiredMark + unitMark + '</label><div class="setting-resource-row">' +
      '<input data-dialog-field="' + esc(key) + '" type="text" value="' + esc(value) + '" ' + disabledAttr + ' ' + requiredAttr + '>' +
      '<button class="btn small" type="button" data-pick-table-path="' + esc(key) + '" data-table-type="' + esc(field.tableType || "") + '" ' + disabledAttr + '>Выбрать .tres</button>' +
      (field.legacyKey ? '<button class="btn small" type="button" data-create-table-path="' + esc(key) + '" data-table-type="' + esc(field.tableType || "") + '" data-legacy-key="' + esc(field.legacyKey) + '" ' + disabledAttr + '>Импортировать старые данные</button>' : '') +
      '</div>' + help + '</div>';
  }
  const inputType = field.type === "number" ? "number" : "text";
  return '<div class="field"><label>' + label + requiredMark + unitMark + '</label><input data-dialog-field="' + esc(key) + '" type="' + inputType +
    '" value="' + esc(value) + '" ' + (field.min !== undefined ? 'min="' + esc(field.min) + '"' : "") + ' ' +
    (field.max !== undefined ? 'max="' + esc(field.max) + '"' : "") + ' ' +
    (field.step !== undefined ? 'step="' + esc(field.step) + '"' : "") + ' ' +
    (field.placeholder ? 'placeholder="' + esc(field.placeholder) + '"' : "") + ' ' + disabledAttr + ' ' + requiredAttr + '>' + help + '</div>';
}
function renderSettingGroups(fields) {
  const groups = new Map();
  for (const field of fields) {
    const id = String(field.groupId || field.groupName || "settings");
    if (!groups.has(id)) groups.set(id, {
      id,
      name: String(field.groupName || "Основные настройки"),
      order: Number.isFinite(Number(field.groupOrder)) ? Number(field.groupOrder) : 0,
      fields: []
    });
    groups.get(id).fields.push(field);
  }
  return [...groups.values()].sort((a, b) => a.order - b.order || a.name.localeCompare(b.name, "ru")).map(group => {
    group.fields.sort((a, b) => Number(a.order || 0) - Number(b.order || 0));
    return '<section class="setting-group" data-setting-group="' + esc(group.id) + '">' +
      '<h3>' + esc(group.name) + '</h3><div class="setting-group-fields">' +
      group.fields.map(dialogFieldMarkup).join("") + '</div></section>';
  }).join("");
}
function renderGroupedMechanicFields(fields) {
  const basic = [];
  const advanced = [];
  const expert = [];
  for (const field of fields) {
    const level = String(field.level || "Basic").toLowerCase();
    if (level === "expert") expert.push(field);
    else if (level === "advanced") advanced.push(field);
    else basic.push(field);
  }
  let markup = renderSettingGroups(basic);
  if (advanced.length) {
    markup += '<details class="setting-level-details"><summary>Расширенные настройки <span>' + advanced.length + '</span></summary>' +
      renderSettingGroups(advanced) + '</details>';
  }
  if (expert.length) {
    markup += '<details class="setting-level-details setting-expert-details"><summary>Экспертные настройки <span>' + expert.length + '</span></summary>' +
      renderSettingGroups(expert) + '</details>';
  }
  return markup;
}
function openForm(options) {
  const modal = $("editorDialogModal");
  const form = $("editorDialogForm");
  if (!modal || !form) return;
  $("editorDialogEyebrow").textContent = options.eyebrow || "OBJECT BUILDER";
  $("editorDialogTitle").textContent = options.title || "Изменить";
  $("editorDialogDescription").textContent = options.description || "";
  $("editorDialogSubmit").textContent = options.submitLabel || "Сохранить";
  const fieldsHost = $("editorDialogFields");
  fieldsHost.innerHTML = (options.groupedSettings
    ? renderGroupedMechanicFields(options.fields || [])
    : (options.fields || []).map(dialogFieldMarkup).join("")) + (options.extraMarkup || "");
  if (typeof options.onOpen === "function") options.onOpen(fieldsHost);
  fieldsHost.querySelectorAll("[data-dialog-search-for]").forEach(search => {
    search.addEventListener("input", () => {
      const targetKey = search.dataset.dialogSearchFor;
      const select = [...fieldsHost.querySelectorAll("[data-dialog-field]")].find(input => input.dataset.dialogField === targetKey);
      if (!select) return;
      const query = search.value.trim().toLocaleLowerCase();
      [...select.options].forEach(option => {
        if (!option.value) return;
        option.hidden = !!query && !option.textContent.toLocaleLowerCase().includes(query);
      });
    });
  });
  fieldsHost.querySelectorAll("[data-dialog-range-output]").forEach(output => {
    const targetKey = output.dataset.dialogRangeOutput;
    const input = [...fieldsHost.querySelectorAll("[data-dialog-field]")].find(control => control.dataset.dialogField === targetKey);
    if (!input) return;
    const updateOutput = () => {
      const field = (options.fields || []).find(item => String(item.key || "") === targetKey);
      output.textContent = input.value + (field?.unit ? " " + field.unit : "");
    };
    input.addEventListener("input", updateOutput);
    updateOutput();
  });
  pendingFormCallback = options.onSubmit || null;
  form.onsubmit = async event => {
    event.preventDefault();
    if (!pendingFormCallback) return;
    const values = {};
    for (const field of fieldsHost.querySelectorAll("[data-dialog-field]")) {
      const key = field.dataset.dialogField;
      values[key] = field.type === "checkbox" ? field.checked : field.value;
    }
    for (const xInput of fieldsHost.querySelectorAll("[data-dialog-vector-x]")) {
      const key = xInput.dataset.dialogVectorX;
      const yInput = [...fieldsHost.querySelectorAll("[data-dialog-vector-y]")].find(input => input.dataset.dialogVectorY === key);
      values[key] = {
        __type: "Vector2",
        x: Number(xInput.value),
        y: Number(yInput?.value ?? 0)
      };
    }
    try {
      const accepted = await pendingFormCallback(values);
      if (accepted !== false) modal.classList.remove("open");
    } catch (error) { toast(error.message, true); }
  };
  modal.classList.add("open");
}
function setView(next) {
  const views = ["workspace","library","catalog","projectLibrary"];
  if (!views.includes(next)) return;
  activeView = next;
  document.querySelectorAll("[data-view]").forEach(button => {
    const active = button.dataset.view === next;
    button.classList.toggle("active", active);
    if (active) button.setAttribute("aria-current","page");
    else button.removeAttribute("aria-current");
  });
  views.forEach(id => $(id + "View")?.classList.toggle("hidden", id !== next));
  const titles = {
    workspace:"Редактор объектов",
    library:"Шаблоны и профили",
    catalog:"Каталог механик",
    projectLibrary:"Нативная библиотека"
  };
  const subtitles = {
    workspace:"Собирай структуру, свойства, компоненты, механики и связи объекта.",
    library:"Сохранённые ObjectDefinition-шаблоны и профили создания из нативного реестра.",
    catalog:"Реальные возможности ObjectCapabilityCatalog с нативными зависимостями и настройками.",
    projectLibrary:"Каждый объект — отдельный ObjectDefinition. Связанные записи не сливаются и не удаляются каскадно."
  };
  $("pageTitle").textContent = titles[next];
  $("pageSub").textContent = subtitles[next];
  if (next === "catalog") renderCatalog();
  if (next === "library") renderLibrary();
  if (next === "projectLibrary") renderProjectLibrary();
}
function renderAll() {
  renderStats();
  renderParts();
  renderLeftEditor();
  renderCanvas();
  renderInstalled();
  renderInspector();
  renderEditorObjectTabs();
  if (state) {
    openSpriteEditor();
  } else {
    $("spriteEditorWorkspace")?.classList.add("hidden");
    $("canvas")?.classList.remove("hidden");
    document.querySelector(".canvas-foot")?.classList.remove("hidden");
  }
  updateUndoButtons();
  const save = $("saveCurrentObject");
  if (save) {
    save.disabled = !state;
    save.textContent = state ? (state.saved ? "Сохранено ✓" : "Сохранить *") : "Сохранить";
    save.classList.toggle("primary", !!state && !state.saved);
  }
  const saveAs = $("saveCurrentObjectAs");
  if (saveAs) saveAs.disabled = !state;
  const templateButton = $("addToLibrary");
  if (templateButton) {
    templateButton.disabled = !state || !state.objectId || state.isTemplate || !state.saved;
    templateButton.textContent = "Создать шаблон";
    templateButton.title = "Создать отдельный шаблон из сохранённого объекта";
  }
  if (activeView === "projectLibrary") renderProjectLibrary();
  if (activeView === "library") renderLibrary();
  if (activeView === "catalog") renderCatalog();
  setStatus(statusMessage || (state ? (state.saved ? "Сохранено" : "Есть изменения") : "Нет объекта"), statusError);
}
function renderStats() {
  const hostEl = $("stats");
  if (!hostEl) return;
  const installed = state?.caps?.length || 0;
  const parts = Math.max(0, (state?.parts?.length || 1) - 1);
  const relations = state?.relations?.length || 0;
  hostEl.innerHTML = [
    [state?.name || "—","ТЕКУЩИЙ ОБЪЕКТ",state ? (state.saved ? "Сохранённый ObjectDefinition" : "Черновик с изменениями") : "Сначала создай или открой объект"],
    [parts,"ДОЧЕРНИЕ УЗЛЫ","Декларативная структура объекта"],
    [installed,"МЕХАНИКИ","Нативные возможности и зависимости"],
    [relations,"СВЯЗИ","Ссылки на независимые записи библиотеки"]
  ].map((item,index) => '<div class="stat"><label>' + item[1] + '</label><strong>' + esc(item[0]) + '</strong><span>' + esc(item[2]) + '</span></div>').join("");
}
function renderParts() {
  $("partCount").textContent = String(state?.parts?.length || 0);
}
function renderGraphNode(part, visited = new Set(), depth = 0) {
  if (!part || visited.has(part.id)) return '<div class="object-graph-warning">Цикл или пустой узел</div>';
  visited.add(part.id);
  const children = (state?.parts || []).filter(item => item.parentId === part.id);
  const nodeType = part.nodeType || part.kind || "Node2D";
  const icon = nodeType.includes("Collision") ? "▧" : nodeType.includes("Sprite") ? "▤" : part.id === "root" ? (state?.emoji || "◆") : "◇";
  return '<div class="object-graph-branch">' +
    '<button type="button" class="object-graph-node ' + (selectedPartId === part.id ? "selected" : "") + '" data-canvas-part="' + esc(part.id) + '" style="--node-depth:' + Math.min(depth,8) + '">' +
      '<span class="object-graph-icon">' + esc(icon) + '</span>' +
      '<span class="object-graph-copy"><b>' + esc(part.name || nodeType) + '</b><small>' + esc(nodeType) + (part.enabled === false ? " · выключен" : "") + '</small></span>' +
      '<span class="object-graph-id">' + esc(part.id) + '</span>' +
    '</button>' +
    (children.length ? '<div class="object-graph-children">' + children.map(child => renderGraphNode(child, new Set(visited), depth + 1)).join("") + '</div>' : '') +
  '</div>';
}
function renderCanvas() {
  $("objectTitle").textContent = state ? state.name : "Нет объекта";
  const root = state?.parts?.find(part => part.id === "root");
  const collision = state?.collision || {};
  const shape = collision.shape || "rectangle";
  const rawWidth = shape === "circle" ? (Number(collision.radius) || 16) * 2 :
    shape === "capsule" ? (Number(collision.radius) || 16) * 2 : Number(collision.size?.x) || 32;
  const rawHeight = shape === "circle" ? (Number(collision.radius) || 16) * 2 :
    shape === "capsule" ? Number(collision.height) || 32 : Number(collision.size?.y) || 32;
  const collisionWidth = Math.max(12,Math.min(190,rawWidth * 1.45));
  const collisionHeight = Math.max(12,Math.min(190,rawHeight * 1.45));
  const offsetX = Math.max(-85,Math.min(85,Number(collision.offset?.x) || 0));
  const offsetY = Math.max(-85,Math.min(85,Number(collision.offset?.y) || 0));
  const collisionMarkup = collision.enabled
    ? '<div class="collision-overlay ' + esc(shape) + '" style="width:' + collisionWidth + 'px;height:' + collisionHeight +
      'px;transform:translate(calc(-50% + ' + offsetX + 'px),calc(-50% + ' + offsetY + 'px))"></div>'
    : "";
  const objectWidth = Math.max(12,Math.min(250,(Number(state?.objectSize?.x) || 32) * 1.45));
  const objectHeight = Math.max(12,Math.min(250,(Number(state?.objectSize?.y) || 32) * 1.45));
  const objectBoundsMarkup = state
    ? '<div class="object-bounds-overlay" title="Габариты объекта ' + esc(state.objectSize.x + " × " + state.objectSize.y + " px") +
      '" style="width:' + objectWidth + 'px;height:' + objectHeight + 'px"></div>'
    : "";
  const visualSettings = state?.sprite || {scale:{x:1,y:1},offset:{x:0,y:0}};
  const visualTransform = 'translate(' + (Number(visualSettings.offset?.x) || 0) + 'px,' + (Number(visualSettings.offset?.y) || 0) + 'px) rotate(' +
    (Number(visualSettings.rotation) || 0) + 'deg) scale(' +
    (Number(visualSettings.scale?.x) || 1) + ',' + (Number(visualSettings.scale?.y) || 1) + ')';
  const visualMarkup = state?.previewDataUrl
    ? '<img class="object-preview-image" src="' + esc(state.previewDataUrl) + '" alt="' + esc(state.name) + '">'
    : '<span class="object-preview-emoji">' + esc(state?.emoji || "◆") + '</span>';
  $("objectArt").innerHTML = state && root
    ? '<div class="object-preview-stage">' + objectBoundsMarkup + '<div class="object-preview-visual" style="transform:' + esc(visualTransform) + '">' + visualMarkup + '</div>' + collisionMarkup +
      '</div><div class="object-preview-caption">' +
      (state.previewDataUrl ? "СПРАЙТ НАЗНАЧЕН" : "ЭМОДЗИ-ЗАГЛУШКА · СПРАЙТ НЕ ДОБАВЛЕН") +
      (collision.enabled ? ' <span>· КОЛЛИЗИЯ ' + esc(shape.toUpperCase()) + '</span>' : "") +
      '</div><div class="object-graph"><div class="mini-title">СТРУКТУРА ОБЪЕКТА</div>' + renderGraphNode(root) + '</div>'
    : '<span class="canvas-empty-mark">◇</span>';
  $("objectLabel").textContent = state ? state.name : "";
  $("objectArtboard").classList.toggle("selected", !!state && selectedPartId === "root");
  $("objectArtboard").classList.toggle("is-empty", !state);
  $("objectArtboard").style.transform = "scale(" + (window._obZoom || 100) / 100 + ")";
  $("zoomLabel").textContent = (window._obZoom || 100) + "%";
  $("objectTypeLabel").textContent = state ? state.type + " · " + state.nativeRootType : "Пустой редактор";
  $("canvas").style.backgroundSize = window._obGrid === false ? "0 0,0 0,auto" : "24px 24px,24px 24px,auto";
  ["zoomOut","zoomIn","gridToggle","uploadSprite"].forEach(id => { if ($(id)) $(id).disabled = !state && id !== "gridToggle"; });
  const foot = $("canvas").querySelector(".canvas-foot span:last-child");
  if (foot) foot.textContent = "ПРЕДПРОСМОТР СПРАЙТА · КОЛЛИЗИЯ · ДЕРЕВО УЗЛОВ";
  $("objectArt").querySelectorAll("[data-canvas-part]").forEach(button => button.onclick = () => {
    selectedPartId = button.dataset.canvasPart;
    if (selectedPartId === "root") setInspectorTab("Объект");
    else setLeftEditorTab("Части");
    renderCanvas();
    renderParts();
  });
  let openButton = $("openNativeScene");
  if (!openButton) {
    openButton = document.createElement("button");
    openButton.id = "openNativeScene";
    openButton.className = "toolbtn";
    openButton.textContent = "Открыть сцену в Godot ↗";
    document.querySelector(".canvas-toolbar-actions")?.appendChild(openButton);
    openButton.onclick = () => {
      if (state?.scenePath) host.request("scene_open", { scene_path: state.scenePath }).then(() => toast("Сцена открыта в Godot.")).catch(error => toast(error.message, true));
      else toast("Сначала сохрани объект, чтобы создать его сцену.");
    };
  }
  openButton.disabled = !state?.scenePath;
}

function renderEditorObjectTabs() {
  const el = $("editorObjectTabs");
  if (!el) return;
  el.innerHTML = openDocuments.length
    ? openDocuments.map(item => {
        const active = state?.objectId === item.objectId;
        const current = active ? state : item;
        return '<span class="editor-object-tab-wrap ' + (active ? "active" : "") + '">' +
          '<button class="editor-object-tab ' + (active ? "active" : "") + '" type="button" data-open-document="' + esc(item.objectId) + '">' +
          esc(current.name) + (current.saved ? "" : " *") + '</button>' +
          '<button class="editor-object-tab-close" type="button" data-close-document="' + esc(item.objectId) + '" title="Закрыть вкладку" aria-label="Закрыть ' + esc(item.name) + '">×</button>' +
        '</span>';
      }).join("")
    : '<span class="editor-tabs-empty">Нет открытого объекта</span>';
  el.querySelectorAll("[data-open-document]").forEach(button => button.onclick = () => {
    if (button.dataset.openDocument !== state?.objectId) openObject(button.dataset.openDocument);
  });
  el.querySelectorAll("[data-close-document]").forEach(button => button.onclick = () => closeObjectTab(button.dataset.closeDocument));
}
function installedMechanicRowMarkup(item) {
  return '<div class="installed-row"><span class="installed-icon">' + capabilityCategoryEmoji(item.category) +
    '</span><span class="installed-group-copy"><b>' + esc(item.name) + '</b><small>' + esc(item.category) +
    '</small></span><button type="button" class="mechanic-settings-button" data-installed-open="' + esc(item.id) +
    '" title="Открыть отдельное окно настроек">⚙ Настроить</button><button type="button" data-installed-remove="' +
    esc(item.id) + '" title="Отключить механику" aria-label="Отключить механику">×</button></div>';
}
function bindInstalledMechanicRows(root) {
  root.querySelectorAll("[data-installed-open]").forEach(button => button.onclick = () => {
    selectedCapabilityId = button.dataset.installedOpen;
    openCapabilitySettingsDialog(selectedCapabilityId);
  });
  root.querySelectorAll("[data-installed-remove]").forEach(button => button.onclick = () =>
    toggleCapability(button.dataset.installedRemove, false));
}
function renderInstalled() {
  const installed = (state?.caps || []).map(id => CATALOG.find(x => x.id === id)).filter(Boolean);
  $("installedCount").textContent = String(installed.length);
  $("installedList").innerHTML = installed.length
    ? installed.map(installedMechanicRowMarkup).join("")
    : '<div class="empty compact-empty">Пока нет подключённых механик.</div>';
  bindInstalledMechanicRows($("installedList"));
}
function setInspectorTab(tab) {
  inspectorTab = tab;
  $("inspectorTabs").querySelectorAll("[data-tab]").forEach(button => button.classList.toggle("active", button.dataset.tab === tab));
  renderInspector();
}
function setLeftEditorTab(tab) {
  leftEditorTab = tab;
  $("leftEditorNav")?.querySelectorAll("[data-left-tab]").forEach(button =>
    button.classList.toggle("active",button.dataset.leftTab === tab)
  );
  renderLeftEditor();
}
function renderLeftEditor() {
  const body = $("leftEditorBody");
  const nav = $("leftEditorNav");
  if (!body) return;
  if (nav) nav.querySelectorAll("[data-left-tab]").forEach(button => {
    button.disabled = !state;
    button.classList.toggle("active",button.dataset.leftTab === leftEditorTab);
  });
  if (!state) {
    body.innerHTML = '<div class="empty-editor compact"><span class="empty-editor-icon">◇</span><b>Редактор пуст</b><p>Создай объект или выбери шаблон.</p></div>';
    return;
  }
  if (leftEditorTab === "Внешний вид") renderAppearanceInspector(body);
  else if (leftEditorTab === "Коллизия") renderCollisionInspector(body);
  else renderPartsInspector(body);
}
function renderInspector() {
  const body = $("inspectorBody");
  if (!state) {
    $("inspectorContext").textContent = "НЕТ ОБЪЕКТА";
    $("inspectorTabs").querySelectorAll("[data-tab]").forEach(button => { button.disabled = true; button.classList.remove("active"); });
    body.innerHTML = '<div class="empty-editor"><span class="empty-editor-icon">◇</span><h3>Редактор пуст</h3><p>Создай объект с нуля по нативному профилю или сделай независимую копию сохранённого шаблона.</p><div class="empty-editor-actions"><button class="btn primary" type="button" data-empty-create>＋ Создать объект</button><button class="btn" type="button" data-empty-templates>Открыть шаблоны</button></div></div>';
    body.querySelector("[data-empty-create]").onclick = openCreate;
    body.querySelector("[data-empty-templates]").onclick = () => setView("library");
    return;
  }
  $("inspectorContext").textContent = state.nativeRootType.toUpperCase();
  $("inspectorTabs").querySelectorAll("[data-tab]").forEach(button => button.disabled = false);
  if (inspectorTab === "Объект") renderObjectInspector(body);
  else if (inspectorTab === "Поведение") renderBehaviorInspector(body);
  else if (inspectorTab === "Компоненты") renderComponentsInspector(body);
  else renderRelationsInspector(body);
}
function renderObjectInspector(body) {
  const rootOptions = ROOT_TYPES.map(type => '<option value="' + type + '" ' + (state.nativeRootType === type ? "selected" : "") + '>' + type + '</option>').join("");
  body.innerHTML =
    '<div class="mini-title">ОСНОВНЫЕ ДАННЫЕ</div>' +
    '<div class="field"><label>Название</label><input data-object-field="name" value="' + esc(state.name) + '" maxlength="80"></div>' +
    '<div class="field"><label>Категория</label><input list="objectCategoriesList" data-object-field="category" value="' + esc(state.category) + '"><datalist id="objectCategoriesList">' + categories.map(x => '<option value="' + esc(x) + '"></option>').join("") + '</datalist></div>' +
    '<div class="field"><label>Подкатегория</label><input list="objectSubcategoriesList" data-object-field="subcategory" value="' + esc(state.subcategory) + '"><datalist id="objectSubcategoriesList">' + textArray(subcategories[state.category]).map(x => '<option value="' + esc(x) + '"></option>').join("") + '</datalist></div>' +
    '<div class="field"><label>Тип корневого узла Godot</label><select data-object-field="nativeRootType">' + rootOptions + '</select></div>' +
    '<div class="field"><label>Описание</label><textarea data-object-field="description">' + esc(state.description) + '</textarea></div>' +
    '<div class="field"><label>Теги (через запятую)</label><input data-object-field="tags" value="' + esc(state.tags.join(", ")) + '"></div>' +
    '<div class="field"><label><input type="checkbox" data-object-field="isTemplate" ' + (state.isTemplate ? "checked" : "") + ' ' + (state.saved ? "disabled" : "") + '> Сохранять как шаблон</label><small>' + (state.saved ? (state.isTemplate ? "Это сохранённый шаблон. Для создания ещё одной версии используй копирование." : "Для сохранённого объекта используй отдельную команду «Создать шаблон».") : "При сохранении черновик попадёт в библиотеку шаблонов.") + '</small></div>' +
    '<div class="mini-title">ПОЛЬЗОВАТЕЛЬСКИЕ СВОЙСТВА <span class="count">' + state.properties.length + '</span></div>' +
    '<div id="propertyList">' + renderPropertyRows() + '</div>' +
    '<button class="btn small" type="button" id="propertyAdd">＋ Добавить свойство</button>' +
    '<div class="mini-title">ИДЕНТИФИКАТОР</div><div class="property-row"><span>ID</span><b>' + esc(state.objectId) + '</b></div>' +
    '<div class="detail-desc">Данные редактируются в черновике. Кнопка «Сохранить» записывает ObjectDefinition и сцену через нативные сервисы Godot.</div>';
  body.querySelectorAll("[data-object-field]").forEach(input => {
    const change = () => {
      captureUndo();
      const key = input.dataset.objectField;
      if (key === "tags") state.tags = input.value.split(",").map(x => x.trim()).filter(Boolean);
      else if (key === "isTemplate") {
        if (state.saved) return toast("Для сохранённой записи используй отдельную команду «Создать шаблон».");
        state.isTemplate = input.checked;
      }
      else if (key === "nativeRootType") state.nativeRootType = input.value;
      else state[key] = input.value;
      if (key === "name") state.parts.find(x => x.id === "root").name = state.name;
      scheduleSync();
      renderStats();
      renderCanvas();
      renderEditorObjectTabs();
      setStatus("Есть несохранённые изменения");
    };
    input.addEventListener("change", change);
    if (input.tagName === "INPUT" || input.tagName === "TEXTAREA") input.addEventListener("input", change);
  });
  $("propertyAdd").onclick = () => openPropertyForm();
  bindPropertyRows(body);
}
function renderPropertyRows() {
  if (!state.properties.length) return '<div class="empty compact-empty">Пользовательских свойств нет.</div>';
  return state.properties.map(property => '<div class="property-row"><span><b>' + esc(property.name || property.id) + '</b><small>' + esc(property.type) + ' · ' + esc(property.group || "Основное") + '</small></span><span>' + esc(String(property.default ?? "")) + '</span><button class="btn small" data-property-edit="' + esc(property.id) + '">Изменить</button><button class="btn small danger" data-property-remove="' + esc(property.id) + '">×</button></div>').join("");
}
function bindPropertyRows(root) {
  root.querySelectorAll("[data-property-edit]").forEach(button => button.onclick = () => {
    const property = state.properties.find(x => x.id === button.dataset.propertyEdit);
    if (property) openPropertyForm(property);
  });
  root.querySelectorAll("[data-property-remove]").forEach(button => button.onclick = () => removeProperty(button.dataset.propertyRemove));
}
function openPropertyForm(property = null) {
  const isEdit = !!property;
  const data = property || {id:"property_" + Math.random().toString(36).slice(2,8),name:"Новое свойство",type:"String",default:"",group:"Основное",description:"",hasRange:false,min:0,max:100};
  openForm({
    eyebrow:"OBJECT DEFINITION / CUSTOM PROPERTIES",
    title:isEdit ? "Изменить свойство" : "Добавить свойство",
    fields:[
      {key:"id",label:"ID",value:data.id,type:"text"},
      {key:"name",label:"Название",value:data.name,type:"text"},
      {key:"type",label:"Тип",value:data.type,type:"select",options:["String","Integer","Float","Boolean","Vector2"].map(x=>({value:x,label:x}))},
      {key:"default",label:"Значение по умолчанию",value:typeof data.default === "object" ? JSON.stringify(data.default) : data.default,type:"text"},
      {key:"group",label:"Группа",value:data.group || "Основное"},
      {key:"description",label:"Описание",value:data.description || "",type:"textarea"},
      {key:"has_range",label:"Ограничить числовой диапазон",value:!!data.hasRange,type:"checkbox"},
      {key:"minimum",label:"Минимум",value:data.min ?? 0,type:"number"},
      {key:"maximum",label:"Максимум",value:data.max ?? 100,type:"number"}
    ],
    onSubmit: async values => {
      let defaultValue = values.default;
      if (values.type === "Integer") defaultValue = Number.parseInt(defaultValue,10) || 0;
      if (values.type === "Float") defaultValue = Number(defaultValue) || 0;
      if (values.type === "Boolean") defaultValue = ["true","1","yes","да"].includes(String(defaultValue).toLowerCase());
      if (values.type === "Vector2") defaultValue = parseVector2Value(defaultValue);
      const payload = {...values,default:defaultValue,has_range:values.has_range === true,minimum:Number(values.minimum),maximum:Number(values.maximum)};
      if (isEdit) await updateProperty(payload); else await addProperty(payload);
    }
  });
}


function renderAppearanceInspector(body) {
  const textureSize = state.sprite.textureSize || {x:0,y:0};
  const displayedWidth = Math.round((textureSize.x || 0) * state.sprite.scale.x);
  const displayedHeight = Math.round((textureSize.y || 0) * state.sprite.scale.y);
  const preview = state.previewDataUrl
    ? '<img src="' + esc(state.previewDataUrl) + '" alt="' + esc(state.name) + '">'
    : '<span class="sprite-empty-emoji">' + esc(state.emoji || "◆") + '</span>';
  body.innerHTML =
    '<section class="editor-section-card"><div class="editor-section-heading"><div><b>Главный спрайт</b><small>Текстура объекта, отдельная от его логических габаритов</small></div><span class="editor-state-pill ' + (state.previewDataUrl ? "ready" : "") + '">' + (state.previewDataUrl ? "НАЗНАЧЕН" : "ЗАГЛУШКА") + '</span></div>' +
    '<div class="sprite-editor-preview">' + preview + '</div>' +
    '<div class="sprite-editor-actions"><button class="btn primary" type="button" id="appearanceSpritePick">' + (state.previewDataUrl ? "Заменить изображение" : "＋ Добавить спрайт") + '</button>' +
    '<button class="btn danger" type="button" id="appearanceSpriteClear" ' + (state.previewDataUrl ? "" : "disabled") + '>Убрать</button></div>' +
    '<button class="btn sprite-open-editor" type="button" id="openFullSpriteEditor">Открыть редактор спрайтов ↗</button>' +
    '<p class="detail-desc">PNG, JPEG и WebP. Исходный файл проекта не перемещается и не удаляется.</p></section>' +
    '<section class="editor-section-card"><div class="mini-title">ГАБАРИТЫ ИГРОВОГО ОБЪЕКТА</div>' +
    '<p class="detail-desc">Размер объекта — логический прямоугольник в мире. Он не меняет разрешение и масштаб изображения.</p>' +
    '<div class="field-grid"><div class="field"><label>Ширина объекта, px</label><input type="number" min="1" max="8192" step="1" data-appearance-field="objectWidth" value="' + state.objectSize.x + '"></div>' +
    '<div class="field"><label>Высота объекта, px</label><input type="number" min="1" max="8192" step="1" data-appearance-field="objectHeight" value="' + state.objectSize.y + '"></div></div>' +
    '<div class="mini-title">ВИДИМЫЙ РАЗМЕР СПРАЙТА</div>' +
    '<p class="detail-desc">Размер отрисовки считается из исходной ширины/высоты текстуры и масштаба. Меняя его, ты меняешь только спрайт.</p>' +
    '<div class="field-grid"><div class="field"><label>Ширина спрайта, px</label><input type="number" min="1" max="131072" step="1" data-appearance-field="spriteWidth" value="' + Math.max(1,displayedWidth || 32) + '" ' + (textureSize.x ? "" : "disabled") + '></div>' +
    '<div class="field"><label>Высота спрайта, px</label><input type="number" min="1" max="131072" step="1" data-appearance-field="spriteHeight" value="' + Math.max(1,displayedHeight || 32) + '" ' + (textureSize.y ? "" : "disabled") + '></div></div>' +
    '<div class="field-grid"><div class="field"><label>Масштаб X</label><input type="number" min="0.05" max="16" step="0.05" data-appearance-field="scaleX" value="' + state.sprite.scale.x + '"></div>' +
    '<div class="field"><label>Масштаб Y</label><input type="number" min="0.05" max="16" step="0.05" data-appearance-field="scaleY" value="' + state.sprite.scale.y + '"></div></div>' +
    '<div class="field-grid"><div class="field"><label>Смещение X, px</label><input type="number" min="-8192" max="8192" step="1" data-appearance-field="offsetX" value="' + state.sprite.offset.x + '"></div>' +
    '<div class="field"><label>Смещение Y, px</label><input type="number" min="-8192" max="8192" step="1" data-appearance-field="offsetY" value="' + state.sprite.offset.y + '"></div></div>' +
    '<div class="field"><label>Порядок отрисовки (Z-index)</label><input type="number" min="-4096" max="4096" step="1" data-appearance-field="zIndex" value="' + state.sprite.zIndex + '"></div>' +
    '<div class="field"><label>Эмодзи-заглушка</label><input id="appearanceEmoji" maxlength="8" value="' + esc(state.emoji || "◆") + '" placeholder="🌳"></div></section>';
  $("appearanceSpritePick").onclick = () => $("spriteFile").click();
  $("appearanceSpriteClear").onclick = clearSprite;
  $("openFullSpriteEditor").onclick = openSpriteEditor;
  $("appearanceEmoji").onchange = () => {
    state.emoji = $("appearanceEmoji").value.trim() || "◆";
    captureUndo();
    scheduleSync();
    renderCanvas();
    renderParts();
    setStatus("Заглушка обновлена");
  };
  body.querySelectorAll("[data-appearance-field]").forEach(input => {
    const apply = recordUndo => {
      const key = input.dataset.appearanceField;
      if (input.value.trim() === "") return;
      const value = Number(input.value);
      if (!Number.isFinite(value)) return;
      if (key === "objectWidth") state.objectSize.x = Math.max(1,Math.min(8192,value));
      if (key === "objectHeight") state.objectSize.y = Math.max(1,Math.min(8192,value));
      if (key === "spriteWidth" && textureSize.x) state.sprite.scale.x = Math.max(0.05,Math.min(16,value / textureSize.x));
      if (key === "spriteHeight" && textureSize.y) state.sprite.scale.y = Math.max(0.05,Math.min(16,value / textureSize.y));
      if (key === "scaleX") state.sprite.scale.x = Math.max(0.05,Math.min(16,value));
      if (key === "scaleY") state.sprite.scale.y = Math.max(0.05,Math.min(16,value));
      if (key === "offsetX") state.sprite.offset.x = Math.max(-8192,Math.min(8192,value));
      if (key === "offsetY") state.sprite.offset.y = Math.max(-8192,Math.min(8192,value));
      if (key === "zIndex") state.sprite.zIndex = Math.max(-4096,Math.min(4096,Math.floor(value)));
      const spriteWidthField = body.querySelector('[data-appearance-field="spriteWidth"]');
      const spriteHeightField = body.querySelector('[data-appearance-field="spriteHeight"]');
      const scaleXField = body.querySelector('[data-appearance-field="scaleX"]');
      const scaleYField = body.querySelector('[data-appearance-field="scaleY"]');
      if (textureSize.x) {
        if (spriteWidthField) spriteWidthField.value = String(Math.round(textureSize.x * state.sprite.scale.x));
        if (scaleXField) scaleXField.value = state.sprite.scale.x.toFixed(2);
      }
      if (textureSize.y) {
        if (spriteHeightField) spriteHeightField.value = String(Math.round(textureSize.y * state.sprite.scale.y));
        if (scaleYField) scaleYField.value = state.sprite.scale.y.toFixed(2);
      }
      state.saved = false;
      scheduleSync();
      renderCanvas();
      setStatus("Размеры и внешний вид изменены");
      if (recordUndo) captureUndo();
    };
    input.addEventListener("input",() => apply(false));
    input.addEventListener("change",() => apply(true));
  });
}

function ensureSpriteEditorWorkspace() {
  if ($("spriteEditorWorkspace")) return;
  const panel = document.querySelector(".canvas-panel");
  const tabs = $("editorObjectTabs");
  if (!panel || !tabs) return;
  tabs.insertAdjacentHTML("afterend",
    '<section id="spriteEditorWorkspace" class="sprite-editor-workspace hidden" aria-label="Редактор спрайтов">' +
      '<header class="sprite-editor-inline-head"><div><span class="eyebrow">PIXEL ART / CANVAS</span><b>Редактор спрайтов</b><small>Рабочая область объекта · спрайты, слои и коллизия</small></div><span class="sprite-editor-always-on">РЕДАКТОР ОБЪЕКТА</span></header>' +
      '<div class="sprite-editor-layout">' +
        '<aside class="sprite-tools" aria-label="Инструменты">' +
          '<button class="sprite-tool active" type="button" data-sprite-tool="select" title="Выделение">↖</button>' +
          '<button class="sprite-tool" type="button" data-sprite-tool="move" title="Перемещение">✥</button>' +
          '<button class="sprite-tool" type="button" data-sprite-tool="scale" title="Масштабирование · Alt — от центра">⤢</button>' +
          '<button class="sprite-tool" type="button" data-sprite-tool="rotate" title="Поворот">↻</button>' +
          '<button class="sprite-tool" type="button" data-sprite-tool="collision" title="Коллизия">▱</button>' +
        '</aside>' +
        '<section class="sprite-editor-main">' +
          '<div class="sprite-editor-toolbar"><button class="btn primary" type="button" id="spriteLayerPick">＋ Добавить спрайт</button><input type="file" id="spriteLayerFiles" accept="image/png,image/jpeg,image/webp" multiple hidden>' +
            '<button class="btn" type="button" id="spriteLayerFront">На передний план</button><button class="btn" type="button" id="spriteLayerBack">На задний план</button><button class="btn danger" type="button" id="spriteLayerRemove">Удалить слой</button>' +
            '<label>Масштаб <input type="range" id="spriteEditorZoom" min="0.5" max="3" step="0.05" value="1"></label><span id="spriteEditorZoomLabel">100%</span>' +
            '<label class="sprite-grid-control"><input type="checkbox" id="spriteGridVisible" checked> Сетка</label>' +
            '<label class="sprite-grid-control"><input type="checkbox" id="spriteGridSnap" checked> Привязка</label>' +
            '<label class="sprite-grid-control">Шаг <select id="spriteGridStep"><option value="1">1</option><option value="2">2</option><option value="4">4</option><option value="8">8</option><option value="16" selected>16</option><option value="32">32</option><option value="64">64</option></select> px</label>' +
            '<span class="sprite-rotation-snap-label" title="Шаг привязки угла при повороте">Поворот: 1°</span>' +
            '<span class="sprite-sheet-dimensions" id="spriteSheetDimensions">Пустой холст</span></div>' +
          '<div class="sprite-editor-ruler-grid"><div class="sprite-ruler-corner">px</div><canvas id="spriteRulerTop" class="sprite-ruler-top"></canvas>' +
            '<canvas id="spriteRulerLeft" class="sprite-ruler-left"></canvas><div class="sprite-editor-scroll"><canvas id="spriteSheetCanvas" class="sprite-sheet-canvas"></canvas></div></div>' +
          '<div class="sprite-editor-footer"><span id="spriteCanvasStatus">Выбери слой или добавь новый спрайт.</span><span>ЛКМ — действие · начало координат в центре</span></div>' +
        '</section>' +
        '<aside class="sprite-layer-panel"><div class="sprite-panel-heading">СЛОИ <span id="spriteLayerCount">0</span></div><div id="spriteLayerList" class="sprite-layer-list"></div>' +
          '<div class="sprite-panel-heading">ТРАНСФОРМАЦИЯ</div><div id="spriteLayerProperties" class="sprite-layer-properties"><div class="empty compact-empty">Выбери слой.</div></div>' +
          '<div class="sprite-panel-heading">КОЛЛИЗИЯ</div><div id="spriteCollisionProperties" class="sprite-collision-properties"></div></aside>' +
      '</div></section>');
  $("spriteLayerPick").onclick = () => $("spriteLayerFiles").click();
  $("spriteLayerFiles").onchange = async event => {
    await addSpriteLayerFiles([...event.target.files || []]);
    event.target.value = "";
  };
  $("spriteLayerRemove").onclick = removeSelectedSpriteLayer;
  $("spriteLayerFront").onclick = bringSelectedSpriteLayerForward;
  $("spriteLayerBack").onclick = sendSelectedSpriteLayerBackward;
  $("spriteEditorZoom").oninput = () => {
    spriteEditorZoomFactor = Number($("spriteEditorZoom").value) || 1;
    fitSpriteCanvas();
  };
  $("spriteGridVisible").onchange = event => {
    spriteGridVisible = event.target.checked;
    drawSpriteSheet();
  };
  $("spriteGridSnap").onchange = event => {
    spriteGridSnapEnabled = event.target.checked;
  };
  $("spriteGridStep").onchange = event => {
    spriteGridStep = Math.max(1, Math.min(64, Number(event.target.value) || 16));
    drawSpriteSheet();
  };
  $("spriteEditorWorkspace").querySelectorAll("[data-sprite-tool]").forEach(button => button.onclick = () => {
    spriteEditorTool = button.dataset.spriteTool;
    $("spriteEditorWorkspace").querySelectorAll("[data-sprite-tool]").forEach(item => item.classList.toggle("active",item === button));
    drawSpriteSheet();
  });
  const scroll = $("spriteEditorWorkspace").querySelector(".sprite-editor-scroll");
  scroll.addEventListener("scroll",() => {
    $("spriteRulerTop").style.transform = "translateX(" + (-scroll.scrollLeft) + "px)";
    $("spriteRulerLeft").style.transform = "translateY(" + (-scroll.scrollTop) + "px)";
  });
  const canvas = $("spriteSheetCanvas");
  canvas.addEventListener("pointerdown",onSpriteCanvasPointerDown);
  canvas.addEventListener("pointermove",onSpriteCanvasPointerMove);
  canvas.addEventListener("pointerup",finishSpriteCanvasDrag);
  canvas.addEventListener("pointercancel",finishSpriteCanvasDrag);
  if (typeof ResizeObserver !== "undefined") {
    if (spriteEditorResizeObserver) spriteEditorResizeObserver.disconnect();
    spriteEditorResizeObserver = new ResizeObserver(() => {
      if (!$("spriteEditorWorkspace")?.classList.contains("hidden")) fitSpriteCanvas();
    });
    spriteEditorResizeObserver.observe(scroll);
  }
}
let spriteCanvasZoom = 0.8;
let spriteEditorZoomFactor = 1;
let spriteEditorResizeObserver = null;
let spriteEditorTool = "move";
let spriteGridVisible = true;
let spriteGridSnapEnabled = true;
let spriteGridStep = 16;
let selectedSpriteLayerId = "";
let spriteCanvasDrag = null;
let spriteLayerDragId = "";
const SPRITE_ROTATION_SNAP_STEP = 1;
const spriteLayerImageCache = new Map();
const SPRITE_STAGE_WIDTH = 1400;
const SPRITE_STAGE_HEIGHT = 1000;
function fitSpriteCanvas() {
  const scroll = $("spriteEditorWorkspace")?.querySelector(".sprite-editor-scroll");
  if (!scroll || !state) return;
  const availableWidth = Math.max(80,scroll.clientWidth - 16);
  const availableHeight = Math.max(80,scroll.clientHeight - 16);
  let minX = -SPRITE_STAGE_WIDTH / 2, maxX = SPRITE_STAGE_WIDTH / 2;
  let minY = -SPRITE_STAGE_HEIGHT / 2, maxY = SPRITE_STAGE_HEIGHT / 2;
  let foundSprite = false;
  for (const layer of getSpriteLayerData()) {
    if (layer.visible === false) continue;
    const image = loadSpriteLayerImage(layer);
    if (!image) continue;
    const bounds = spriteLayerBounds(layer,image);
    minX = foundSprite ? Math.min(minX,bounds.x-bounds.w/2) : bounds.x-bounds.w/2;
    maxX = foundSprite ? Math.max(maxX,bounds.x+bounds.w/2) : bounds.x+bounds.w/2;
    minY = foundSprite ? Math.min(minY,bounds.y-bounds.h/2) : bounds.y-bounds.h/2;
    maxY = foundSprite ? Math.max(maxY,bounds.y+bounds.h/2) : bounds.y+bounds.h/2;
    foundSprite = true;
  }
  if (state.collision?.enabled) {
    const collision = state.collision;
    const halfWidth = collision.shape === "circle" ? collision.radius : (collision.size?.x || 32) / 2;
    const halfHeight = collision.shape === "circle" ? collision.radius : (collision.size?.y || 32) / 2;
    minX = foundSprite ? Math.min(minX,collision.offset.x-halfWidth) : collision.offset.x-halfWidth;
    maxX = foundSprite ? Math.max(maxX,collision.offset.x+halfWidth) : collision.offset.x+halfWidth;
    minY = foundSprite ? Math.min(minY,collision.offset.y-halfHeight) : collision.offset.y-halfHeight;
    maxY = foundSprite ? Math.max(maxY,collision.offset.y+halfHeight) : collision.offset.y+halfHeight;
    foundSprite = true;
  }
  if (!foundSprite) {
    minX=-SPRITE_STAGE_WIDTH/2;maxX=SPRITE_STAGE_WIDTH/2;
    minY=-SPRITE_STAGE_HEIGHT/2;maxY=SPRITE_STAGE_HEIGHT/2;
  }
  const contentWidth=Math.max(1,maxX-minX),contentHeight=Math.max(1,maxY-minY);
  const paddingX=Math.max(24,contentWidth*.14),paddingY=Math.max(24,contentHeight*.14);
  spriteCanvasViewCenter={x:(minX+maxX)/2,y:(minY+maxY)/2};
  const fit=Math.min(availableWidth/(contentWidth+paddingX*2),availableHeight/(contentHeight+paddingY*2),16);
  spriteCanvasZoom=Math.max(.05,Math.min(16,fit*spriteEditorZoomFactor));
  drawSpriteSheet();
}

function reorderSpriteLayers(sourceId,targetId) {
  if (!state || !sourceId || !targetId || sourceId === targetId) return;
  const ordered = [...getSpriteLayerData()].sort((a,b) => (Number(b.zIndex) || 0) - (Number(a.zIndex) || 0));
  const from = ordered.findIndex(layer => layer.id === sourceId);
  const to = ordered.findIndex(layer => layer.id === targetId);
  if (from < 0 || to < 0) return;
  captureUndo();
  const [moved] = ordered.splice(from,1);
  ordered.splice(to,0,moved);
  ordered.forEach((layer,index) => {
    const nextZ = ordered.length - index - 1;
    layer.zIndex = nextZ;
    if (layer.primary) state.sprite.zIndex = nextZ;
    else {
      const stored = state.spriteLayers.find(item => item.id === layer.id);
      if (stored) stored.zIndex = nextZ;
    }
  });
  state.saved = false;
  scheduleSync();
  renderSpriteEditor();
  drawSpriteSheet();
}
function getSpriteLayerData() {
  if (!state) return [];
  if (!Array.isArray(state.spriteLayers)) state.spriteLayers = [];
  const layers = [];
  if (state.previewDataUrl) {
    layers.push({
      id:"primary",name:"Основной спрайт",textureHash:state.previewHash || "",
      textureDataUrl:state.previewDataUrl,
      textureSize:{x:state.sprite.textureSize.x,y:state.sprite.textureSize.y},
      position:{x:state.sprite.offset.x,y:state.sprite.offset.y},
      scale:{x:state.sprite.scale.x,y:state.sprite.scale.y},
      rotation:state.sprite.rotation || 0,zIndex:state.sprite.zIndex || 0,visible:true,primary:true,
      runtimeVisible:true,embeddedRelationId:"",embeddedObjectId:"",embeddedSourceName:""
    });
  }
  layers.push(...state.spriteLayers);
  return layers;
}
function getSelectedSpriteLayer() {
  return getSpriteLayerData().find(layer => layer.id === selectedSpriteLayerId) || null;
}
function applySpriteLayerTransform(layer) {
  if (!layer || !state) return;
  if (layer.primary) {
    state.sprite.offset = {...layer.position};
    state.sprite.scale = {...layer.scale};
    state.sprite.rotation = Number(layer.rotation) || 0;
    state.sprite.zIndex = Number(layer.zIndex) || 0;
  } else {
    const target = state.spriteLayers.find(item => item.id === layer.id);
    if (target) {
      target.name = String(layer.name || target.name || "Спрайт");
      target.position = {...layer.position};
      target.scale = {...layer.scale};
      target.rotation = Number(layer.rotation) || 0;
      target.zIndex = Number(layer.zIndex) || 0;
      target.visible = layer.visible !== false;
    }
  }
  state.saved = false;
  scheduleSync();
}
function loadSpriteLayerImage(layer) {
  const source = layer?.textureDataUrl || "";
  if (!source) return null;
  const cached = spriteLayerImageCache.get(source);
  if (cached) return cached.complete && cached.naturalWidth ? cached : null;
  const image = new Image();
  spriteLayerImageCache.set(source,image);
  image.onload = () => {
    if (layer.textureSize) {
      layer.textureSize.x = image.naturalWidth;
      layer.textureSize.y = image.naturalHeight;
    }
    drawSpriteSheet();
    if (!$("spriteEditorWorkspace")?.classList.contains("hidden")) fitSpriteCanvas();
  };
  image.onerror = () => {
    spriteLayerImageCache.delete(source);
    toast("Не удалось загрузить спрайт «" + (layer.name || "без названия") + "».",true);
  };
  image.src = source;
  return null;
}
function ensureSpriteLayerDefaults() {
  if (!state) return;
  if (!Array.isArray(state.spriteLayers)) state.spriteLayers = [];
  if (!selectedSpriteLayerId) selectedSpriteLayerId = getSpriteLayerData()[0]?.id || "";
  if (selectedSpriteLayerId && !getSpriteLayerData().some(layer => layer.id === selectedSpriteLayerId)) selectedSpriteLayerId = "";
}
function openSpriteEditor() {
  if (!state) return;
  ensureSpriteEditorWorkspace();
  ensureSpriteLayerDefaults();
  $("canvas")?.classList.add("hidden");
  document.querySelector(".canvas-foot")?.classList.add("hidden");
  $("spriteEditorWorkspace").classList.remove("hidden");
  $("spriteEditorWorkspace").querySelectorAll("[data-sprite-tool]").forEach(button => button.classList.toggle("active",button.dataset.spriteTool === spriteEditorTool));
  renderSpriteEditor();
  requestAnimationFrame(fitSpriteCanvas);
}
function renderSpriteEditor() {
  if (!$("spriteEditorWorkspace") || !state) return;
  const layers = getSpriteLayerData();
  if (!layers.some(layer => layer.id === selectedSpriteLayerId)) selectedSpriteLayerId = layers[0]?.id || "";
  $("spriteLayerCount").textContent = String(layers.length);
  const displayLayers = [...layers].sort((a,b) => (Number(b.zIndex) || 0) - (Number(a.zIndex) || 0));
  $("spriteLayerList").innerHTML = displayLayers.map((layer,index) =>
    '<div class="sprite-layer-row ' + (layer.id === selectedSpriteLayerId ? "active" : "") + '" data-sprite-layer-row="' + esc(layer.id) + '" draggable="true">' +
      '<button type="button" class="sprite-layer-select" data-sprite-layer="' + esc(layer.id) + '" title="Выбрать слой">' +
        '<span class="sprite-layer-drag-handle" aria-hidden="true">⠿</span><span class="sprite-layer-thumb">▧</span>' +
        '<span class="sprite-layer-copy"><b>' + esc(layer.name || ("Спрайт " + (index + 1))) + '</b><small>Z ' + (Number(layer.zIndex) || 0) +
        " · " + (layer.primary ? "Основной" : (layer.textureSize?.x || "?") + " × " + (layer.textureSize?.y || "?") + " px") +
        (layer.embeddedRelationId ? " · Встроенная часть" : "") + '</small></span></button>' +
      '<button type="button" class="sprite-layer-visibility" data-sprite-visibility="' + esc(layer.id) + '" ' + (layer.primary ? "disabled" : "") +
      ' title="' + (layer.primary ? "Основной спрайт" : (layer.visible === false ? "Показать в редакторе" : "Скрыть в редакторе")) + '">' +
      (layer.visible === false ? "◌" : "●") + '</button></div>'
  ).join("") || '<div class="empty compact-empty">Нет спрайтов. Нажми «Добавить спрайт».</div>';
  const layerList = $("spriteLayerList");
  layerList.querySelectorAll("[data-sprite-layer]").forEach(button => button.onclick = () => {
    selectedSpriteLayerId = button.dataset.spriteLayer;
    renderSpriteEditor();
    drawSpriteSheet();
  });
  layerList.querySelectorAll("[data-sprite-visibility]").forEach(button => button.onclick = event => {
    event.stopPropagation();
    const layer = getSpriteLayerData().find(item => item.id === button.dataset.spriteVisibility);
    if (!layer || layer.primary) return;
    captureUndo();
    layer.visible = layer.visible === false;
    applySpriteLayerTransform(layer);
    renderSpriteEditor();
    drawSpriteSheet();
  });
  layerList.querySelectorAll("[data-sprite-layer-row]").forEach(row => {
    row.addEventListener("dragstart",event => {
      spriteLayerDragId = row.dataset.spriteLayerRow || "";
      event.dataTransfer.effectAllowed = "move";
      event.dataTransfer.setData("text/plain",spriteLayerDragId);
      row.classList.add("dragging");
    });
    row.addEventListener("dragover",event => {
      event.preventDefault();
      row.classList.add("drop-target");
      event.dataTransfer.dropEffect = "move";
    });
    row.addEventListener("dragleave",() => row.classList.remove("drop-target"));
    row.addEventListener("drop",event => {
      event.preventDefault();
      row.classList.remove("drop-target");
      const sourceId = event.dataTransfer.getData("text/plain") || spriteLayerDragId;
      reorderSpriteLayers(sourceId,row.dataset.spriteLayerRow || "");
    });
    row.addEventListener("dragend",() => {
      spriteLayerDragId = "";
      layerList.querySelectorAll(".dragging,.drop-target").forEach(item => item.classList.remove("dragging","drop-target"));
    });
  });
  const selected = getSelectedSpriteLayer();
  $("spriteLayerFront").disabled = !selected || selected.primary;
  $("spriteLayerBack").disabled = !selected || selected.primary;
  const p = selected?.position || {x:0,y:0}, s = selected?.scale || {x:1,y:1};
  $("spriteLayerProperties").innerHTML = selected ? (
    '<label class="sprite-layer-name-field">Название слоя<input type="text" maxlength="80" data-sprite-prop="name" value="' + esc(selected.name || "") + '" ' + (selected.primary ? "disabled" : "") + '></label>' +
    (selected.embeddedRelationId ? '<p class="sprite-panel-hint embedded-layer-note">Часть объекта «' + esc(selected.embeddedSourceName || "связанный объект") + '». В игре скрыта до срабатывания механики.</p>' : '') +
    '<div class="sprite-prop-grid"><label>Позиция X<input type="number" step="1" data-sprite-prop="x" value="' + Number(p.x || 0) + '"></label>' +
    '<label>Позиция Y<input type="number" step="1" data-sprite-prop="y" value="' + Number(p.y || 0) + '"></label>' +
    '<label>Масштаб X<input type="number" min="0.05" max="16" step="0.05" data-sprite-prop="scaleX" value="' + Number(s.x || 1) + '"></label>' +
    '<label>Масштаб Y<input type="number" min="0.05" max="16" step="0.05" data-sprite-prop="scaleY" value="' + Number(s.y || 1) + '"></label>' +
    '<label>Поворот °<input type="number" step="1" data-sprite-prop="rotation" value="' + Number(selected.rotation || 0) + '"></label>' +
    '<label>Z-index<input type="number" step="1" min="-4096" max="4096" data-sprite-prop="zIndex" value="' + Number(selected.zIndex || 0) + '"></label></div>' +
    '<label class="sprite-prop-check"><input type="checkbox" data-sprite-prop="visible" ' + (selected.visible === false ? "" : "checked") + '> Показывать в редакторе' + (selected.embeddedRelationId ? ' (в игре скрыт)' : '') + '</label>'
  ) : '<div class="empty compact-empty">Выбери слой.</div>';
  $("spriteLayerProperties").querySelectorAll("[data-sprite-prop]").forEach(input => input.addEventListener("change",() => {
    const layer = getSelectedSpriteLayer();
    if (!layer) return;
    captureUndo();
    const key = input.dataset.spriteProp;
    if (key === "name") {
      if (!layer.primary) layer.name = String(input.value || "Спрайт").trim().slice(0,80) || "Спрайт";
    } else if (key === "visible") layer.visible = input.checked;
    else if (key === "x" || key === "y") layer.position[key] = Math.max(-8192,Math.min(8192,spriteGridSnapValue(Number(input.value) || 0)));
    else if (key === "scaleX") layer.scale.x = Math.max(0.05,Math.min(16,Number(input.value) || 1));
    else if (key === "scaleY") layer.scale.y = Math.max(0.05,Math.min(16,Number(input.value) || 1));
    else if (key === "rotation") layer.rotation = Number(input.value) || 0;
    else if (key === "zIndex") layer.zIndex = Math.max(-4096,Math.min(4096,Math.trunc(Number(input.value) || 0)));
    applySpriteLayerTransform(layer);
    renderSpriteEditor();
  }));
  const col = state.collision;
  const options = ["rectangle","circle","capsule"].map(shape =>
    '<option value="' + shape + '" ' + (col.shape === shape ? "selected" : "") + '>' + ({rectangle:"Прямоугольник",circle:"Круг",capsule:"Капсула"})[shape] + '</option>'
  ).join("");
  const modeOptions = [
    {value:"solid",label:"Твёрдая — блокирует движение"},
    {value:"area",label:"Область — обнаруживает пересечение"}
  ].map(option => '<option value="' + option.value + '" ' + (col.mode === option.value ? "selected" : "") + '>' + option.label + '</option>').join("");
  $("spriteCollisionProperties").innerHTML =
    '<label class="sprite-prop-check"><input type="checkbox" data-collision-prop="enabled" ' + (col.enabled ? "checked" : "") + '> Включить коллизию</label>' +
    '<label>Режим<select data-collision-prop="mode">' + modeOptions + '</select></label>' +
    '<label>Форма<select data-collision-prop="shape">' + options + '</select></label>' +
    '<div class="sprite-prop-grid"><label>Ширина<input type="number" min="1" max="8192" data-collision-prop="width" value="' + Number(col.size.x || 32) + '"></label>' +
    '<label>Высота<input type="number" min="1" max="8192" data-collision-prop="height" value="' + Number(col.shape === "capsule" ? col.height : (col.size.y || 32)) + '"></label>' +
    '<label>Радиус<input type="number" min="1" max="4096" data-collision-prop="radius" value="' + Number(col.radius || 16) + '"></label>' +
    '<label>Смещение X<input type="number" data-collision-prop="offsetX" value="' + Number(col.offset.x || 0) + '"></label>' +
    '<label>Смещение Y<input type="number" data-collision-prop="offsetY" value="' + Number(col.offset.y || 0) + '"></label>' +
    '<label>Физический слой<input type="number" min="0" max="4294967295" step="1" data-collision-prop="layer" value="' + Number(col.layer) + '"></label>' +
    '<label>Маска обнаружения<input type="number" min="0" max="4294967295" step="1" data-collision-prop="mask" value="' + Number(col.mask) + '"></label></div>' +
    '<p class="sprite-panel-hint">Твёрдое тело блокирует движение. Область только обнаруживает пересечение. Слой 2 — препятствия, маска 1 — игрок.</p>';
  $("spriteCollisionProperties").querySelectorAll("[data-collision-prop]").forEach(input => input.addEventListener("change",() => {
    captureUndo();
    const key=input.dataset.collisionProp,collision=state.collision;
    if(key==="enabled")collision.enabled=input.checked;
    else if(key==="mode")collision.mode=input.value === "area" ? "area" : "solid";
    else if(key==="shape")collision.shape=input.value;
    else if(key==="width")collision.size.x=Math.max(1,Math.min(8192,spriteGridSnapLength(Number(input.value)||32)));
    else if(key==="height"){const value=Math.max(1,Math.min(8192,spriteGridSnapLength(Number(input.value)||32)));if(collision.shape==="capsule")collision.height=value;else collision.size.y=value;}
    else if(key==="radius")collision.radius=Math.max(1,Math.min(4096,spriteGridSnapLength(Number(input.value)||16)));
    else if(key==="offsetX")collision.offset.x=Math.max(-8192,Math.min(8192,spriteGridSnapValue(Number(input.value)||0)));
    else if(key==="offsetY")collision.offset.y=Math.max(-8192,Math.min(8192,spriteGridSnapValue(Number(input.value)||0)));
    else if(key==="layer")collision.layer=Math.max(0,Math.min(4294967295,Math.trunc(Number(input.value)||0)));
    else if(key==="mask")collision.mask=Math.max(0,Math.min(4294967295,Math.trunc(Number(input.value)||0)));
    state.saved=false;scheduleSync();renderSpriteEditor();
  }));
  drawSpriteSheet();
}
async function addSpriteLayerFiles(files) {
  if (!state) return;
  const accepted=files.filter(file=>{
    const ext=file.name.split(".").pop().toLowerCase();
    const mime=file.type||({png:"image/png",jpg:"image/jpeg",jpeg:"image/jpeg",webp:"image/webp"})[ext]||"";
    if(!["image/png","image/jpeg","image/jpg","image/webp"].includes(mime)){toast("Пропущен неподдерживаемый файл: "+file.name,true);return false;}
    if(file.size>5*1024*1024){toast("Файл больше 5 МБ: "+file.name,true);return false;}
    return true;
  });
  if((state.spriteLayers?.length||0)+accepted.length>24)return toast("В объекте может быть не больше 24 дополнительных спрайтов.",true);
  for(const file of accepted){
    const dataUrl=await new Promise((resolve,reject)=>{
      const reader=new FileReader();reader.onload=()=>resolve(String(reader.result||""));reader.onerror=()=>reject(new Error("Не удалось прочитать "+file.name));reader.readAsDataURL(file);
    });
    const dimensions=await new Promise((resolve,reject)=>{
      const image=new Image();image.onload=()=>resolve({x:image.naturalWidth,y:image.naturalHeight});image.onerror=()=>reject(new Error("Не удалось открыть "+file.name));image.src=dataUrl;
    });
    captureUndo();
    const id="sprite_"+Date.now().toString(36)+"_"+Math.random().toString(36).slice(2,7);
    state.spriteLayers.push({id,name:file.name.replace(/\.[^.]+$/,""),textureHash:"",textureDataUrl:dataUrl,textureSize:dimensions,
      position:{x:0,y:0},scale:{x:1,y:1},rotation:0,zIndex:state.spriteLayers.length+1,visible:true});
    selectedSpriteLayerId=id;state.saved=false;scheduleSync();
  }
  renderSpriteEditor();toast(accepted.length?"Добавлено спрайтов: "+accepted.length:"Нет файлов для добавления.");
}
function removeSelectedSpriteLayer() {
  const layer=getSelectedSpriteLayer();if(!layer||!state)return;
  if(layer.primary){
    if(!window.confirm("Убрать основной спрайт объекта?"))return;
    captureUndo();state.previewDataUrl="";state.previewHash="";state.previewPath="";
    state.sprite.textureSize={x:0,y:0};
  }else{
    captureUndo();state.spriteLayers=state.spriteLayers.filter(item=>item.id!==layer.id);
  }
  selectedSpriteLayerId=getSpriteLayerData()[0]?.id||"";
  state.saved=false;scheduleSync();renderSpriteEditor();
}
function bringSelectedSpriteLayerForward() {
  const layer=getSelectedSpriteLayer();if(!layer||layer.primary||!state)return;
  captureUndo();layer.zIndex=Math.min(4096,Math.max(0,...state.spriteLayers.map(item=>Number(item.zIndex)||0))+1);
  applySpriteLayerTransform(layer);renderSpriteEditor();
}
function sendSelectedSpriteLayerBackward() {
  const layer=getSelectedSpriteLayer();if(!layer||layer.primary||!state)return;
  captureUndo();layer.zIndex=Math.max(-4096,Math.min(0,...state.spriteLayers.map(item=>Number(item.zIndex)||0))-1);
  applySpriteLayerTransform(layer);renderSpriteEditor();
}
let spriteCanvasViewCenter = {x:0,y:0};
function spriteCanvasPoint(event) {
  const rect=$("spriteSheetCanvas").getBoundingClientRect(),zoom=spriteCanvasZoom||.8;
  return {
    x:(event.clientX-rect.left-rect.width/2)/zoom+spriteCanvasViewCenter.x,
    y:(event.clientY-rect.top-rect.height/2)/zoom+spriteCanvasViewCenter.y
  };
}
function rotateSpriteVector(vector,degrees) {
  const angle=degrees*Math.PI/180,cos=Math.cos(angle),sin=Math.sin(angle);
  return {x:vector.x*cos-vector.y*sin,y:vector.x*sin+vector.y*cos};
}
function spriteLayerLocalPoint(point,layer) {
  const relative={x:point.x-(Number(layer.position?.x)||0),y:point.y-(Number(layer.position?.y)||0)};
  return rotateSpriteVector(relative,-(Number(layer.rotation)||0));
}
function spriteLayerBounds(layer,image) {
  const width=Math.max(1,image.naturalWidth*Math.abs(Number(layer.scale?.x)||1));
  const height=Math.max(1,image.naturalHeight*Math.abs(Number(layer.scale?.y)||1));
  const angle=(Number(layer.rotation)||0)*Math.PI/180;
  const rotatedWidth=Math.abs(width*Math.cos(angle))+Math.abs(height*Math.sin(angle));
  const rotatedHeight=Math.abs(width*Math.sin(angle))+Math.abs(height*Math.cos(angle));
  return {x:Number(layer.position?.x)||0,y:Number(layer.position?.y)||0,w:rotatedWidth,h:rotatedHeight};
}
function hitSpriteLayer(point,layer,image) {
  if(!image||layer.visible===false)return false;
  const local=spriteLayerLocalPoint(point,layer);
  const halfWidth=Math.max(1,image.naturalWidth*Math.abs(Number(layer.scale?.x)||1))/2;
  const halfHeight=Math.max(1,image.naturalHeight*Math.abs(Number(layer.scale?.y)||1))/2;
  return local.x>=-halfWidth&&local.x<=halfWidth&&local.y>=-halfHeight&&local.y<=halfHeight;
}
function spriteGridSnapValue(value,event=null) {
  if (!spriteGridSnapEnabled || event?.ctrlKey) return value;
  const step = Math.max(1, Number(spriteGridStep) || 16);
  return Math.round(value / step) * step;
}
function spriteGridSnapLength(value,event=null) {
  if (!spriteGridSnapEnabled || event?.ctrlKey) return Math.max(1, value);
  const step = Math.max(1, Number(spriteGridStep) || 16);
  return Math.max(step, Math.round(value / step) * step);
}
function spriteLayerHandleAnchor(handle,halfWidth,halfHeight) {
  return {
    x:handle.includes("e")?-halfWidth:(handle.includes("w")?halfWidth:0),
    y:handle.includes("s")?-halfHeight:(handle.includes("n")?halfHeight:0)
  };
}
function spriteLayerResizeHandleAt(point,layer,image) {
  if(!layer||!image||layer.visible===false)return "";
  const local=spriteLayerLocalPoint(point,layer);
  const halfWidth=image.naturalWidth*Math.abs(Number(layer.scale?.x)||1)/2;
  const halfHeight=image.naturalHeight*Math.abs(Number(layer.scale?.y)||1)/2;
  const tolerance=Math.max(5,10/Math.max(.05,spriteCanvasZoom||.8));
  const nearLeft=Math.abs(local.x+halfWidth)<=tolerance;
  const nearRight=Math.abs(local.x-halfWidth)<=tolerance;
  const nearTop=Math.abs(local.y+halfHeight)<=tolerance;
  const nearBottom=Math.abs(local.y-halfHeight)<=tolerance;
  const onHorizontal=local.x>=-halfWidth-tolerance&&local.x<=halfWidth+tolerance;
  const onVertical=local.y>=-halfHeight-tolerance&&local.y<=halfHeight+tolerance;
  if(nearLeft&&nearTop)return "nw";
  if(nearRight&&nearTop)return "ne";
  if(nearRight&&nearBottom)return "se";
  if(nearLeft&&nearBottom)return "sw";
  if(nearTop&&onHorizontal)return "n";
  if(nearBottom&&onHorizontal)return "s";
  if(nearLeft&&onVertical)return "w";
  if(nearRight&&onVertical)return "e";
  return "";
}
function spriteLayerRotateHandleAt(point,layer,image) {
  if(!layer||!image||layer.visible===false)return false;
  const local=spriteLayerLocalPoint(point,layer);
  const halfHeight=image.naturalHeight*Math.abs(Number(layer.scale?.y)||1)/2;
  const halfWidth=image.naturalWidth*Math.abs(Number(layer.scale?.x)||1)/2;
  const handleY=-halfHeight-Math.max(18,24/Math.max(.05,spriteCanvasZoom||.8));
  return Math.hypot(local.x,local.y-handleY)<=Math.max(7,12/Math.max(.05,spriteCanvasZoom||.8)) && Math.abs(local.x)<=halfWidth+10;
}
function startSpriteResizeDrag(point,layer,image,handle) {
  const width=image.naturalWidth*Math.abs(Number(layer.scale?.x)||1);
  const height=image.naturalHeight*Math.abs(Number(layer.scale?.y)||1);
  const anchorLocal=spriteLayerHandleAnchor(handle,width/2,height/2);
  const anchorOffset=rotateSpriteVector(anchorLocal,Number(layer.rotation)||0);
  const anchorWorld={x:Number(layer.position?.x||0)+anchorOffset.x,y:Number(layer.position?.y||0)+anchorOffset.y};
  captureUndo();
  spriteCanvasDrag={
    kind:"resize",start:point,position:{...layer.position},scale:{...layer.scale},rotation:Number(layer.rotation)||0,
    handle,anchorWorld,initialWidth:width,initialHeight:height,imageSize:{x:image.naturalWidth,y:image.naturalHeight}
  };
}
function nearestSpriteResizeHandle(point,layer,image) {
  const local=spriteLayerLocalPoint(point,layer);
  const halfWidth=image.naturalWidth*Math.abs(Number(layer.scale?.x)||1)/2;
  const halfHeight=image.naturalHeight*Math.abs(Number(layer.scale?.y)||1)/2;
  const horizontal=local.x<0?"w":"e",vertical=local.y<0?"n":"s";
  if(Math.abs(local.x/Math.max(1,halfWidth))>Math.abs(local.y/Math.max(1,halfHeight)))return horizontal;
  if(Math.abs(local.y/Math.max(1,halfHeight))>Math.abs(local.x/Math.max(1,halfWidth)))return vertical;
  return vertical+horizontal;
}
function onSpriteCanvasPointerDown(event) {
  if(event.button!==0||!state)return;
  const point=spriteCanvasPoint(event),collision=state.collision;
  if(spriteEditorTool==="collision"){
    if(!collision.enabled){captureUndo();collision.enabled=true;renderSpriteEditor();}else captureUndo();
    const cx=collision.offset.x,cy=collision.offset.y;
    const resize=collision.shape==="rectangle"&&Math.abs(point.x-(cx+collision.size.x/2))<12/spriteCanvasZoom&&Math.abs(point.y-(cy+collision.size.y/2))<12/spriteCanvasZoom;
    spriteCanvasDrag={kind:resize?"collision-size":"collision-move",start:point,offset:{...collision.offset},size:{...collision.size}};
  }else{
    const selected=getSelectedSpriteLayer();
    const selectedImage=selected?loadSpriteLayerImage(selected):null;
    const selectedHandle=selected&&selectedImage?spriteLayerResizeHandleAt(point,selected,selectedImage):"";
    const selectedRotate=selected&&selectedImage?spriteLayerRotateHandleAt(point,selected,selectedImage):false;
    if(selectedHandle&&selectedImage){
      startSpriteResizeDrag(point,selected,selectedImage,selectedHandle);
    }else if(selectedRotate&&selectedImage){
      captureUndo();
      spriteCanvasDrag={kind:"rotate",start:point,position:{...selected.position},scale:{...selected.scale},rotation:Number(selected.rotation)||0};
    }else{
      const layers=[...getSpriteLayerData()].sort((a,b)=>(Number(b.zIndex)||0)-(Number(a.zIndex)||0));let hit=null;
      for(const layer of layers){
        const image=loadSpriteLayerImage(layer);
        if(hitSpriteLayer(point,layer,image)){hit=layer;break;}
      }
      if(hit){
        selectedSpriteLayerId=hit.id;
        renderSpriteEditor();
        const image=loadSpriteLayerImage(hit);
        if(spriteEditorTool==="move"){
          captureUndo();
          spriteCanvasDrag={kind:"move",start:point,position:{...hit.position},scale:{...hit.scale},rotation:Number(hit.rotation)||0};
        }else if(spriteEditorTool==="scale"&&image){
          startSpriteResizeDrag(point,hit,image,nearestSpriteResizeHandle(point,hit,image));
        }else if(spriteEditorTool==="rotate"){
          captureUndo();
          spriteCanvasDrag={kind:"rotate",start:point,position:{...hit.position},scale:{...hit.scale},rotation:Number(hit.rotation)||0};
        }
      }else if(spriteEditorTool==="select"){selectedSpriteLayerId="";renderSpriteEditor();}
    }
  }
  $("spriteSheetCanvas").setPointerCapture?.(event.pointerId);drawSpriteSheet();
}
function onSpriteCanvasPointerMove(event) {
  if(!spriteCanvasDrag||!state){
    const canvas=$("spriteSheetCanvas");
    if(canvas&&state&&spriteEditorTool!=="collision"){
      const selected=getSelectedSpriteLayer(),image=selected?loadSpriteLayerImage(selected):null,point=spriteCanvasPoint(event);
      canvas.style.cursor=selected&&image&&spriteLayerResizeHandleAt(point,selected,image)?"nwse-resize":
        selected&&image&&spriteLayerRotateHandleAt(point,selected,image)?"grab":"crosshair";
    }
    return;
  }
  const point=spriteCanvasPoint(event),delta={x:point.x-spriteCanvasDrag.start.x,y:point.y-spriteCanvasDrag.start.y};
  if(spriteCanvasDrag.kind==="collision-move"){
    state.collision.offset={
      x:spriteGridSnapValue(spriteCanvasDrag.offset.x+delta.x,event),
      y:spriteGridSnapValue(spriteCanvasDrag.offset.y+delta.y,event)
    };
  }else if(spriteCanvasDrag.kind==="collision-size"){
    state.collision.size={
      x:Math.max(1,Math.min(8192,spriteGridSnapLength(spriteCanvasDrag.size.x+delta.x*2,event))),
      y:Math.max(1,Math.min(8192,spriteGridSnapLength(spriteCanvasDrag.size.y+delta.y*2,event)))
    };
  }else{
    const layer=getSelectedSpriteLayer();if(!layer)return;
    if(spriteCanvasDrag.kind==="move")layer.position={
      x:spriteGridSnapValue(spriteCanvasDrag.position.x+delta.x,event),
      y:spriteGridSnapValue(spriteCanvasDrag.position.y+delta.y,event)
    };
    else if(spriteCanvasDrag.kind==="resize"){
      const drag=spriteCanvasDrag,handle=drag.handle;
      const centered=event.altKey;
      const resizeOrigin=centered?drag.position:drag.anchorWorld;
      const relative=rotateSpriteVector({x:point.x-resizeOrigin.x,y:point.y-resizeOrigin.y},-drag.rotation);
      const changesWidth=handle.includes("e")||handle.includes("w");
      const changesHeight=handle.includes("n")||handle.includes("s");
      let width=changesWidth?Math.abs(relative.x)*(centered?2:1):drag.initialWidth;
      let height=changesHeight?Math.abs(relative.y)*(centered?2:1):drag.initialHeight;
      if(event.shiftKey){
        const factor=handle.length===2?Math.max(width/drag.initialWidth,height/drag.initialHeight):
          (changesWidth?width/drag.initialWidth:height/drag.initialHeight);
        let uniformFactor=Math.max(.05,factor);
        if(spriteGridSnapEnabled&&!event.ctrlKey){
          const base=Math.min(drag.initialWidth,drag.initialHeight);
          uniformFactor=spriteGridSnapLength(base*uniformFactor,event)/base;
        }
        width=drag.initialWidth*uniformFactor;
        height=drag.initialHeight*uniformFactor;
      }else{
        width=spriteGridSnapLength(width,event);
        height=spriteGridSnapLength(height,event);
      }
      width=Math.max(1,Math.min(8192,width));
      height=Math.max(1,Math.min(8192,height));
      layer.scale={
        x:Math.max(.05,Math.min(16,width/drag.imageSize.x)),
        y:Math.max(.05,Math.min(16,height/drag.imageSize.y))
      };
      if(centered){
        layer.position={...drag.position};
      }else{
        const nextAnchor=spriteLayerHandleAnchor(handle,width/2,height/2);
        const nextOffset=rotateSpriteVector(nextAnchor,drag.rotation);
        layer.position={x:drag.anchorWorld.x-nextOffset.x,y:drag.anchorWorld.y-nextOffset.y};
      }
    }else if(spriteCanvasDrag.kind==="rotate"){
      const center=spriteCanvasDrag.position;
      const a0=Math.atan2(spriteCanvasDrag.start.y-center.y,spriteCanvasDrag.start.x-center.x),a1=Math.atan2(point.y-center.y,point.x-center.x);
      const raw=spriteCanvasDrag.rotation+(a1-a0)*180/Math.PI;
      layer.rotation=event.ctrlKey?raw:Math.round(raw/SPRITE_ROTATION_SNAP_STEP)*SPRITE_ROTATION_SNAP_STEP;
    }
    applySpriteLayerTransform(layer);
  }
  state.saved=false;scheduleSync();drawSpriteSheet();
}
function finishSpriteCanvasDrag() {
  if(!spriteCanvasDrag)return;
  spriteCanvasDrag=null;
  const canvas=$("spriteSheetCanvas");
  if(canvas)canvas.style.cursor="crosshair";
  renderSpriteEditor();
}
function drawSpriteSheet() {
  const canvas=$("spriteSheetCanvas");if(!canvas||!state)return;
  const zoom=Math.max(.05,Math.min(16,Number(spriteCanvasZoom)||.3));spriteCanvasZoom=zoom;
  $("spriteEditorZoomLabel").textContent=Math.round(zoom*100)+"%";
  const scroll=$("spriteEditorWorkspace")?.querySelector(".sprite-editor-scroll");
  const width=Math.max(80,Math.round((scroll?.clientWidth||800)-16));
  const height=Math.max(80,Math.round((scroll?.clientHeight||560)-16));
  if(canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height;}
  canvas.style.width=width+"px";canvas.style.height=height+"px";
  const ctx=canvas.getContext("2d");ctx.clearRect(0,0,width,height);
  ctx.save();
  ctx.translate(width/2-spriteCanvasViewCenter.x*zoom,height/2-spriteCanvasViewCenter.y*zoom);
  ctx.scale(zoom,zoom);
  const viewMinX=spriteCanvasViewCenter.x-width/(2*zoom),viewMaxX=spriteCanvasViewCenter.x+width/(2*zoom);
  const viewMinY=spriteCanvasViewCenter.y-height/(2*zoom),viewMaxY=spriteCanvasViewCenter.y+height/(2*zoom);
  if(spriteGridVisible){
    const gridStep=Math.max(1,Number(spriteGridStep)||16);
    const screenStep=gridStep*zoom;
    const visibleStep=screenStep>=4?gridStep:gridStep*Math.ceil(4/screenStep);
    ctx.strokeStyle="rgba(155,177,194,.22)";ctx.lineWidth=1/zoom;
    for(let x=Math.floor(viewMinX/visibleStep)*visibleStep;x<=viewMaxX;x+=visibleStep){ctx.beginPath();ctx.moveTo(x,viewMinY);ctx.lineTo(x,viewMaxY);ctx.stroke();}
    for(let y=Math.floor(viewMinY/visibleStep)*visibleStep;y<=viewMaxY;y+=visibleStep){ctx.beginPath();ctx.moveTo(viewMinX,y);ctx.lineTo(viewMaxX,y);ctx.stroke();}
  }
  ctx.strokeStyle="rgba(224,193,135,.75)";ctx.beginPath();ctx.moveTo(viewMinX,0);ctx.lineTo(viewMaxX,0);ctx.moveTo(0,viewMinY);ctx.lineTo(0,viewMaxY);ctx.stroke();
  const layers=getSpriteLayerData();
  for(const layer of [...layers].sort((a,b)=>(Number(a.zIndex)||0)-(Number(b.zIndex)||0))){
    const image=loadSpriteLayerImage(layer);if(!image||layer.visible===false)continue;
    ctx.save();ctx.translate(Number(layer.position?.x)||0,Number(layer.position?.y)||0);ctx.rotate((Number(layer.rotation)||0)*Math.PI/180);
    ctx.scale(Number(layer.scale?.x)||1,Number(layer.scale?.y)||1);ctx.imageSmoothingEnabled=false;ctx.drawImage(image,-image.naturalWidth/2,-image.naturalHeight/2);
    if(layer.id===selectedSpriteLayerId){
      ctx.strokeStyle="#a7f36b";ctx.lineWidth=1/zoom;ctx.setLineDash([4/zoom,3/zoom]);
      ctx.strokeRect(-image.naturalWidth/2,-image.naturalHeight/2,image.naturalWidth,image.naturalHeight);ctx.setLineDash([]);
      const handleScale=Math.max(.05,Math.max(Math.abs(Number(layer.scale?.x)||1),Math.abs(Number(layer.scale?.y)||1)));
      const h=7/(zoom*handleScale);ctx.fillStyle="#a7f36b";
      const left=-image.naturalWidth/2,right=image.naturalWidth/2,top=-image.naturalHeight/2,bottom=image.naturalHeight/2;
      [[left,top],[0,top],[right,top],[right,0],[right,bottom],[0,bottom],[left,bottom],[left,0]].forEach(([x,y])=>ctx.fillRect(x-h/2,y-h/2,h,h));
      const rotateY=top-22/Math.max(.05,Math.abs(Number(layer.scale?.y)||1));
      ctx.strokeStyle="#a7f36b";ctx.lineWidth=1/zoom;ctx.beginPath();ctx.moveTo(0,top);ctx.lineTo(0,rotateY);ctx.stroke();
      ctx.beginPath();ctx.arc(0,rotateY,5/(zoom*handleScale),0,Math.PI*2);ctx.fill();
    }
    ctx.restore();
  }
  if(state.collision.enabled){
    const col=state.collision;ctx.save();ctx.translate(col.offset.x,col.offset.y);ctx.strokeStyle="#f08d75";ctx.fillStyle="rgba(240,141,117,.10)";ctx.lineWidth=2/zoom;ctx.setLineDash([5/zoom,3/zoom]);
    if(col.shape==="circle")ctx.arc(0,0,Number(col.radius)||16,0,Math.PI*2);
    else if(col.shape==="capsule"){const radius=Number(col.radius)||16,height=Math.max(radius*2,Number(col.height)||32);ctx.roundRect(-radius,-height/2,radius*2,height,radius);}
    else ctx.rect(-col.size.x/2,-col.size.y/2,col.size.x,col.size.y);
    ctx.fill();ctx.stroke();ctx.setLineDash([]);
    if(col.shape==="rectangle"){ctx.fillStyle="#f08d75";ctx.fillRect(col.size.x/2-4/zoom,col.size.y/2-4/zoom,8/zoom,8/zoom);}
    ctx.restore();
  }
  ctx.restore();
  $("spriteSheetDimensions").textContent=layers.length+" спрайт(ов) · "+SPRITE_STAGE_WIDTH+" × "+SPRITE_STAGE_HEIGHT+" px";
  $("spriteCanvasStatus").textContent=spriteEditorTool==="collision"?"Коллизия: перетаскивай контур или нижний правый маркер.":"Тяни слой — перемещение; 8 ручек — размер; Shift — пропорции; Alt — от центра; Ctrl — без привязки; поворот — 1°.";
  drawSpriteRulers();
}
function drawSpriteRulers() {
  const zoom=spriteCanvasZoom||.8,canvas=$("spriteSheetCanvas");
  const width=canvas?.width||800,height=canvas?.height||560;
  const top=$("spriteRulerTop"),left=$("spriteRulerLeft");
  top.width=width;top.height=26;top.style.width=width+"px";top.style.height="26px";
  left.width=26;left.height=height;left.style.width="26px";left.style.height=height+"px";
  const tx=top.getContext("2d");tx.fillStyle="#111923";tx.fillRect(0,0,width,26);tx.strokeStyle="#71869a";tx.fillStyle="#bdcbd7";tx.font="10px monospace";
  const minX=spriteCanvasViewCenter.x-width/(2*zoom),maxX=spriteCanvasViewCenter.x+width/(2*zoom);
  const minY=spriteCanvasViewCenter.y-height/(2*zoom),maxY=spriteCanvasViewCenter.y+height/(2*zoom);
  for(let value=Math.floor(minX/16)*16;value<=maxX;value+=16){const x=width/2+(value-spriteCanvasViewCenter.x)*zoom;const major=value%64===0;tx.beginPath();tx.moveTo(x+.5,26);tx.lineTo(x+.5,major?8:17);tx.stroke();if(major)tx.fillText(String(value),x+2,8);}
  const ly=left.getContext("2d");ly.fillStyle="#111923";ly.fillRect(0,0,26,height);ly.strokeStyle="#71869a";ly.fillStyle="#bdcbd7";ly.font="9px monospace";
  for(let value=Math.floor(minY/16)*16;value<=maxY;value+=16){const y=height/2+(value-spriteCanvasViewCenter.y)*zoom;const major=value%64===0;ly.beginPath();ly.moveTo(26,y+.5);ly.lineTo(major?8:17,y+.5);ly.stroke();if(major)ly.fillText(String(value),1,y+10);}
}
function getSpriteAnimationFormData() {
  const rows=Math.max(1,Math.min(256,Number($("spriteAnimationRows").value)||1));
  const columns=Math.max(1,Math.min(256,Number($("spriteAnimationColumns").value)||1));
  const row=Math.max(0,Math.min(rows-1,Number($("spriteAnimationRow").value)||0));
  const start_column=Math.max(0,Math.min(columns-1,Number($("spriteAnimationStart").value)||0));
  return {
    name:$("spriteAnimationName").value.trim() || "animation",
    rows,columns,row,start_column,
    frame_count:Math.max(1,Math.min(columns-start_column,Number($("spriteAnimationFrames").value)||1)),
    margin_x:Math.max(0,Math.min(8192,Number($("spriteAnimationMarginX").value)||0)),
    margin_y:Math.max(0,Math.min(8192,Number($("spriteAnimationMarginY").value)||0)),
    separation_x:Math.max(0,Math.min(8192,Number($("spriteAnimationSeparationX").value)||0)),
    separation_y:Math.max(0,Math.min(8192,Number($("spriteAnimationSeparationY").value)||0)),
    fps:Math.max(.1,Math.min(60,Number($("spriteAnimationFps").value)||8)),
    loop:$("spriteAnimationLoop").checked
  };
}
function saveSpriteAnimation() {
  if (!state?.spriteSheetDataUrl && !state?.previewDataUrl) return toast("Сначала загрузи spritesheet или спрайт.",true);
  const animation=getSpriteAnimationFormData();
  if (spriteEditorAnimationIndex >= 0 && state.spriteAnimations[spriteEditorAnimationIndex]) {
    const duplicate=state.spriteAnimations.some((item,index)=>index!==spriteEditorAnimationIndex && item.name.toLowerCase()===animation.name.toLowerCase());
    if (duplicate) return toast("Анимация с таким именем уже существует.",true);
    captureUndo();
    state.spriteAnimations[spriteEditorAnimationIndex]=animation;
  } else {
    if (state.spriteAnimations.some(item=>item.name.toLowerCase()===animation.name.toLowerCase())) return toast("Анимация с таким именем уже существует.",true);
    captureUndo();
    state.spriteAnimations.push(animation);
    spriteEditorAnimationIndex=state.spriteAnimations.length-1;
  }
  state.saved=false;
  scheduleSync();
  renderSpriteEditor();
  renderCanvas();
  toast("Настройки анимации сохранены в объекте.");
}
function removeSpriteAnimation() {
  if (spriteEditorAnimationIndex < 0 || !state?.spriteAnimations[spriteEditorAnimationIndex]) return;
  captureUndo();
  state.spriteAnimations.splice(spriteEditorAnimationIndex,1);
  spriteEditorAnimationIndex=-1;
  state.saved=false;
  scheduleSync();
  renderSpriteEditor();
  renderCanvas();
}
function drawSpriteAnimationPreview() {
  const canvas=$("spriteAnimationPreview");
  if(!canvas) return;
  const ctx=canvas.getContext("2d");
  ctx.clearRect(0,0,canvas.width,canvas.height);
  const dataUrl=state?.spriteSheetDataUrl || state?.previewDataUrl || "";
  const animation=state?.spriteAnimations?.[spriteEditorAnimationIndex] || getSpriteAnimationFormData();
  if(!dataUrl){ctx.fillStyle="#9aa8b5";ctx.font="12px sans-serif";ctx.fillText("Нет изображения",48,96);return;}
  const img=spriteEditorImage;
  if(!img || img.src!==dataUrl || !img.complete || !img.naturalWidth){const next=new Image();next.onload=()=>{spriteEditorImage=next;drawSpriteAnimationPreview();};next.src=dataUrl;return;}
  const rows = Math.max(1,animation.rows), columns = Math.max(1,animation.columns);
  const marginX = Math.max(0,Number(animation.margin_x)||0), marginY = Math.max(0,Number(animation.margin_y)||0);
  const separationX = Math.max(0,Number(animation.separation_x)||0), separationY = Math.max(0,Number(animation.separation_y)||0);
  const fw = (img.naturalWidth - marginX*2 - separationX*(columns-1)) / columns;
  const fh = (img.naturalHeight - marginY*2 - separationY*(rows-1)) / rows;
  if (fw <= 0 || fh <= 0) return;
  const frame=window._obSpriteFrame || 0;
  const col=animation.start_column+(frame%Math.max(1,animation.frame_count));
  const sx=marginX + col*(fw+separationX), sy=marginY + animation.row*(fh+separationY);
  const scale=Math.min((canvas.width-24)/fw,(canvas.height-24)/fh);
  ctx.imageSmoothingEnabled=false;
  ctx.drawImage(img,sx,sy,fw,fh,(canvas.width-fw*scale)/2,(canvas.height-fh*scale)/2,fw*scale,fh*scale);
}
function toggleSpriteAnimationPreview() {
  if(window._obSpritePreviewTimer){
    window.clearInterval(window._obSpritePreviewTimer);window._obSpritePreviewTimer=0;
    $("spriteAnimationPlay").textContent="▶ Воспроизвести";
    return;
  }
  const animation=state?.spriteAnimations?.[spriteEditorAnimationIndex] || getSpriteAnimationFormData();
  window._obSpriteFrame=0;
  $("spriteAnimationPlay").textContent="Ⅱ Остановить";
  drawSpriteAnimationPreview();
  window._obSpritePreviewTimer=window.setInterval(()=>{
    window._obSpriteFrame=(window._obSpriteFrame||0)+1;
    if(window._obSpriteFrame>=animation.frame_count){
      if(animation.loop) window._obSpriteFrame=0;
      else {
        window.clearInterval(window._obSpritePreviewTimer);
        window._obSpritePreviewTimer=0;
        $("spriteAnimationPlay").textContent="▶ Воспроизвести";
        return;
      }
    }
    drawSpriteAnimationPreview();
  },1000/Math.max(.1,animation.fps));
}

function renderCollisionBits(key,mask) {
  return '<div class="collision-layer-grid">' + Array.from({length:32},(_,index) => {
    const bit = 2 ** index;
    const checked = Math.floor((Number(mask) || 0) / bit) % 2 >= 1;
    const name = physicsLayers[index] || ("Слой " + (index + 1));
    return '<label><input type="checkbox" data-collision-bit="' + key + '" data-bit="' + bit + '" ' + (checked ? "checked" : "") + '><span>' +
      '<b>' + (index + 1) + '</b>' + esc(name) + '</span></label>';
  }).join("") + '</div>';
}

function renderCollisionInspector(body) {
  const c = state.collision;
  const sizeFields = c.shape === "rectangle"
    ? '<div class="field-grid"><div class="field"><label>Ширина, px</label><input type="number" min="1" max="8192" step="1" data-collision-field="width" value="' + c.size.x + '"></div>' +
      '<div class="field"><label>Высота, px</label><input type="number" min="1" max="8192" step="1" data-collision-field="height" value="' + c.size.y + '"></div></div>'
    : c.shape === "circle"
      ? '<div class="field"><label>Радиус, px</label><input type="number" min="1" max="4096" step="1" data-collision-field="radius" value="' + c.radius + '"></div>'
      : '<div class="field-grid"><div class="field"><label>Радиус, px</label><input type="number" min="1" max="4096" step="1" data-collision-field="radius" value="' + c.radius + '"></div>' +
        '<div class="field"><label>Высота капсулы, px</label><input type="number" min="2" max="8192" step="1" data-collision-field="height" value="' + c.height + '"></div></div>';
  body.innerHTML =
    '<section class="editor-section-card"><div class="editor-section-heading"><div><b>Физическая форма</b><small>Настраивается прямо здесь и отображается поверх предпросмотра</small></div>' +
    '<label class="switch-field"><input type="checkbox" data-collision-field="enabled" ' + (c.enabled ? "checked" : "") + '> Включена</label></div>' +
    '<div class="field"><label>Поведение</label><select data-collision-field="mode"><option value="solid" ' + (c.mode === "solid" ? "selected" : "") + '>Твёрдая — блокирует движение</option><option value="area" ' + (c.mode === "area" ? "selected" : "") + '>Область — обнаруживает пересечения</option></select></div>' +
    '<div class="field"><label>Форма</label><select data-collision-field="shape"><option value="rectangle" ' + (c.shape === "rectangle" ? "selected" : "") + '>Прямоугольник</option><option value="circle" ' + (c.shape === "circle" ? "selected" : "") + '>Круг</option><option value="capsule" ' + (c.shape === "capsule" ? "selected" : "") + '>Капсула</option></select></div>' +
    sizeFields +
    '<div class="mini-title">СМЕЩЕНИЕ ФОРМЫ</div><div class="field-grid"><div class="field"><label>X, px</label><input type="number" min="-8192" max="8192" step="1" data-collision-field="offsetX" value="' + c.offset.x + '"></div>' +
    '<div class="field"><label>Y, px</label><input type="number" min="-8192" max="8192" step="1" data-collision-field="offsetY" value="' + c.offset.y + '"></div></div>' +
    '<div class="collision-preview-hint">' + (c.enabled ? "Контур виден на центральном предпросмотре." : "Коллизия выключена. Включи её, чтобы увидеть контур.") + '</div></section>' +
    '<details class="editor-section-card advanced-collision"><summary>Слои и маски столкновений</summary>' +
    '<p class="detail-desc">Слой определяет, к каким группам принадлежит объект. Маска — какие группы он обнаруживает или блокирует.</p>' +
    '<div class="collision-bit-group"><b>Слой объекта</b><small>Группы, к которым принадлежит объект</small>' + renderCollisionBits("layer",c.layer) + '</div>' +
    '<div class="collision-bit-group"><b>Маска столкновений</b><small>Группы, с которыми объект взаимодействует</small>' + renderCollisionBits("mask",c.mask) + '</div></details>' +
    '<p class="detail-desc">Форма создаётся как управляемый узел StaticBody2D или Area2D в сцене объекта. Пользовательские узлы и их коллизии не удаляются и не перезаписываются.</p>';
  body.querySelectorAll("[data-collision-bit]").forEach(input => input.addEventListener("change",() => {
    const key = input.dataset.collisionBit;
    const bit = Number(input.dataset.bit) >>> 0;
    const current = Number(c[key]) >>> 0;
    c[key] = input.checked ? ((current | bit) >>> 0) : ((current & ~bit) >>> 0);
    state.saved = false;
    captureUndo();
    scheduleSync();
    setStatus("Слои столкновений изменены");
  }));
  body.querySelectorAll("[data-collision-field]").forEach(input => {
    const apply = recordUndo => {
      const key = input.dataset.collisionField;
      if (key === "enabled") c.enabled = input.checked;
      else if (key === "mode") c.mode = input.value === "area" ? "area" : "solid";
      else if (key === "shape") c.shape = ["rectangle","circle","capsule"].includes(input.value) ? input.value : "rectangle";
      else {
        if (input.value.trim() === "") return;
        const value = Number(input.value);
        if (!Number.isFinite(value)) return;
        if (key === "width") c.size.x = Math.max(1,Math.min(8192,value));
        if (key === "height" && c.shape === "rectangle") c.size.y = Math.max(1,Math.min(8192,value));
        if (key === "height" && c.shape === "capsule") c.height = Math.max(c.radius * 2,Math.min(8192,value));
        if (key === "radius") c.radius = Math.max(1,Math.min(4096,value));
        if (key === "capsuleHeight") c.height = Math.max(c.radius * 2,Math.min(8192,value));
        if (key === "offsetX") c.offset.x = Math.max(-8192,Math.min(8192,value));
        if (key === "offsetY") c.offset.y = Math.max(-8192,Math.min(8192,value));
        if (key === "layer") c.layer = Math.max(0,Math.min(4294967295,Math.floor(value)));
        if (key === "mask") c.mask = Math.max(0,Math.min(4294967295,Math.floor(value)));

      }
      state.saved = false;
      scheduleSync();
      renderCanvas();
      renderStats();
      setStatus("Параметры коллизии изменены");
      if (recordUndo) {
        captureUndo();
        if (key === "shape" || key === "enabled" || key === "mode") renderInspector();
      }
    };
    input.addEventListener("input",() => apply(false));
    input.addEventListener("change",() => apply(true));
  });
}

async function importSprite(file) {
  if (!file || !state) return;
  if (file.size > 5 * 1024 * 1024) return toast("Изображение больше 5 МБ.",true);
  const mime = file.type || ({png:"image/png",jpg:"image/jpeg",jpeg:"image/jpeg",webp:"image/webp"}[file.name.split(".").pop().toLowerCase()] || "");
  if (!["image/png","image/jpeg","image/jpg","image/webp"].includes(mime)) return toast("Поддерживаются PNG, JPEG и WebP.",true);
  try {
    const dataUrl = await new Promise((resolve,reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result || ""));
      reader.onerror = () => reject(new Error("Не удалось прочитать выбранное изображение."));
      reader.readAsDataURL(file);
    });
    await api("sprite_upload",{data_url:dataUrl});
    captureUndo();
    setStatus("Спрайт назначен · не забудь сохранить объект");
    toast("Спрайт добавлен в объект.");
  } catch (error) { toast(error.message,true); }
}
async function clearSprite() {
  if (!state?.previewDataUrl) return;
  try {
    await api("sprite_clear");
    captureUndo();
    setStatus("Спрайт удалён из объекта");
    toast("Спрайт убран. Файлы не затронуты.");
  } catch (error) { toast(error.message,true); }
}

function renderReadOnlyNodeProperties(part) {
  const properties = part?.properties && typeof part.properties === "object" ? part.properties : {};
  const keys = Object.keys(properties);
  if (!keys.length) return '<div class="detail-desc">Нет дополнительных свойств для отображения.</div>';
  return '<details class="editor-section-card" open><summary>Параметры из Godot <span class="count">' + keys.length + '</span></summary>' +
    '<pre class="detail-desc" style="white-space:pre-wrap;overflow-wrap:anywhere">' +
    esc(JSON.stringify(properties, null, 2)) + '</pre></details>';
}

function renderPartsInspector(body) {
  const part = state.parts.find(x => x.id === selectedPartId) || state.parts[0];
  const editableParts = state.parts.filter(x => x.id !== "root" && !x.external);
  const options = editableParts.filter(x => x.id !== (part?.id || "root")).map(x => ({value:x.id,label:x.name}));
  const treeMarkup = state.parts.map(item => {
    const parent = state.parts.find(x => x.id === item.parentId);
    const depth = item.id === "root" ? 0 : (parent?.id === "root" ? 1 : 2);
    const sourceLabel = item.external ? "Узел Godot" : (item.nodeType || item.kind || "root");
    return '<button type="button" class="left-part-tree-item ' + (selectedPartId === item.id ? "active" : "") +
      '" data-left-part="' + esc(item.id) + '" style="--part-depth:' + depth + '"><span>' + (depth ? "↳" : "◇") + ' ' + esc(item.name) +
      '</span><small>' + esc(sourceLabel) + '</small></button>';
  }).join("");
  const nameField = part
    ? '<div class="field"><label>Имя узла</label><input id="partName" value="' + esc(part.name) + '" ' +
      (part.id === "root" || part.external ? "disabled" : "") + '></div>'
    : "";
  let partDetails = '<div class="empty">Выбери узел.</div>';
  if (part) {
    if (part.external) {
      partDetails =
        '<div class="detail-desc">Этот узел создан или изменён непосредственно в сцене Godot. Он показывается здесь только для просмотра. Web Object Builder не будет перезаписывать его свойства, перемещать или удалять.</div>' +
        '<div class="property-row"><span>Источник</span><b>Godot</b></div>' +
        '<div class="property-row"><span>Путь узла</span><b>' + esc(part.nodePath || part.metadata?.nodePath || "") + '</b></div>' +
        renderReadOnlyNodeProperties(part);
    } else if (part.id === "root") {
      partDetails = '<div class="property-row"><span>Корневой тип меняется в разделе «Объект» справа.</span></div>' +
        renderReadOnlyNodeProperties(part);
    } else {
      partDetails =
        '<div class="field"><label>Родитель</label><select id="partParent"><option value="root">Корень объекта</option>' +
        options.map(x => '<option value="' + esc(x.value) + '" ' + (part.parentId === x.value ? "selected" : "") + '>' + esc(x.label) + '</option>').join("") + '</select></div>' +
        '<div class="field"><label>Тип узла</label><select id="partNodeType">' + NODE_TYPES.map(x => '<option value="' + x + '" ' + (part.nodeType === x ? "selected" : "") + '>' + x + '</option>').join("") + '</select></div>' +
        '<div class="field"><label>Состояние узла</label><label class="switch-field"><input id="partEnabled" type="checkbox" ' + (part.enabled === false ? "" : "checked") + '> Узел включён</label></div>' +
        '<details class="editor-section-card advanced-node-settings"><summary>Дополнительные свойства узла</summary><p class="detail-desc">Технические значения Godot в JSON. Основные параметры спрайта и коллизии настраиваются в соседних разделах слева.</p><textarea id="partProperties">' + esc(JSON.stringify(part.properties || {},null,2)) + '</textarea></details>' +
        '<button class="btn primary" id="partApply">Применить изменения</button><button class="btn danger" id="partRemove">Удалить узел</button>';
    }
  }
  body.innerHTML =
    '<div class="left-editor-section"><div class="mini-title">ДЕРЕВО УЗЛОВ <span class="count">' + state.parts.length + '</span></div>' +
    '<div class="left-part-tree">' + treeMarkup + '</div><button class="btn small" id="partAdd">＋ Добавить часть / узел</button></div>' +
    '<div class="mini-title">ПАРАМЕТРЫ ВЫБРАННОЙ ЧАСТИ</div>' +
    '<div class="detail-desc">Узлы одной сцены показаны вместе. Части, добавленные в Godot, отмечены как внешние и доступны только для просмотра.</div>' +
    '<div id="partDetails">' + (part ? nameField +
    '<div class="field"><label>Тип узла</label><input value="' + esc(part.nodeType || state.nativeRootType) + '" disabled></div>' +
    partDetails : partDetails) + '</div>';
  body.querySelectorAll("[data-left-part]").forEach(button => button.onclick = () => {
    selectedPartId = button.dataset.leftPart;
    renderLeftEditor();
    renderCanvas();
  });
  if (part && part.id !== "root" && !part.external) {
    $("partApply").onclick = async () => {
      let properties = {};
      try { properties = JSON.parse($("partProperties").value || "{}"); }
      catch (_error) { return toast("Свойства узла должны быть корректным JSON.", true); }
      await updatePart({
        id:part.id,name:$("partName").value,parent_id:$("partParent").value,
        node_type:$("partNodeType").value,enabled:$("partEnabled").checked,properties
      });
    };
    $("partRemove").onclick = () => removePart(part.id);
  }
  const defaultParent = editableParts.some(x => x.id === selectedPartId) ? selectedPartId : "root";
  $("partAdd").onclick = () => openForm({
    eyebrow:"OBJECT STRUCTURE",
    title:"Добавить узел",
    fields:[
      {key:"name",label:"Имя узла",value:"NewNode"},
      {key:"node_type",label:"Тип Godot",type:"select",value:"Node2D",options:NODE_TYPES.map(x=>({value:x,label:x}))},
      {key:"parent_id",label:"Родитель",type:"select",value:defaultParent,options:[{value:"root",label:"Корень объекта"},...editableParts.map(x=>({value:x.id,label:x.name}))]}
    ],
    onSubmit: values => addPart(values)
  });
}
function settingInput(descriptor, value, prefix) {
  const type = fieldType(descriptor.value_type);
  const key = String(descriptor.setting_key || descriptor.key || "");
  const component = String(descriptor.component_id || "");
  const label = descriptor.display_name || descriptor.label || key;
  const displayValue = descriptor.value_type === "Vector2" && value && typeof value === "object"
    ? String(Number(value.x) || 0) + ", " + String(Number(value.y) || 0)
    : value;
  if (type === "checkbox") {
    return '<label class="field"><span><input type="checkbox" data-' + prefix + '-setting="' + esc(key) + '" data-component-id="' + esc(component) + '" ' + (value ? "checked" : "") + '> ' + esc(label) + '</span></label>';
  }
  const inputType = type === "number" ? "number" : "text";
  return '<div class="field"><label>' + esc(label) + '</label><input type="' + inputType + '" data-' + prefix + '-setting="' + esc(key) + '" data-component-id="' + esc(component) + '" value="' + esc(displayValue ?? "") + '" ' +
    (descriptor.has_range ? 'min="' + esc(descriptor.minimum) + '" max="' + esc(descriptor.maximum) + '"' : "") + '></div>';
}
function openCapabilitySettingsDialog(capabilityId) {
  const capability = CATALOG.find(item => item.id === capabilityId);
  if (!capability || !state) return;
  const schema = capability.settingsSchema || [];
  const fields = schema.map((descriptor, index) => {
    const key = String(descriptor.setting_key || descriptor.key || "");
    const tableTypes = {
      resource_table_path: "yield",
      loot_table_path: "loot",
      recipes_table_path: "recipe",
      production_table_path: "production"
    };
    const legacyKeys = {
      resource_table_path: "resource_table_json",
      loot_table_path: "loot_table_json",
      recipes_table_path: "recipes_json",
      production_table_path: "production"
    };
    const type = tableTypes[key]
      ? "resource_path"
      : (descriptor.value_type === "String" && /_json$/i.test(key) ? "textarea" : fieldType(descriptor.value_type));
    return {
      key: "mechanic-setting-" + index,
      label: descriptor.display_name || descriptor.label || key,
      value: (() => {
        const raw = valueForSetting(capability.id, descriptor);
        if (descriptor.value_type === "Vector2" && raw && typeof raw === "object") {
          return String(Number(raw.x) || 0) + ", " + String(Number(raw.y) || 0);
        }
        return raw;
      })(),
      type,
      tableType: tableTypes[key] || "",
      legacyKey: legacyKeys[key] || "",
      min: descriptor.has_range ? descriptor.minimum : undefined,
      max: descriptor.has_range ? descriptor.maximum : undefined,
      step: descriptor.value_type === "Integer" ? 1 : (descriptor.value_type === "Float" ? 0.1 : undefined),
      description: descriptor.description || (
        key === "loot_table_json"
          ? "JSON-массив предметов: item_id, chance (0–1), minimum и maximum. Оставь [] если добычи нет."
          : ""
      )
    };
  });
  if (!fields.length) {
    fields.push({
      key: "mechanic-no-settings",
      label: "У этой механики нет дополнительных параметров.",
      value: "",
      type: "text",
      disabled: true
    });
  }
  openForm({
    eyebrow: "НАСТРОЙКИ МЕХАНИКИ",
    title: capability.name,
    description: capability.description || "Параметры выбранного поведения объекта.",
    fields,
    extraMarkup: mechanicRelationMarkup(capability),
    onOpen: root => {
      bindMechanicRelationControls(root);
      root.querySelectorAll("[data-pick-table-path]").forEach(button => {
        button.onclick = async () => {
          const key = button.dataset.pickTablePath;
          const input = root.querySelector('[data-dialog-field="' + key + '"]');
          if (!input || !window.ObjectBuilderHost?.isEmbedded) {
            toast("Выбор ресурса доступен только внутри Godot.");
            return;
          }
          try {
            const result = await window.ObjectBuilderHost.request("gameplay_table_pick_request", {
              table_type: button.dataset.tableType,
              current_path: input.value
            });
            if (result.path) input.value = result.path;
          } catch (error) {
            if (!String(error.message || error).includes("отменён")) toast(error.message || String(error));
          }
        };
      });
      root.querySelectorAll("[data-create-table-path]").forEach(button => {
        button.onclick = async () => {
          const key = button.dataset.createTablePath;
          const input = root.querySelector('[data-dialog-field="' + key + '"]');
          if (!input || !window.ObjectBuilderHost?.isEmbedded) {
            toast("Создание ресурса доступно только внутри Godot.");
            return;
          }
          let legacyJson = "";
          const legacyKey = button.dataset.legacyKey;
          if (legacyKey === "production") {
            const itemKey = capability.id === "can_produce_resources" ? "resource_item_id" : "output_item_id";
            const itemDescriptor = schema.find(item => String(item.setting_key || item.key || "") === itemKey);
            const amountDescriptor = schema.find(item => String(item.setting_key || item.key || "") === "amount_per_cycle");
            const itemIndex = schema.findIndex(item => String(item.setting_key || item.key || "") === itemKey);
            const amountIndex = schema.findIndex(item => String(item.setting_key || item.key || "") === "amount_per_cycle");
            const itemInput = itemIndex >= 0 ? root.querySelector('[data-dialog-field="mechanic-setting-' + itemIndex + '"]') : null;
            const amountInput = amountIndex >= 0 ? root.querySelector('[data-dialog-field="mechanic-setting-' + amountIndex + '"]') : null;
            const itemId = itemInput ? itemInput.value : (itemDescriptor ? valueForSetting(capability.id, itemDescriptor) : "");
            const amount = amountInput ? amountInput.value : (amountDescriptor ? valueForSetting(capability.id, amountDescriptor) : 1);
            legacyJson = JSON.stringify([{item_id:String(itemId || "").trim(),amount_per_cycle:Number(amount) || 1}]);
          } else {
            const legacyIndex = schema.findIndex(item => String(item.setting_key || item.key || "") === legacyKey);
            const legacyInput = legacyIndex >= 0 ? root.querySelector('[data-dialog-field="mechanic-setting-' + legacyIndex + '"]') : null;
            legacyJson = legacyInput ? legacyInput.value : "";
          }
          if (!String(legacyJson).trim()) {
            toast("Сначала заполни старую JSON-таблицу или параметры производства.");
            return;
          }
          try {
            const result = await window.ObjectBuilderHost.request("gameplay_table_create_from_legacy", {
              table_type: button.dataset.tableType,
              legacy_json: legacyJson,
              table_id: String(state.objectId || "object") + "_" + capability.id
            });
            if (result.path) input.value = result.path;
            const missing = Array.isArray(result.unknown_item_ids) ? result.unknown_item_ids : [];
            toast(missing.length
              ? "Ресурс создан. Не найдены item_id: " + missing.join(", ")
              : "Ресурс таблицы создан: " + result.path);
          } catch (error) {
            toast(error.message || String(error));
          }
        };
      });
    },
    submitLabel: schema.length ? "Сохранить параметры" : "Закрыть",
    onSubmit: async values => {
      if (!schema.length) return true;
      const updates = schema.map((descriptor, index) => {
        let value = values["mechanic-setting-" + index];
        if (descriptor.value_type === "Integer") {
          value = Number.parseInt(value, 10);
          if (!Number.isFinite(value)) throw new Error("Проверь целочисленное значение: " + (descriptor.display_name || descriptor.key));
        } else if (descriptor.value_type === "Float") {
          value = Number(value);
          if (!Number.isFinite(value)) throw new Error("Проверь числовое значение: " + (descriptor.display_name || descriptor.key));
        } else if (descriptor.value_type === "Vector2") {
          value = parseVector2Value(value);
        } else if (descriptor.value_type === "String" && /_json$/i.test(String(descriptor.setting_key || descriptor.key || ""))) {
          const settingKey = String(descriptor.setting_key || descriptor.key || "");
          let parsedJson;
          try {
            parsedJson = JSON.parse(String(value ?? ""));
          } catch (error) {
            throw new Error("Некорректный JSON в настройке «" + (descriptor.display_name || settingKey) + "»: " + error.message);
          }
          if (settingKey === "loot_table_json") {
            if (!Array.isArray(parsedJson)) {
              throw new Error("Таблица добычи должна быть JSON-массивом записей.");
            }
            parsedJson = parsedJson.map((entry, entryIndex) => {
              if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
                throw new Error("Запись добычи №" + (entryIndex + 1) + " должна быть объектом.");
              }
              const itemId = String(entry.item_id || "").trim();
              const chance = Number(entry.chance ?? 1);
              const minimum = Number(entry.minimum ?? 1);
              const maximum = Number(entry.maximum ?? minimum);
              if (!itemId) throw new Error("В записи добычи №" + (entryIndex + 1) + " не указан item_id.");
              if (!Number.isFinite(chance) || chance < 0 || chance > 1) {
                throw new Error("Шанс выпадения в записи №" + (entryIndex + 1) + " должен быть от 0 до 1.");
              }
              if (!Number.isInteger(minimum) || !Number.isInteger(maximum) || minimum < 0 || maximum < minimum) {
                throw new Error("Количество в записи №" + (entryIndex + 1) + " должно быть целым, неотрицательным, а maximum не меньше minimum.");
              }
              return {...entry, item_id:itemId, chance, minimum, maximum};
            });
          }
          value = JSON.stringify(parsedJson);
        }
        return {
          componentId: descriptor.component_id,
          key: descriptor.setting_key || descriptor.key,
          value
        };
      });
      return await saveCapabilitySettings(capability.id, updates);
    }
  });
}
function renderBehaviorInspector(body) {
  const installed = (state.caps || []).map(id => CATALOG.find(x => x.id === id)).filter(Boolean);
  body.innerHTML = '<div class="mini-title">УСТАНОВЛЕННЫЕ МЕХАНИКИ <span class="count">' + installed.length + '</span></div>' +
    (installed.length ? installed.map(installedMechanicRowMarkup).join("") : '<div class="empty compact-empty">У объекта пока нет подключённых механик.</div>') +
    '<div class="mini-title">ДОБАВИТЬ МЕХАНИКУ</div><button class="btn primary" id="openCapabilityCatalog">Открыть каталог механик</button>';
  $("openCapabilityCatalog").onclick = () => setView("catalog");
  bindInstalledMechanicRows(body);
}
function bindMechanicRelationControls(root) {
  root.querySelectorAll("[data-mechanic-add]").forEach(button =>
    button.onclick = () => addMechanicRelation(button.dataset.mechanicAdd, button.dataset.mechanicKind));
  root.querySelectorAll("[data-mechanic-create]").forEach(button =>
    button.onclick = () => openRelatedCreateForm(button.dataset.mechanicCreate, button.dataset.mechanicKind));
  bindRelationRows(root);
}
function bindMechanicSettingForms(root) {
  root.querySelectorAll("[data-cap-remove]").forEach(button => button.onclick = () => toggleCapability(button.dataset.capRemove,false));
  root.querySelectorAll("[data-cap-settings-save]").forEach(button => button.onclick = () => {
    const capabilityId = button.dataset.capSettingsSave;
    const parent = button.closest("[data-capability-settings]");
    const settings = [...parent.querySelectorAll("[data-cap-setting]")].map(input => {
      const descriptor = CATALOG.find(x => x.id === capabilityId)?.settingsSchema?.find(x => (x.setting_key || x.key) === input.dataset.capSetting && x.component_id === input.dataset.componentId);
      let value = input.type === "checkbox" ? input.checked : input.value;
      if (descriptor?.value_type === "Integer") value = Number.parseInt(value,10) || 0;
      if (descriptor?.value_type === "Float") value = Number(value) || 0;
      if (descriptor?.value_type === "Vector2") value = parseVector2Value(value);
      return {componentId:input.dataset.componentId,key:input.dataset.capSetting,value};
    });
    saveCapabilitySettings(capabilityId,settings);
  });
  root.querySelectorAll("[data-relation-for]").forEach(button => button.onclick = () => openRelationForm(button.dataset.relationFor));
  root.querySelectorAll("[data-mechanic-add]").forEach(button => button.onclick = () => addMechanicRelation(button.dataset.mechanicAdd,button.dataset.mechanicKind));
  root.querySelectorAll("[data-mechanic-create]").forEach(button => button.onclick = () => openRelatedCreateForm(button.dataset.mechanicCreate,button.dataset.mechanicKind));
  bindRelationRows(root);
}
function renderComponentsInspector(body) {
  const installed = state.components || [];
  body.innerHTML = '<div class="mini-title">НИЗКОУРОВНЕВЫЕ КОМПОНЕНТЫ <span class="count">' + installed.length + '</span></div>' +
    '<p class="detail-desc">Компоненты — нативные реализации поведения. Обычно их добавляют через механику; ручное добавление оставлено для расширенного режима.</p>' +
    (installed.length ? installed.map(component => {
      const schema = component.settings_schema || [];
      return '<section class="relation-view-group"><header><div><b>' + esc(component.name) + '</b><small>' + esc(component.component_id) + ' · ' + esc(component.category) + '</small></div><button class="btn small danger" data-component-remove="' + esc(component.component_id) + '">Удалить</button></header>' +
        schema.map(d => settingInput(d,component.settings?.[d.key] ?? d.default_value,"component")).join("") +
        (schema.length ? '<button class="btn small primary" data-component-save="' + esc(component.component_id) + '">Сохранить параметры</button>' : '') + '</section>';
    }).join("") : '<div class="empty compact-empty">Ручных компонентов нет. Механики автоматически создают нужные привязки.</div>') +
    '<div class="mini-title">ДОБАВИТЬ КОМПОНЕНТ</div>' +
    '<div class="field"><select id="componentCatalogSelect">' + COMPONENTS.filter(x => !installed.some(c => c.component_id === x.id)).map(x => '<option value="' + esc(x.id) + '">' + esc(x.name) + ' · ' + esc(x.category) + '</option>').join("") + '</select></div>' +
    '<button class="btn" id="componentAdd" ' + (COMPONENTS.length === installed.length ? "disabled" : "") + '>＋ Добавить компонент</button>';
  $("componentAdd")?.addEventListener("click", () => addComponent($("componentCatalogSelect").value));
  body.querySelectorAll("[data-component-remove]").forEach(button => button.onclick = () => removeComponent(button.dataset.componentRemove));
  body.querySelectorAll("[data-component-save]").forEach(button => button.onclick = () => {
    const componentId = button.dataset.componentSave;
    const block = button.closest(".relation-view-group");
    const settings = {};
    block.querySelectorAll("[data-component-setting]").forEach(input => {
      const descriptor = COMPONENTS.find(x => x.id === componentId)?.settingsSchema?.find(x => x.key === input.dataset.componentSetting);
      let value = input.type === "checkbox" ? input.checked : input.value;
      if (descriptor?.value_type === "Integer") value = Number.parseInt(value,10) || 0;
      if (descriptor?.value_type === "Float") value = Number(value) || 0;
      if (descriptor?.value_type === "Vector2") value = parseVector2Value(value);
      settings[input.dataset.componentSetting] = value;
    });
    saveComponentSettings(componentId,settings);
  });
}

const RELATION_PROFILES = {
  can_be_harvested:{title:"Добыча и сбор",kinds:["harvest"],trigger:"После успешного сбора",description:"Какие предметы и в каком количестве выдаются за добычу."},
  can_produce_resources:{title:"Производство ресурсов",kinds:["produce"],trigger:"По циклу производства",description:"Какие объекты производятся со временем."},
  supports_item_crafting:{title:"Рецепт изготовления",kinds:["input","produce"],trigger:"При запуске изготовления",description:"Материалы, расходуемые на рецепт, и его результат."},
  breaks_when_health_empty:{title:"Разрушение объекта",kinds:["drop","remains"],trigger:"Когда здоровье достигает нуля",description:"Выпадающие предметы, остатки и обломки после разрушения."}
};
const RELATION_KIND_LABELS = {
  related:"Связан с",drop:"Выпадает при разрушении",harvest:"Результат добычи / сбора",
  produce:"Производится",input:"Материал рецепта",remains:"Остаётся после разрушения"
};
function relationOwnerId(relation) {
  if (relation?.mechanic_id) return relation.mechanic_id;
  return ({drop:"breaks_when_health_empty",remains:"breaks_when_health_empty",harvest:"can_be_harvested",produce:"can_produce_resources",input:"supports_item_crafting"})[relation?.kind] || "";
}
function allRelationObjects() {
  const unique = new Map();
  [...projectObjects,...openDocuments,state].filter(Boolean).forEach(object => {
    if (object.objectId) unique.set(object.objectId,object);
  });
  return [...unique.values()];
}
function findRelationTarget(targetId) {
  return allRelationObjects().find(object => object.objectId === targetId) ||
    templates.find(template => template.objectId === targetId) || null;
}
function defaultRelationSettings(kind,settings = {}) {
  const placementDefaults = {drop:"drop",remains:"replace",harvest:"spawn",produce:"spawn",input:"consume",related:"attach"};
  const currentPosition = settings.local_position && typeof settings.local_position === "object" ? settings.local_position : {};
  const currentScale = settings.local_scale && typeof settings.local_scale === "object" ? settings.local_scale : {};
  const numberOr = (value,fallback) => Number.isFinite(Number(value)) ? Number(value) : fallback;
  return {
    ...settings,
    placement:String(settings.placement || placementDefaults[kind] || "attach"),
    embed_in_parent:settings.embed_in_parent === true,
    local_position:{x:numberOr(currentPosition.x,0),y:numberOr(currentPosition.y,kind === "drop" ? -12 : 0)},
    rotation:numberOr(settings.rotation,0),
    local_scale:{x:numberOr(currentScale.x,1),y:numberOr(currentScale.y,1)}
  };
}
function relationPlacementOptions(kind) {
  const options = {
    drop:[["drop","Появиться рядом с родителем"],["replace","Заменить родительский объект"],["attach","Прикрепить к родителю"]],
    remains:[["replace","Заменить родительский объект"],["attach","Остаться прикреплённым"],["spawn","Появиться рядом"]],
    harvest:[["spawn","Появиться рядом"],["drop","Выпасть рядом"],["attach","Прикрепить к родителю"]],
    produce:[["spawn","Создать рядом"],["attach","Прикрепить к родителю"]],
    input:[["consume","Поглотить / расходовать"],["attach","Закрепить как часть"]],
    related:[["attach","Прикрепить к родителю"],["spawn","Появиться рядом"]]
  };
  return options[kind] || options.related;
}
function relationPlacementLabel(value) {
  return ({drop:"Выпадение рядом",replace:"Замена родителя",attach:"Дочерняя часть",spawn:"Создать рядом",consume:"Расходуемый объект",embedded:"Встроенная часть объекта"})[value] || "Дочерняя часть";
}
function normalizeLibraryIdentity(value) {
  return String(value || "").trim().toLocaleLowerCase("ru").replace(/ё/g,"е");
}
function findSavedObjectByIdentity(name,category,templateId = "") {
  const wantedName = normalizeLibraryIdentity(name);
  const wantedCategory = normalizeLibraryIdentity(category);
  if (templateId) {
    const byTemplate = projectObjects.find(object => object.templateId === templateId);
    if (byTemplate) return byTemplate;
  }
  if (!wantedName || !wantedCategory) return null;
  return projectObjects.find(object =>
    normalizeLibraryIdentity(object.name) === wantedName &&
    normalizeLibraryIdentity(object.category) === wantedCategory
  ) || null;
}
function findSavedObjectForTemplate(template) {
  if (!template) return null;
  return findSavedObjectByIdentity(template.name,template.category,template.objectId);
}
function relationTargetOptions(kind) {
  const options = new Map();
  allRelationObjects().filter(object => object.objectId !== state.objectId).forEach(object => {
    options.set(object.objectId,{value:object.objectId,label:(object.emoji || "📦") + " " + object.name + " · " + object.type + (object.saved ? "" : " · черновик")});
  });
  templates.forEach(template => {
    if (template.objectId === state.objectId) return;
    const existing = findSavedObjectForTemplate(template);
    if (existing) return;
    options.set("template:" + template.objectId,{
      value:"template:" + template.objectId,
      label:(template.emoji || "📦") + " " + template.name + " · шаблон"
    });
  });
  const entries = [...options.values()].sort((a,b) => a.label.localeCompare(b.label,"ru"));
  return '<option value="">Выбрать объект…</option>' + entries.map(option =>
    '<option value="' + esc(option.value) + '">' + esc(option.label) + '</option>'
  ).join("");
}
function mechanicRelationMarkup(capability) {
  const profile = RELATION_PROFILES[capability.id];
  if (!profile) return "";
  return '<details class="mechanic-relation-editor"><summary class="mechanic-relation-heading"><span><b>Связи механики</b><small>' + esc(profile.trigger) + '</small></span><span class="relation-count">' +
    (state.relations || []).filter(relation => relationOwnerId(relation) === capability.id).length +
    ' · открыть</span></summary><p class="mechanic-relation-description">' + esc(profile.description) + '</p><div class="mechanic-relation-content">' +
    profile.kinds.map(kind => {
      const relations = (state.relations || []).filter(relation => relationOwnerId(relation) === capability.id && relation.kind === kind);
      const title = ({input:"Расходуемые материалы",produce:"Результат производства",drop:"Что выпадает",harvest:"Что получается при сборе",remains:"Остатки после разрушения"})[kind] || RELATION_KIND_LABELS[kind];
      return '<div class="mechanic-relation-group"><div class="mechanic-relation-group-title">' + esc(title) +
        ' <span>' + relations.length + '</span></div>' +
        (relations.length ? relations.map(relation => relationRow(relation,kind === "input" ? "←" : "→")).join("") :
          '<div class="empty compact-empty">Пока ничего не назначено.</div>') +
        '<div class="mechanic-relation-add"><div class="field"><label>Объект</label><select data-mechanic-target="' +
        esc(capability.id + "|" + kind) + '">' + relationTargetOptions(kind) + '</select></div>' +
        '<div class="field quantity-field"><label>Количество</label><input type="number" min="1" max="99999" step="1" value="1" data-mechanic-quantity="' +
        esc(capability.id + "|" + kind) + '"></div>' +
        (kind === "harvest" ? '<div class="field relation-item-id-field"><label>ID предмета в игровом инвентаре</label><input type="text" placeholder="например, wood" data-mechanic-item-id="' + esc(capability.id + "|" + kind) + '"></div>' : '') +
        '<div class="relation-picker-actions"><button class="btn primary small" type="button" data-mechanic-add="' +
        esc(capability.id) + '" data-mechanic-kind="' + esc(kind) + '">＋ Добавить</button>' +
        '<button class="btn small" type="button" data-mechanic-create="' + esc(capability.id) +
        '" data-mechanic-kind="' + esc(kind) + '">＋ Создать объект</button></div></div></div>';
    }).join("") +
    '<p class="relation-hint">Связь остаётся отдельным объектом библиотеки. Обратные ссылки доступны во вкладке «Связи».</p></div></details>';
}
async function createRelatedAndLink(createPayload,relationPayload) {
  if (!state?.objectId) throw new Error("Сначала открой исходный объект.");
  await syncNow();
  const result = await api("object_create_related",{...createPayload,relation:relationPayload});
  const related = result.related;
  if (!related?.objectId) throw new Error("Godot не вернул созданный связанный объект.");
  return related;
}
async function resolveRelationTarget(value,relationPayload = null) {
  if (!value) throw new Error("Сначала выбери целевой объект.");
  if (value.startsWith("template:")) {
    if (!relationPayload) throw new Error("Для копирования шаблона сразу задай механику связи.");
    const templateId = value.slice("template:".length);
    const template = templates.find(object => object.objectId === templateId);
    if (!template) throw new Error("Шаблон связанного объекта не найден.");
    const existing = findSavedObjectForTemplate(template);
    if (existing) return existing;
    return createRelatedAndLink({
      mode:"template",source_id:templateId,name:template.name,
      category:template.category,description:template.description,tags:template.tags
    },relationPayload);
  }
  const target = allRelationObjects().find(object => object.objectId === value);
  if (!target) throw new Error("Целевой объект не найден. Обнови библиотеку или создай связанный объект заново.");
  return target;
}
async function addMechanicRelation(capabilityId,kind) {
  const key = capabilityId + "|" + kind;
  const select = document.querySelector('[data-mechanic-target="' + key + '"]');
  const quantity = document.querySelector('[data-mechanic-quantity="' + key + '"]');
  const itemIdInput = document.querySelector('[data-mechanic-item-id="' + key + '"]');
  try {
    const itemId = String(itemIdInput?.value || "").trim();
    if (kind === "harvest" && !itemId) throw new Error("Укажи ID предмета, который должен попасть в инвентарь (например, wood).");
    const relationPayload = {
      mechanic_id:capabilityId,
      kind,
      label:RELATION_KIND_LABELS[kind] || "Связанный объект",
      quantity:Math.max(1,Math.min(99999,Math.floor(Number(quantity?.value) || 1))),
      settings:defaultRelationSettings(kind,{condition:"",action:"",...(kind === "harvest" ? {item_id:itemId} : {})})
    };
    const selectedValue = select?.value || "";
    const target = await resolveRelationTarget(selectedValue,relationPayload);
    if (selectedValue.startsWith("template:")) {
      toast("Копия шаблона создана и сразу добавлена в механику.");
      return;
    }
    await addRelation({...relationPayload,target_object_id:target.objectId});
  } catch (error) { toast(error.message,true); }
}
function openRelatedCreateForm(capabilityId,kind) {
  const defaultProfile = creationProfiles.find(profile => /resource|item|ресурс|предмет/i.test(profile.id + " " + profile.name)) || creationProfiles[0];
  openForm({
    eyebrow:"СВЯЗЬ МЕХАНИКИ",
    title:"Создать связанный объект",
    description:"Объект, его черновик и связь с этой механикой создаются одной операцией. Он сразу появится отдельной строкой среди открытых объектов и будет доступен в окне сохранения.",
    fields:[
      {key:"name",label:"Название объекта",value:"Новый связанный объект"},
      {key:"profile_id",label:"Тип заготовки",type:"select",value:defaultProfile?.id || "other",options:creationProfiles.map(profile => ({value:profile.id,label:profile.name + " · " + profile.rootType}))},
      ...(kind === "harvest" ? [{key:"item_id",label:"ID предмета в игровом инвентаре",value:""}] : [])
    ],
    onSubmit:async values => {
      if (kind === "harvest" && !String(values.item_id || "").trim()) {
        throw new Error("Укажи ID предмета для игрового инвентаря (например, wood).");
      }
      const profile = creationProfiles.find(item => item.id === values.profile_id);
      const requestedName = String(values.name || "Новый связанный объект").trim();
      const category = profile?.category || "Other";
      const relationPayload = {
        mechanic_id:capabilityId,kind,
        label:RELATION_KIND_LABELS[kind] || "Связанный объект",quantity:1,
        settings:defaultRelationSettings(kind,{condition:"",action:"",...(kind === "harvest" ? {item_id:String(values.item_id || "").trim()} : {})})
      };
      const existing = findSavedObjectByIdentity(requestedName,category);
      if (existing) {
        const linked = await addRelation({...relationPayload,target_object_id:existing.objectId},{silent:true});
        if (!linked) return false;
        toast("«" + existing.name + "» уже есть в библиотеке. Использована существующая запись, копия не создавалась.");
        return true;
      }
      await createRelatedAndLink({
        mode:"new",profile_id:values.profile_id,name:requestedName,
        category,description:"Создан как связанный объект."
      },relationPayload);
      toast("Связанный объект создан и подключён. Он появится в комплекте при сохранении.");
      return true;
    }
  });
}

function relationRow(relation,direction = "→",readOnly = false) {
  const targetId = relation.target_object_id || "";
  const target = findRelationTarget(targetId);
  const settings = defaultRelationSettings(relation.kind,relation.settings || {});
  const position = settings.local_position;
  const notes = [
    settings.embed_in_parent ? "Встроена в родительский объект · скрыта до события" : relationPlacementLabel(settings.placement),
    !settings.embed_in_parent ? "локально (" + position.x + ", " + position.y + ")" : "",
    !settings.embed_in_parent && Number(settings.rotation) ? "поворот " + settings.rotation + "°" : ""
  ].filter(Boolean).join(" · ");
  return '<article class="relation-view-row ' + (readOnly ? "read-only" : "") + (settings.embed_in_parent ? " embedded-relation" : "") + '">' +
    '<span class="relation-view-arrow">' + direction + '</span><div class="relation-view-target"><b>' +
    esc(target ? (target.emoji || "📦") + " " + target.name : ("Не найден объект: " + targetId)) + '</b><small>' +
    esc(relation.label || RELATION_KIND_LABELS[relation.kind] || relation.kind) + ' · ' + esc(RELATION_KIND_LABELS[relation.kind] || relation.kind) +
    ' · ' + esc(notes) + '</small></div>' +
    '<div class="relation-view-actions">' +
      (!readOnly ? '<label class="relation-quantity"><span>Количество</span><input type="number" min="1" max="99999" step="1" value="' + Math.max(1,Number(relation.quantity) || 1) +
        '" data-relation-quantity="' + esc(relation.relation_id) + '"></label>' : '<span class="relation-quantity-static">Количество: ' + Math.max(1,Number(relation.quantity) || 1) + '</span>') +
      '<div class="relation-view-buttons">' +
        (target ? '<button class="btn small" data-relation-open="' + esc(targetId) + '">Открыть</button>' : '') +
        (!readOnly ? '<button class="btn small" data-relation-edit="' + esc(relation.relation_id) + '">Настроить</button><button class="btn small danger" data-relation-remove="' + esc(relation.relation_id) + '">×</button>' : '') +
      '</div></div></article>';
}
function renderRelationsInspector(body) {
  const outgoing = state.relations || [];
  const incoming = allRelationObjects().filter(source => source.objectId !== state.objectId).flatMap(source =>
    (source.relations || []).filter(relation => relation.target_object_id === state.objectId).map(relation => ({source,relation}))
  );
  const groups = new Map();
  outgoing.forEach(relation => {
    const owner = relationOwnerId(relation) || "__general";
    if (!groups.has(owner)) groups.set(owner,[]);
    groups.get(owner).push(relation);
  });
  const outgoingMarkup = groups.size ? [...groups.entries()].map(([owner,relations]) => {
    const capability = CATALOG.find(item => item.id === owner);
    const title = RELATION_PROFILES[owner]?.title || capability?.name || "Общие связи";
    const description = RELATION_PROFILES[owner]?.description || "Связи без владельца-механики.";
    return '<section class="relation-view-group"><header><div><b>' + esc(title) + '</b><small>' + esc(description) + '</small></div>' +
      (capability ? '<button class="btn small" type="button" data-open-mechanic="' + esc(owner) + '">К механике ↗</button>' : '') +
      '<span class="relation-count">' + relations.length + '</span></header>' +
      relations.map(relation => relationRow(relation,relation.kind === "input" ? "←" : "→")).join("") + '</section>';
  }).join("") : '<div class="empty compact-empty">Исходящих связей пока нет. Добавляй результаты непосредственно в карточках механик — так связи не потеряют владельца.</div>';
  const incomingMarkup = incoming.length ? incoming.map(({source,relation}) =>
    '<div class="relation-view-row read-only"><span class="relation-view-arrow">←</span><div class="relation-view-target"><b>' +
    esc((source.emoji || "📦") + " " + source.name) + '</b><small>' +
    esc(RELATION_KIND_LABELS[relation.kind] || relation.label || relation.kind) + ' · ' + esc(relation.kind) + '</small></div>' +
    '<button class="btn small" data-relation-open="' + esc(source.objectId) + '">Открыть источник</button></div>'
  ).join("") : '<div class="empty compact-empty">Другие объекты пока не ссылаются на этот.</div>';
  body.innerHTML =
    '<div class="relation-head"><div><div class="mini-title">ИСХОДЯЩИЕ СВЯЗИ</div><p class="detail-desc">Связи сгруппированы по механике-владельцу. Удаление связи не удаляет цель и не затрагивает другие ссылки.</p></div><span class="relation-count">' + outgoing.length + '</span></div>' +
    outgoingMarkup +
    '<button class="btn primary" id="relationAdd">＋ Общая связь</button>' +
    '<div class="mini-title">ОБРАТНЫЕ ССЫЛКИ <span class="count">' + incoming.length + '</span></div>' + incomingMarkup;
  $("relationAdd").onclick = () => openRelationForm("");
  bindRelationRows(body);
  body.querySelectorAll("[data-open-mechanic]").forEach(button => button.onclick = () => {
    inspectorTab = "Поведение";
    renderInspector();
    body.querySelector('[data-capability-settings="' + button.dataset.openMechanic + '"]')?.scrollIntoView({block:"nearest"});
  });
}
function bindRelationRows(root) {
  root.querySelectorAll("[data-relation-open]").forEach(button => button.onclick = () => openObject(button.dataset.relationOpen));
  root.querySelectorAll("[data-relation-remove]").forEach(button => button.onclick = () => removeRelation(button.dataset.relationRemove));
  root.querySelectorAll("[data-relation-edit]").forEach(button => button.onclick = () => editRelation(button.dataset.relationEdit));
  root.querySelectorAll("[data-relation-quantity]").forEach(input => input.onchange = () => {
    const relation = state.relations.find(item => item.relation_id === input.dataset.relationQuantity);
    if (!relation) return;
    updateRelation({relation_id:relation.relation_id,quantity:Math.max(1,Math.min(99999,Math.floor(Number(input.value) || 1)))});
  });
}
function openRelationForm(mechanicId,kind = "related",relation = null) {
  if (!state) return;
  const candidates = allRelationObjects().filter(object => object.objectId !== state.objectId);
  if (!candidates.length) return toast("Сначала создай или выбери целевой объект.");
  const ownerId = relation?.mechanic_id || mechanicId || "";
  const ownerProfile = RELATION_PROFILES[ownerId] || null;
  const allowedKinds = ownerProfile ? ownerProfile.kinds : ["related"];
  const selectedKind = allowedKinds.includes(relation?.kind || kind) ? (relation?.kind || kind) : allowedKinds[0];
  const settings = defaultRelationSettings(selectedKind,relation?.settings || {});
  const placementOptions = relationPlacementOptions(selectedKind).map(([value,label])=>({value,label}));
  openForm({
    eyebrow:"OBJECT RELATIONS",
    title:relation ? "Настроить связь" : "Добавить связь механики",
    description:ownerProfile
      ? "Связь принадлежит механике «" + ownerProfile.title + "». Цель остаётся отдельным объектом, но может быть показана как выпадающий, остающийся или прикреплённый объект."
      : "Общая связь между объектами. Для результата рубки, добычи и производства настрой связь внутри конкретной механики.",
    fields:[
      {key:"target_object_id",label:"Целевой объект",type:"select",value:relation?.target_object_id || candidates[0].objectId,disabled:settings.embed_in_parent,options:candidates.map(object=>({value:object.objectId,label:(object.emoji || "📦") + " " + object.name + " · " + object.category + (object.saved ? "" : " · черновик")}))},
      {key:"mechanic_id",label:"Механика-владелец",type:"select",value:ownerId,disabled:settings.embed_in_parent,options:[{value:ownerId,label:ownerProfile ? ownerProfile.title : "Общая связь"}]},
      {key:"kind",label:"Тип связи",type:"select",value:selectedKind,disabled:settings.embed_in_parent,options:allowedKinds.map(value=>({value,label:RELATION_KIND_LABELS[value]}))},
      {key:"label",label:"Название связи",value:relation?.label || RELATION_KIND_LABELS[selectedKind] || ""},
      {key:"quantity",label:"Количество создаваемых / требуемых объектов",type:"number",value:relation?.quantity || 1,min:1,max:99999},
      ...(selectedKind === "harvest" ? [{key:"item_id",label:"ID предмета в игровом инвентаре",value:settings.item_id || ""}] : []),
      ...(allowedKinds.includes("remains") ? [{
        key:"embed_in_parent",label:"Встроить как часть родительского объекта",type:"checkbox",
        value:settings.embed_in_parent,disabled:settings.embed_in_parent || selectedKind !== "remains",
        description:settings.embed_in_parent
          ? "Часть уже встроена. Её слои доступны в редакторе спрайтов; в игре они будут скрыты до срабатывания механики."
          : "Доступно для типа связи «Остаётся после разрушения». После подтверждения спрайты выбранного объекта копируются в родительский объект отдельными редактируемыми слоями и скрываются в игре до разрушения."
      }] : []),
      {key:"placement",label:"Как размещать целевой объект",type:"select",value:settings.placement,options:placementOptions,disabled:settings.embed_in_parent},
      {key:"offsetX",label:"Локальное смещение X, px",type:"number",value:settings.local_position.x,min:-8192,max:8192,step:1,disabled:settings.embed_in_parent},
      {key:"offsetY",label:"Локальное смещение Y, px",type:"number",value:settings.local_position.y,min:-8192,max:8192,step:1,disabled:settings.embed_in_parent},
      {key:"rotation",label:"Поворот относительно родителя, °",type:"number",value:settings.rotation,min:-360,max:360,step:1,disabled:settings.embed_in_parent},
      {key:"scaleX",label:"Масштаб дочернего объекта X",type:"number",value:settings.local_scale.x,min:.05,max:16,step:.05,disabled:settings.embed_in_parent},
      {key:"scaleY",label:"Масштаб дочернего объекта Y",type:"number",value:settings.local_scale.y,min:.05,max:16,step:.05,disabled:settings.embed_in_parent}
    ],
    onSubmit:async values => {
      const activeKind = String(values.kind || selectedKind);
      if (activeKind === "harvest" && !String(values.item_id || "").trim()) {
        toast("Укажи ID предмета для игрового инвентаря (например, wood).",true);
        return false;
      }
      const payload = {
        ...values,mechanic_id:ownerId,
        quantity:Math.max(1,Math.min(99999,Math.floor(Number(values.quantity) || 1))),
        settings:{
          ...settings,
          ...(activeKind === "harvest" ? {item_id:String(values.item_id || "").trim()} : {}),
          embed_in_parent:activeKind === "remains" ? (settings.embed_in_parent || values.embed_in_parent === true) : false,
          placement:String(values.placement || settings.placement),
          local_position:{
            x:Math.max(-8192,Math.min(8192,Number(values.offsetX) || 0)),
            y:Math.max(-8192,Math.min(8192,Number(values.offsetY) || 0))
          },
          rotation:Math.max(-360,Math.min(360,Number(values.rotation) || 0)),
          local_scale:{
            x:Math.max(.05,Math.min(16,Number(values.scaleX) || 1)),
            y:Math.max(.05,Math.min(16,Number(values.scaleY) || 1))
          }
        }
      };
      delete payload.item_id;
      delete payload.embed_in_parent;
      delete payload.placement; delete payload.offsetX; delete payload.offsetY;
      delete payload.rotation; delete payload.scaleX; delete payload.scaleY;
      if (activeKind === "remains" && values.embed_in_parent === true && !settings.embed_in_parent) {
        const targetName = findRelationTarget(values.target_object_id)?.name || "выбранный объект";
        if (!window.confirm("Встроить «" + targetName + "» в «" + state.name + "» как скрытую часть? Спрайты будут скопированы в родительский объект, а исходная запись останется в библиотеке.")) return false;
        const result = await api("relation_embed_as_part",{...payload,relation_id:relation?.relation_id || "",settings:payload.settings});
        hydrateWorking(result.working);
        captureUndo();
        toast("Объект встроен как часть. Настрой его слои в редакторе спрайтов.");
        return true;
      }
      if (relation) return updateRelation({...payload,relation_id:relation.relation_id});
      return addRelation(payload);
    }
  });
  const kindField = $("editorDialogFields").querySelector('[data-dialog-field="kind"]');
  const placementField = $("editorDialogFields").querySelector('[data-dialog-field="placement"]');
  kindField?.addEventListener("change",() => {
    if (!placementField) return;
    const nextKind = kindField.value;
    const embedField = $("editorDialogFields").querySelector('[data-dialog-field="embed_in_parent"]');
    if (embedField) embedField.disabled = settings.embed_in_parent || nextKind !== "remains";
    const nextOptions = relationPlacementOptions(nextKind);
    placementField.innerHTML = nextOptions.map(([value,label]) => '<option value="' + esc(value) + '">' + esc(label) + '</option>').join("");
    const defaults = defaultRelationSettings(nextKind,{});
    placementField.value = defaults.placement;
    const offsetYField = $("editorDialogFields").querySelector('[data-dialog-field="offsetY"]');
    if (offsetYField && !relation) offsetYField.value = String(defaults.local_position.y);
  });
}
function editRelation(relationId) {
  const relation = state?.relations?.find(item => item.relation_id === relationId);
  if (relation) openRelationForm(relation.mechanic_id,relation.kind,relation);
}
const CAPABILITY_CATEGORY_EMOJI = {
  "Основное":"🧩","Внешний вид":"🎨","Анимация":"🎞️","Движение":"🏃","Физика":"🧲",
  "Взаимодействие":"🤝","Характеристики":"❤️","Бой":"⚔️","Защита":"🛡️","Разрушение":"💥",
  "Добыча и сбор":"⛏️","Предметы":"🧪","Инвентарь":"🎒","Контейнеры":"📦","Строительство":"🏠",
  "Поведение и AI":"🧠","Животные":"🐾","Звук и эффекты":"🔊","Время и события":"⏱️","Генерация мира":"🌍"
};
function capabilityCategoryEmoji(category) {
  return CAPABILITY_CATEGORY_EMOJI[String(category || "")] || "✦";
}
function creationProfileEmoji(profile) {
  const icons = {npc:"🧑",resource:"⛏️",construction:"🏠",item:"📦",weapon:"⚔️",tool:"🪓",animal:"🐾",interactive:"⚙️",decoration:"🌿",transport:"🛒",effect:"✨",other:"◇"};
  return icons[String(profile?.id || "")] || "◇";
}
function templateCategoryEmoji(category) {
  const icons = {"Природа":"🌳","Ферма":"🌾","Ресурсы":"🪨","Оружие":"⚔️","Инструменты":"🛠️","Контейнеры":"📦","Здания":"🏠","Мебель":"🪑","Механизмы":"⚙️","Персонажи":"🧑","Животные":"🐾","Декорации":"🪴","Транспорт":"🛒"};
  return icons[String(category || "")] || "◇";
}

function renderCatalog() {
  const categoriesList = [...new Set(CATALOG.map(x => x.category).filter(Boolean))];
  $("catalogCount").textContent = String(CATALOG.length);
  if ($("capabilityCategoryCount")) $("capabilityCategoryCount").textContent = String(categoriesList.length);
  const groupedCounts = categoriesList.map(name => [name,CATALOG.filter(x => x.category === name).length]);
  $("categoryList").innerHTML =
    '<button class="sideitem ' + (!window._capCategory || window._capCategory === "Все" ? "active" : "") + '" data-cap-category="Все"><span><i class="sideicon">✧</i>Все категории</span><span class="count">' + CATALOG.length + '</span></button>' +
    groupedCounts.map(([name,count]) => '<button class="sideitem ' + (window._capCategory === name ? "active" : "") + '" data-cap-category="' + esc(name) + '"><span><i class="sideicon">' + capabilityCategoryEmoji(name) + '</i>' + esc(name) + '</span><span class="count">' + count + '</span></button>').join("");
  $("categoryList").querySelectorAll("[data-cap-category]").forEach(button => button.onclick = () => {
    window._capCategory = button.dataset.capCategory;
    renderCatalog();
  });
  const query = capSearch.trim().toLowerCase();
  const visible = CATALOG.filter(item =>
    (!window._capCategory || window._capCategory === "Все" || item.category === window._capCategory) &&
    (capFilter === "Все" || (capFilter === "Работает" ? item.status === "Работает" : capFilter === "В разработке" ? item.status !== "Работает" : state?.caps?.includes(item.id))) &&
    (!query || (item.id + " " + item.name + " " + item.description + " " + item.category + " " + (item.keywords || []).join(" ")).toLowerCase().includes(query))
  );
  $("catalogResults").textContent = visible.length + " возможностей в выбранном разделе · всего " + CATALOG.length;
  $("catalogGrid").innerHTML = visible.map(item => {
    const installed = !!state?.caps?.includes(item.id);
    const ready = item.status === "Работает";
    const icon = capabilityCategoryEmoji(item.category);
    const stateText = installed ? "ПОДКЛЮЧЕНО" : ready ? "РАБОТАЕТ" : "В РАЗРАБОТКЕ";
    const stateMark = installed ? "✓" : ready ? "＋" : "◷";
    return '<button class="cap-card ' + (selectedCapabilityId === item.id ? "focused " : "") + (installed ? "installed " : "") + (!ready ? "locked" : "") + '" data-cap="' + esc(item.id) + '">' +
      '<div class="cap-top"><span class="cap-icon" aria-hidden="true">' + icon + '</span><span class="cap-state ' + (ready ? "status-ready" : "status-wip") + '">' + stateText + '</span></div>' +
      '<h3>' + esc(item.name) + '</h3><p>' + esc(item.description) + '</p>' +
      '<div class="cap-meta"><span class="category-tag">' + esc(item.category) + '</span><span class="cap-state">' + stateMark + '</span></div>' +
    '</button>';
  }).join("") || '<div class="empty">Ничего не найдено. Измени запрос или фильтр.</div>';
  $("catalogGrid").querySelectorAll("[data-cap]").forEach(button => button.onclick = () => {
    selectedCapabilityId = button.dataset.cap;
    renderCatalog();
    renderCapabilityDetail();
  });
  if (!selectedCapabilityId || !visible.some(x => x.id === selectedCapabilityId)) {
    selectedCapabilityId = visible[0]?.id || "";
  }
  renderCapabilityDetail();
}
function renderCapabilityDetail() {
  const capability = CATALOG.find(x => x.id === selectedCapabilityId);
  const detail = $("capDetail");
  if (!capability) {
    detail.innerHTML = '<div class="empty">В нативном каталоге нет доступных записей.</div>';
    return;
  }
  const installed = !!state?.caps?.includes(capability.id);
  const dependencies = textArray(capability.required).map(id => CATALOG.find(x => x.id === id)?.name || id);
  const incompatible = textArray(capability.incompatible).map(id => CATALOG.find(x => x.id === id)?.name || id);
  const schema = capability.settingsSchema || [];
  detail.innerHTML = '<div class="detail-icon">' + capabilityCategoryEmoji(capability.category) + '</div><h2 class="detail-title">' + esc(capability.name) + '</h2><div class="chip">' + esc(capability.id) + '</div>' +
    '<p class="detail-desc">' + esc(capability.description) + '</p>' +
    '<div class="property-row"><span>Категория</span><b>' + esc(capability.category) + '</b></div>' +
    '<div class="property-row"><span>Статус</span><b class="' + (capability.status === "Работает" ? "status-ready" : "status-wip") + '">' + esc(capability.status) + '</b></div>' +
    '<div class="property-row"><span>Область</span><b>' + esc(capability.executionScope || "не указана") + '</b></div>' +
    '<div class="property-row"><span>Реализация</span><b>' + esc(capability.implementationType || "не указана") + '</b></div>' +
    '<div class="property-row"><span>Компоненты</span><b>' + esc((capability.componentIds || []).join(", ") || "Только данные") + '</b></div>' +
    '<div class="property-row"><span>В объекте</span><b>' + (installed ? "Подключена" : "Не подключена") + '</b></div>' +
    (dependencies.length ? '<div class="mini-title">ОБЯЗАТЕЛЬНЫЕ ЗАВИСИМОСТИ</div><p class="detail-desc">' + dependencies.map(esc).join(" · ") + '</p>' : '') +
    (incompatible.length ? '<div class="mini-title">НЕСОВМЕСТИМОСТЬ</div><p class="detail-desc">' + incompatible.map(esc).join(" · ") + '</p>' : '') +
    '<div class="detail-actions">' + (installed
      ? '<button class="btn danger" id="capToggle">Отключить</button>'
      : '<button class="btn primary" id="capToggle" ' + (capability.status === "Работает" && state ? "" : "disabled") + '>＋ Подключить</button>') +
    '<button class="btn" id="capCopy">Копировать ID</button></div>' +
    '<div class="mini-title">ПАРАМЕТРЫ МЕХАНИКИ <small>' + schema.length + '</small></div>' +
    (schema.length ? schema.map(d => '<div class="property-row"><span>' + esc(d.display_name || d.setting_key || d.key) + '</span><b>' + esc(d.value_type || "") + (d.unit ? " · " + esc(d.unit) : "") + '</b></div>').join("") : '<div class="empty compact-empty">У этой возможности нет пользовательских параметров.</div>') +
    '<p class="detail-desc">Настройки загружаются из ObjectCapabilityCatalog и сохраняются в ObjectCapabilitySelection. Недоступные возможности нельзя подключить.</p>';
  $("capToggle").onclick = () => toggleCapability(capability.id,!installed);
  $("capCopy").onclick = () => navigator.clipboard?.writeText(capability.id).then(() => toast("ID скопирован."));
}
function renderLibrary() {
  const query = templateSearch.trim().toLowerCase();
  const categories = [...new Set(templates.map(x => x.category || "Без категории"))].sort((a,b) => a.localeCompare(b,"ru"));
  const types = [...new Set(templates.map(x => x.type).filter(Boolean))].sort((a,b) => a.localeCompare(b,"ru"));
  const subcategories = [...new Set(templates.map(x => x.subcategory).filter(Boolean))].sort((a,b) => a.localeCompare(b,"ru"));
  const profileCards = creationProfiles.filter(profile =>
    !query || (profile.name + " " + profile.description + " " + profile.id).toLowerCase().includes(query)
  );
  const visibleTemplates = templates.filter(template =>
    (templateCategory === "Все" || (template.category || "Без категории") === templateCategory) &&
    (templateType === "Все" || template.type === templateType) &&
    (templateSubcategory === "Все" || template.subcategory === templateSubcategory) &&
    (!query || (template.name + " " + template.description + " " + template.category + " " + template.subcategory + " " + template.type).toLowerCase().includes(query))
  );

  $("templateCategories").innerHTML =
    '<div class="side-title">ПРОФИЛИ СОЗДАНИЯ <span class="count">' + creationProfiles.length + '</span></div>' +
    profileCards.map(profile =>
      '<button class="sideitem" type="button" data-create-profile="' + esc(profile.id) + '"><span><i class="sideicon">' + creationProfileEmoji(profile) + '</i>' + esc(profile.name) + '</span><span class="count">' + esc(profile.rootType) + '</span></button>'
    ).join("") +
    '<div class="side-title">ГОТОВЫЕ ШАБЛОНЫ <span class="count">' + templates.length + '</span></div>' +
    '<button class="template-filter ' + (templateCategory === "Все" ? "active" : "") + '" type="button" data-template-category="Все"><span>◇ Все шаблоны</span><small>' + templates.length + '</small></button>' +
    categories.map(category =>
      '<button class="template-filter ' + (templateCategory === category ? "active" : "") + '" type="button" data-template-category="' + esc(category) + '"><span><i class="sideicon">' + templateCategoryEmoji(category) + '</i>' + esc(category) + '</span><small>' + templates.filter(x => (x.category || "Без категории") === category).length + '</small></button>'
    ).join("");

  $("templateCategories").querySelectorAll("[data-create-profile]").forEach(button => button.onclick = () =>
    createFromProfile(button.dataset.createProfile, creationProfiles.find(x => x.id === button.dataset.createProfile)?.name)
  );
  $("templateCategories").querySelectorAll("[data-template-category]").forEach(button => button.onclick = () => {
    templateCategory = button.dataset.templateCategory;
    renderLibrary();
  });

  const typeSelect = $("templateTypes");
  if (typeSelect) {
    typeSelect.innerHTML = '<option value="Все">Все типы</option>' + types.map(type =>
      '<option value="' + esc(type) + '">' + esc(type) + '</option>'
    ).join("");
    typeSelect.value = types.includes(templateType) ? templateType : "Все";
    if (typeSelect.value !== templateType) templateType = "Все";
  }
  const subcategorySelect = $("templateSubcategories");
  if (subcategorySelect) {
    subcategorySelect.innerHTML = '<option value="Все">Все подкатегории</option>' + subcategories.map(value =>
      '<option value="' + esc(value) + '">' + esc(value) + '</option>'
    ).join("");
    subcategorySelect.value = subcategories.includes(templateSubcategory) ? templateSubcategory : "Все";
    if (subcategorySelect.value !== templateSubcategory) templateSubcategory = "Все";
  }
  if ($("templateSearch").value !== templateSearch) $("templateSearch").value = templateSearch;
  $("templateCount").textContent = profileCards.length + " профилей создания · " + visibleTemplates.length + " из " + templates.length + " шаблонов";

  const profileSection = '<section class="template-section"><header class="template-section-head"><div><span class="eyebrow">NATIVE CREATION PROFILES</span><h2>Профили создания</h2></div><span class="section-count">' + profileCards.length + '</span></header>' +
    '<div class="library-grid profile-grid">' + (profileCards.length ? profileCards.map(profile =>
      '<article class="template profile-template"><div class="template-top"><span class="template-preview"><span class="emoji">' + creationProfileEmoji(profile) + '</span></span><span class="template-kind">' + esc(profile.rootType) + '</span></div>' +
      '<h3>' + esc(profile.name) + '</h3><p>' + esc(profile.description) + '</p><div class="template-classification">' + esc(profile.category) + '</div>' +
      '<div class="template-meta"><span class="chip">' + (profile.capabilities || []).length + ' рекомендуемых механик</span><button class="btn primary small" type="button" data-profile-create="' + esc(profile.id) + '">Создать →</button></div></article>'
    ).join("") : '<div class="empty">Профили не найдены.</div>') + '</div></section>';

  const templateSection = '<section class="template-section"><header class="template-section-head"><div><span class="eyebrow">OBJECT TEMPLATE LIBRARY</span><h2>Готовые шаблоны</h2></div><span class="section-count">' + visibleTemplates.length + ' / ' + templates.length + '</span></header>' +
    '<div class="library-grid template-grid">' + (visibleTemplates.length ? visibleTemplates.map(template => {
      const builtin = !!template.builtin;
      const badge = builtin ? "ВСТРОЕННЫЙ" : "СОХРАНЁННЫЙ";
      const emoji = template.emoji || "◆";
      const mechanics = (template.caps || []).length;
      return '<article class="template object-template"><div class="template-top"><span class="template-preview" title="Временная иконка до добавления спрайта"><span class="emoji">' + esc(emoji) + '</span></span><span class="template-kind">' + esc(template.type || template.nativeRootType || "Объект") + '</span></div>' +
        '<div class="template-badges"><span class="template-origin ' + (builtin ? "builtin" : "saved") + '">' + badge + '</span><span class="count">' + esc(template.nativeRootType || "") + '</span></div>' +
        '<h3>' + esc(template.name) + '</h3><p>' + esc(template.description) + '</p>' +
        '<div class="template-classification">' + esc(template.category || "Без категории") + (template.subcategory ? " / " + esc(template.subcategory) : "") + '</div>' +
        '<div class="template-meta"><span class="chip">' + mechanics + ' механик</span><span class="template-open">Создать копию →</span></div>' +
        '<div class="template-actions">' + (builtin ? "" : '<button class="btn small" type="button" data-template-classify="' + esc(template.objectId) + '">Категория</button>') +
        '<button class="btn primary small" type="button" data-template-create="' + esc(template.objectId) + '">Создать</button></div></article>';
    }).join("") : '<div class="empty">Шаблоны по выбранным фильтрам не найдены.</div>') + '</div></section>';

  $("templateGrid").innerHTML = profileSection + templateSection;
  $("templateGrid").querySelectorAll("[data-profile-create]").forEach(button => button.onclick = () =>
    createFromProfile(button.dataset.profileCreate, creationProfiles.find(x => x.id === button.dataset.profileCreate)?.name)
  );
  $("templateGrid").querySelectorAll("[data-template-create]").forEach(button => button.onclick = () => createFromTemplate(button.dataset.templateCreate));
  $("templateGrid").querySelectorAll("[data-template-classify]").forEach(button => button.onclick = () => classifyTemplate(button.dataset.templateClassify));
}
function renderProjectLibrary() {
  const query = projectSearch.trim().toLowerCase();
  const visible = projectObjects.filter(item =>
    (projectCategory === "Все" || item.category === projectCategory) &&
    (projectType === "Все" || item.type === projectType) &&
    (projectSubcategory === "Все" || item.subcategory === projectSubcategory) &&
    (projectRelation === "Все" || item.relations.some(relation => relation.kind === projectRelation)) &&
    (projectMechanic === "Все" || item.caps.includes(projectMechanic) || item.relations.some(relation => relation.mechanic_id === projectMechanic)) &&
    (projectMode !== "Избранное" || favoriteIds.includes(item.objectId)) &&
    (projectMode !== "Недавние" || recentIds.includes(item.objectId)) &&
    (projectCollection === "Все" || textArray(collections[projectCollection]?.object_ids).includes(item.objectId)) &&
    (!query || (item.name + " " + item.description + " " + item.category + " " + item.subcategory + " " + item.caps.join(" ") + " " + item.relations.map(x => x.label).join(" ")).toLowerCase().includes(query))
  );
  visible.sort((a,b) => {
    if (projectSort === "name") return a.name.localeCompare(b.name,"ru");
    if (projectSort === "objects") return b.relations.length - a.relations.length;
    const recentA = recentIds.indexOf(a.objectId);
    const recentB = recentIds.indexOf(b.objectId);
    return (recentA < 0 ? Number.MAX_SAFE_INTEGER : recentA) - (recentB < 0 ? Number.MAX_SAFE_INTEGER : recentB);
  });
  $("projectLibraryCount").textContent = projectObjects.length + " объектов";
  $("projectLibrarySummary").textContent = visible.length + " из " + projectObjects.length + " отдельных ObjectDefinition";
  $("projectIntegrityReport").innerHTML = "";
  const modeOptions = ["Все","Избранное","Недавние"].map(mode => '<button class="sideitem ' + (projectMode === mode ? "active" : "") + '" data-project-mode="' + esc(mode) + '"><span>' + (mode === "Избранное" ? "★ " : mode === "Недавние" ? "◷ " : "▦ ") + esc(mode) + '</span></button>').join("");
  const categoryOptions = ["Все",...categories].map(x => '<button class="sideitem ' + (projectCategory === x ? "active" : "") + '" data-project-category="' + esc(x) + '"><span>' + esc(x) + '</span><span class="count">' + (x === "Все" ? projectObjects.length : projectObjects.filter(o => o.category === x).length) + '</span></button>').join("");
  const collectionRows = Object.entries(collections).map(([id,collection]) => {
    const count = textArray(collection.object_ids).length;
    return '<div class="collection-side-row"><button class="sideitem ' + (projectCollection === id ? "active" : "") + '" data-collection-filter="' + esc(id) + '"><span>▣ ' + esc(collection.name || id) + '</span><span class="count">' + count + '</span></button><button class="collection-side-action" type="button" data-collection-rename="' + esc(id) + '" title="Переименовать">✎</button><button class="collection-side-action danger" type="button" data-collection-delete="' + esc(id) + '" title="Удалить">×</button></div>';
  }).join("");
  $("projectLibraryCategories").innerHTML = '<div class="side-title">БИБЛИОТЕКА</div>' + modeOptions +
    '<div class="side-title">КАТЕГОРИИ</div>' + categoryOptions +
    '<div class="library-category-actions"><button class="btn small" id="categoryAdd">＋ Категория</button>' + (projectCategory !== "Все" ? '<button class="btn small" id="categoryRename">Переименовать</button><button class="btn small danger" id="categoryDelete">Удалить</button>' : '') + '</div>' +
    '<div class="side-title">КОЛЛЕКЦИИ</div>' + collectionRows +
    '<button class="btn small" id="collectionAdd">＋ Новая коллекция</button>';
  $("projectLibraryCategories").querySelectorAll("[data-project-mode]").forEach(button => button.onclick = () => { projectMode = button.dataset.projectMode; projectCollection = "Все"; renderProjectLibrary(); });
  $("projectLibraryCategories").querySelectorAll("[data-project-category]").forEach(button => button.onclick = () => { projectCategory = button.dataset.projectCategory; projectCollection = "Все"; projectMode = "Все"; renderProjectLibrary(); });
  $("projectLibraryCategories").querySelectorAll("[data-collection-filter]").forEach(button => button.onclick = () => { projectCollection = button.dataset.collectionFilter; projectMode = "Все"; renderProjectLibrary(); });
  $("projectLibraryCategories").querySelectorAll("[data-collection-rename]").forEach(button => button.onclick = () => {
    const collection = collections[button.dataset.collectionRename];
    const name = window.prompt("Название коллекции:", collection?.name || "");
    if (name && name.trim()) updateCollection(button.dataset.collectionRename,{name:name.trim()});
  });
  $("projectLibraryCategories").querySelectorAll("[data-collection-delete]").forEach(button => button.onclick = () => deleteCollection(button.dataset.collectionDelete));
  $("collectionAdd").onclick = () => {
    const name = window.prompt("Название новой коллекции:");
    if (name && name.trim()) createCollection(name.trim());
  };
  $("categoryAdd").onclick = () => {
    const name = window.prompt("Название новой категории:");
    if (name) addCategory(name);
  };
  $("categoryRename")?.addEventListener("click",() => renameCategory(projectCategory));
  $("categoryDelete")?.addEventListener("click",() => deleteCategory(projectCategory));
  $("projectLibraryType").innerHTML = '<option value="Все">Все типы</option>' + [...new Set(projectObjects.map(x => x.type))].map(x => '<option ' + (projectType === x ? "selected" : "") + '>' + esc(x) + '</option>').join("");
  $("projectLibrarySubcategory").innerHTML = '<option value="Все">Все подкатегории</option>' + [...new Set(projectObjects.map(x => x.subcategory).filter(Boolean))].map(x => '<option ' + (projectSubcategory === x ? "selected" : "") + '>' + esc(x) + '</option>').join("");
  $("projectLibraryType").onchange = e => { projectType = e.target.value; renderProjectLibrary(); };
  $("projectLibrarySubcategory").onchange = e => { projectSubcategory = e.target.value; renderProjectLibrary(); };
  $("projectLibraryRelation").innerHTML = '<option value="Все">Все типы связей</option>' + [...new Set(projectObjects.flatMap(x => x.relations.map(r => r.kind)))].map(x => '<option value="' + esc(x) + '" ' + (projectRelation === x ? "selected" : "") + '>' + esc(x) + '</option>').join("");
  $("projectLibraryMechanic").innerHTML = '<option value="Все">Все механики</option>' + [...new Set(projectObjects.flatMap(x => [...x.caps, ...x.relations.map(r => r.mechanic_id).filter(Boolean)]))].map(x => '<option value="' + esc(x) + '" ' + (projectMechanic === x ? "selected" : "") + '>' + esc(CATALOG.find(c => c.id === x)?.name || x) + '</option>').join("");
  $("projectLibraryRelation").onchange = e => { projectRelation = e.target.value; renderProjectLibrary(); };
  $("projectLibraryMechanic").onchange = e => { projectMechanic = e.target.value; renderProjectLibrary(); };
  $("projectLibrarySort").value = projectSort;
  $("projectLibrarySort").onchange = e => { projectSort = e.target.value; renderProjectLibrary(); };
  $("projectLibrarySearch").value = projectSearch;
  $("projectLibrarySearch").oninput = e => { projectSearch = e.target.value; renderProjectLibrary(); };
  $("projectLibraryGrid").innerHTML = visible.map(item => {
    const incoming = projectObjects.filter(source => source.relations.some(r => r.target_object_id === item.objectId)).length;
    const relationNames = item.relations.map(r => {
      const target = projectObjects.find(x => x.objectId === r.target_object_id);
      return target ? target.name : "Не найдено: " + r.target_object_id;
    });
    const memberCollections = Object.entries(collections).filter(([,collection]) => textArray(collection.object_ids).includes(item.objectId));
    return '<article class="library-item"><div class="library-item-header"><span class="emoji">' + esc(item.emoji) + '</span><span class="template-kind">' + esc(item.type) + '</span><button class="btn small" data-favorite="' + esc(item.objectId) + '">' + (favoriteIds.includes(item.objectId) ? "★" : "☆") + '</button></div>' +
      '<h3>' + esc(item.name) + '</h3><p>' + esc(item.description) + '</p><div class="template-classification">' + esc(item.category) + (item.subcategory ? " / " + esc(item.subcategory) : "") + '</div>' +
      '<div class="library-item-meta"><span class="chip">' + item.caps.length + ' механик</span><span class="chip">' + item.parts.length + ' узлов</span><span class="chip">' + item.relations.length + ' связей</span><span class="chip">' + incoming + ' входящих</span></div>' +
      (relationNames.length ? '<div class="library-chip-list">' + relationNames.map(x => '<span class="library-chip">' + esc(x) + '</span>').join("") + '</div>' : '') +
      (memberCollections.length ? '<div class="library-memberships">' + memberCollections.map(([id,collection]) => '<button class="library-membership" type="button" data-collection-remove="' + esc(id) + '" data-collection-object="' + esc(item.objectId) + '" title="Убрать только из коллекции">' + esc(collection.name || id) + ' ×</button>').join("") + '</div>' : '') +
      '<div class="library-item-footer"><button class="btn small" data-collection-add="' + esc(item.objectId) + '">В коллекцию</button><button class="btn small primary" data-object-open="' + esc(item.objectId) + '">Открыть</button><button class="btn small" data-object-duplicate="' + esc(item.objectId) + '">Копия</button><button class="btn small" data-object-template="' + esc(item.objectId) + '">Шаблон</button><button class="btn small danger" data-object-delete="' + esc(item.objectId) + '">Удалить</button></div></article>';
  }).join("") || '<div class="library-empty"><strong>Библиотека пуста</strong><span>Сохрани объект из редактора, чтобы добавить его в нативную библиотеку.</span></div>';
  $("projectLibraryGrid").querySelectorAll("[data-collection-remove]").forEach(button => button.onclick = () => {
    updateCollection(button.dataset.collectionRemove,{object_id:button.dataset.collectionObject,remove:true});
  });
  $("projectLibraryGrid").querySelectorAll("[data-collection-add]").forEach(button => button.onclick = () => {
    const options = Object.entries(collections).map(([id,collection]) => ({value:id,label:collection.name || id}));
    if (!options.length) return toast("Сначала создай коллекцию слева.");
    openForm({
      eyebrow:"OBJECT LIBRARY / COLLECTIONS",
      title:"Добавить объект в коллекцию",
      fields:[{key:"collection_id",label:"Коллекция",type:"select",value:options[0].value,options}],
      onSubmit: values => updateCollection(values.collection_id,{object_id:button.dataset.collectionAdd})
    });
  });
  $("projectLibraryGrid").querySelectorAll("[data-object-open]").forEach(button => button.onclick = () => openObject(button.dataset.objectOpen));
  $("projectLibraryGrid").querySelectorAll("[data-object-duplicate]").forEach(button => button.onclick = () => duplicateObject(button.dataset.objectDuplicate));
  $("projectLibraryGrid").querySelectorAll("[data-object-template]").forEach(button => button.onclick = () => createTemplate(button.dataset.objectTemplate));
  $("projectLibraryGrid").querySelectorAll("[data-object-delete]").forEach(button => button.onclick = () => deleteObject(button.dataset.objectDelete));
  $("projectLibraryGrid").querySelectorAll("[data-favorite]").forEach(button => button.onclick = () => toggleFavorite(button.dataset.favorite));
}
function openCreate() {
  selectedProfileId = creationProfiles.some(x => x.id === "other") ? "other" : (creationProfiles[0]?.id || "");
  $("createName").value = "Новый объект";
  $("createTypeGrid").innerHTML = creationProfiles.map(profile =>
    '<button type="button" class="type-option ' + (profile.id === selectedProfileId ? "active" : "") + '" data-profile="' + esc(profile.id) + '"><span>✦</span>' + esc(profile.name) + '<small>' + esc(profile.rootType) + '</small></button>'
  ).join("");
  $("createTypeGrid").querySelectorAll("[data-profile]").forEach(button => button.onclick = () => {
    selectedProfileId = button.dataset.profile;
    $("createTypeGrid").querySelectorAll("[data-profile]").forEach(x => x.classList.toggle("active",x === button));
  });
  $("createModal").classList.add("open");
}
function bind() {
  document.querySelectorAll("[data-view]").forEach(button => button.onclick = () => setView(button.dataset.view));
  $("newObject").onclick = openCreate;
  $("openObjectLibrary").onclick = async () => {
    try {
      await host.request("object_library_open");
      toast("Открыта панель «Библиотека объектов» в Godot.");
    } catch (error) { toast(error.message,true); }
  };
  $("createClose").onclick = () => $("createModal").classList.remove("open");
  $("createConfirm").onclick = () => createFromProfile(selectedProfileId,$("createName").value.trim());
  $("saveCurrentObject").onclick = saveCurrentObject;
  $("saveCurrentObjectAs").onclick = saveCurrentObjectAs;
  $("confirmLibrarySave").onclick = confirmLibrarySave;
  $("addToLibrary").onclick = () => state ? createTemplate(state.objectId) : null;
  $("undo").onclick = undo;
  $("redo").onclick = redo;
  $("catalogSearch").oninput = e => { capSearch = e.target.value; renderCatalog(); };
  $("capFilter").onchange = e => { capFilter = e.target.value; renderCatalog(); };
  $("templateSearch").oninput = e => { templateSearch = e.target.value; renderLibrary(); };
  $("templateTypes").onchange = e => { templateType = e.target.value; renderLibrary(); };
  $("templateSubcategories").onchange = e => { templateSubcategory = e.target.value; renderLibrary(); };
  $("projectLibrarySearch").oninput = e => { projectSearch = e.target.value; renderProjectLibrary(); };
  $("saveObject").onclick = exportObject;
  $("importObject").hidden = false;
  $("importObject").textContent = "Импорт сцены";
  $("importObject").onclick = async () => {
    try {
      const result = await host.request("scene_import_request");
      if (result.working) {
        hydrateWorking(result.working);
        undoStack = [clone(state)];
        redoStack = [];
        setView("workspace");
        toast("Сцена импортирована в новый черновик. Исходная сцена не изменена.");
      }
    } catch (error) {
      if (error.message !== "Импорт сцены отменён.") toast(error.message, true);
    }
  };
  $("importFile").hidden = true;
  $("uploadSprite").hidden = false;
  $("uploadSprite").textContent = "▧ Спрайт";
  $("uploadSprite").onclick = () => $("spriteFile").click();
  $("spriteFile").accept = "image/png,image/jpeg,image/webp";
  $("spriteFile").onchange = event => {
    const selected = event.target.files?.[0];
    importSprite(selected);
    event.target.value = "";
  };
  $("gridToggle").onclick = () => { window._obGrid = window._obGrid === false; $("gridToggle").classList.toggle("active",window._obGrid !== false); renderCanvas(); };
  $("zoomIn").onclick = () => { window._obZoom = Math.min(160,(window._obZoom || 100) + 10); renderCanvas(); };
  $("zoomOut").onclick = () => { window._obZoom = Math.max(50,(window._obZoom || 100) - 10); renderCanvas(); };
  $("leftEditorNav")?.querySelectorAll("[data-left-tab]").forEach(button =>
    button.onclick = () => setLeftEditorTab(button.dataset.leftTab)
  );
  $("inspectorTabs").querySelectorAll("[data-tab]").forEach(button => button.onclick = () => setInspectorTab(button.dataset.tab));
  $("clearLibraryFilters").onclick = () => { projectSearch = "";projectCategory = projectType = projectSubcategory = projectRelation = projectMechanic = projectCollection = projectMode = "Все";projectSort = "name";renderProjectLibrary(); };
  document.querySelectorAll("[data-close-modal]").forEach(button => button.onclick = () => $(button.dataset.closeModal)?.classList.remove("open"));
  $("editorDialogClose").onclick = () => $("editorDialogModal").classList.remove("open");
  $("editorDialogCancel").onclick = () => $("editorDialogModal").classList.remove("open");
  document.addEventListener("keydown", event => {
    const mod = event.ctrlKey || event.metaKey;
    if (mod && event.shiftKey && event.key.toLowerCase() === "s") { event.preventDefault();saveCurrentObjectAs(); }
    else if (mod && event.key.toLowerCase() === "s") { event.preventDefault();saveCurrentObject(); }
    if (mod && event.key.toLowerCase() === "z" && !event.shiftKey) { event.preventDefault();undo(); }
    if (mod && (event.key.toLowerCase() === "y" || (event.key.toLowerCase() === "z" && event.shiftKey))) { event.preventDefault();redo(); }
  });
  const tab = $("inspectorTabs");
  if (tab && !tab.querySelector('[data-tab="Компоненты"]')) {
    const button = document.createElement("button");
    button.dataset.tab = "Компоненты";
    button.textContent = "Компоненты";
    tab.appendChild(button);
    button.onclick = () => setInspectorTab("Компоненты");
  }
}
async function undo() {
  if (!state || undoStack.length < 2) return;
  redoStack.push(clone(state));
  undoStack.pop();
  state = clone(undoStack[undoStack.length - 1]);
  state.saved = false;
  await syncNow();
  renderAll();
  toast("Изменение отменено.");
}
async function redo() {
  if (!state || !redoStack.length) return;
  const next = redoStack.pop();
  undoStack.push(clone(next));
  state = clone(next);
  state.saved = false;
  await syncNow();
  renderAll();
  toast("Изменение восстановлено.");
}
function exportObject() {
  if (!state) return toast("Нет объекта для экспорта.");
  const exportData = {
    format:"godot-object-definition-web-export",
    schema:6,
    object:clone(state),
    timestamp:new Date().toISOString()
  };
  const blob = new Blob([JSON.stringify(exportData,null,2)],{type:"application/json"});
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = (state.name.toLowerCase().replace(/[^a-z0-9а-яё]+/gi,"-") || "object") + ".object.json";
  anchor.click();
  window.setTimeout(() => URL.revokeObjectURL(url),1000);
  toast("Экспортирована резервная копия текущего определения.");
}
async function boot() {
  bind();
  if (!host?.isEmbedded) {
    document.body.innerHTML = '<main class="standalone-blocker"><h1>Web Object Builder</h1><p>Открой вкладку Web Object Builder внутри редактора Godot, чтобы работать с библиотекой, механиками и сценами.</p></main>';
    return;
  }
  try {
    const requestedObjectId = new URLSearchParams(window.location.search).get("open_object_id") || "";
    const result = await api("workspace_get_state");
    applyWorkspace(result.workspace);
    if (result.workspace?.working) applyWorking(result.workspace.working);
    setStatus("Подключено к Web Object Builder");
    renderAll();
    setView("workspace");
    if (requestedObjectId) await openObject(requestedObjectId);
    // The host waits for this handshake before sending the authoritative
    // workspace snapshot, so events cannot be lost during initial page load.
    host.send("frontend_ready", {});
  } catch (error) {
    setStatus(error.message,true);
    toast(error.message,true);
  }
}
boot();
