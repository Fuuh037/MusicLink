const localDatabaseKey = "music-link-database-v2";
const legacyArtistsKey = "music-link-artists";
const supabaseConfig = window.MUSIC_LINK_SUPABASE || {};
const isSupabaseConfigured = Boolean(
  window.supabase &&
  url: "https://escolarprojectmusiclink.netlify.app/",
  anonKey: "sb_publishable_pwUyG5OqkRcEBwmP-GkNJQ_6B_NG-Zm"
  supabaseConfig.url.startsWith("https://") &&
  supabaseConfig.anonKey.length > 20
);
const supabaseClient = isSupabaseConfigured
  ? window.supabase.createClient(supabaseConfig.url, supabaseConfig.anonKey)
  : null;

const demoCredentials = {
  admin: { email: "admin@musiclink.com", password: "admin123" },
  artista: { email: "luna@musiclink.com", password: "artista123" },
  comum: { email: "ouvinte@musiclink.com", password: "comum123" }
};

const starterDatabase = {
  activeUserId: null,
  users: [
    {
      id: "user-admin",
      name: "Admin Music Link",
      email: "admin@musiclink.com",
      password: "admin123",
      role: "admin"
    },
    {
      id: "user-luna",
      name: "Luna Alves",
      email: "luna@musiclink.com",
      password: "artista123",
      role: "artista"
    },
    {
      id: "user-ouvinte",
      name: "Usuário Ouvinte",
      email: "ouvinte@musiclink.com",
      password: "comum123",
      role: "comum"
    }
  ],
  artists: [
    {
      id: "artist-luna",
      ownerId: "user-luna",
      name: "Luna Alves",
      genre: "Pop",
      song: "Noites de Neon",
      bio: "Cantora independente com letras autorais e sonoridade moderna."
    },
    {
      id: "artist-rima",
      ownerId: "user-admin",
      name: "Rima Norte",
      genre: "Rap",
      song: "Cidade Acordada",
      bio: "Grupo de rap que mistura crítica social, batidas urbanas e poesia."
    },
    {
      id: "artist-horizonte",
      ownerId: "user-admin",
      name: "Banda Horizonte",
      genre: "Rock",
      song: "Estrada Livre",
      bio: "Quarteto de rock alternativo com shows autorais e energia de palco."
    }
  ]
};

const elements = {
  loginForm: document.querySelector("#loginForm"),
  loginRole: document.querySelector("#loginRole"),
  loginEmail: document.querySelector("#loginEmail"),
  loginPassword: document.querySelector("#loginPassword"),
  loginMessage: document.querySelector("#loginMessage"),
  logoutButton: document.querySelector("#logoutButton"),
  signupForm: document.querySelector("#signupForm"),
  signupName: document.querySelector("#signupName"),
  signupRole: document.querySelector("#signupRole"),
  signupEmail: document.querySelector("#signupEmail"),
  signupPassword: document.querySelector("#signupPassword"),
  signupMessage: document.querySelector("#signupMessage"),
  sessionBadge: document.querySelector("#sessionBadge"),
  backendBadge: document.querySelector("#backendBadge"),
  demoAccess: document.querySelector("#demoAccess"),
  formPanel: document.querySelector("#cadastro"),
  form: document.querySelector("#artistForm"),
  formTitle: document.querySelector("#formTitle"),
  artistId: document.querySelector("#artistId"),
  artistName: document.querySelector("#artistName"),
  artistGenre: document.querySelector("#artistGenre"),
  artistSong: document.querySelector("#artistSong"),
  artistBio: document.querySelector("#artistBio"),
  submitButton: document.querySelector("#submitButton"),
  cancelEditButton: document.querySelector("#cancelEditButton"),
  formMessage: document.querySelector("#formMessage"),
  permissionNote: document.querySelector("#permissionNote"),
  artistCount: document.querySelector("#artistCount"),
  userCount: document.querySelector("#userCount"),
  genreCount: document.querySelector("#genreCount"),
  modal: document.querySelector("#artistModal"),
  openGalleryButton: document.querySelector("#openGalleryButton"),
  closeGalleryButton: document.querySelector("#closeGalleryButton"),
  previousArtistButton: document.querySelector("#previousArtistButton"),
  nextArtistButton: document.querySelector("#nextArtistButton"),
  editArtistButton: document.querySelector("#editArtistButton"),
  artistSearch: document.querySelector("#artistSearch"),
  profileCard: document.querySelector("#profileCard"),
  profilePosition: document.querySelector("#profilePosition"),
  demoButtons: document.querySelectorAll("[data-demo]")
};

let database = isSupabaseConfigured ? null : loadLocalDatabase();
let activeProfile = null;
let artists = [];
let stats = { userCount: 0 };
let currentIndex = 0;
let searchTerm = "";

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function createId(prefix) {
  if (crypto.randomUUID) {
    return `${prefix}-${crypto.randomUUID()}`;
  }

  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
}

function cleanText(value) {
  return String(value).trim().replace(/\s+/g, " ");
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function showMessage(target, message) {
  target.textContent = message;
}

function getRoleName(role) {
  const names = {
    admin: "Administrador",
    artista: "Artista",
    comum: "Usuário comum"
  };

  return names[role] || "Visitante";
}

function loadLocalDatabase() {
  const savedDatabase = localStorage.getItem(localDatabaseKey);

  if (savedDatabase) {
    try {
      const parsedDatabase = normalizeLocalDatabase(JSON.parse(savedDatabase));
      localStorage.setItem(localDatabaseKey, JSON.stringify(parsedDatabase));
      return parsedDatabase;
    } catch {
      localStorage.removeItem(localDatabaseKey);
    }
  }

  const databaseSeed = clone(starterDatabase);
  const legacyArtists = localStorage.getItem(legacyArtistsKey);

  if (legacyArtists) {
    try {
      const parsedArtists = JSON.parse(legacyArtists);
      databaseSeed.artists = parsedArtists.map((artist) => ({
        id: artist.id || createId("artist"),
        ownerId: artist.name === "Luna Alves" ? "user-luna" : "user-admin",
        name: artist.name,
        genre: artist.genre,
        song: artist.song,
        bio: artist.bio
      }));
    } catch {
      databaseSeed.artists = clone(starterDatabase.artists);
    }
  }

  localStorage.setItem(localDatabaseKey, JSON.stringify(databaseSeed));
  return databaseSeed;
}

function normalizeLocalDatabase(databaseValue) {
  const safeDatabase = {
    activeUserId: databaseValue.activeUserId || null,
    users: Array.isArray(databaseValue.users) ? databaseValue.users : [],
    artists: Array.isArray(databaseValue.artists) ? databaseValue.artists : []
  };

  starterDatabase.users.forEach((starterUser) => {
    const hasUser = safeDatabase.users.some((user) => user.id === starterUser.id);

    if (!hasUser) {
      safeDatabase.users.push(starterUser);
    }
  });

  safeDatabase.artists = safeDatabase.artists.map((artist) => ({
    id: artist.id || createId("artist"),
    ownerId: artist.name === "Luna Alves" ? "user-luna" : artist.ownerId || "user-admin",
    name: artist.name || "Artista sem nome",
    genre: artist.genre || "Outro",
    song: artist.song || "Música não informada",
    bio: artist.bio || "Bio ainda não cadastrada."
  }));

  return safeDatabase;
}

function saveLocalDatabase() {
  localStorage.setItem(localDatabaseKey, JSON.stringify(database));
}

function syncLocalState() {
  activeProfile = database.users.find((user) => user.id === database.activeUserId) || null;
  artists = database.artists.map((artist) => ({
    ...artist,
    ownerName: database.users.find((user) => user.id === artist.ownerId)?.name || "Music Link"
  }));
  stats.userCount = database.users.length;
}

async function loadRemoteProfile(userId) {
  const { data, error } = await supabaseClient
    .from("profiles")
    .select("id, name, role")
    .eq("id", userId)
    .single();

  if (error) {
    activeProfile = null;
    showMessage(elements.loginMessage, "Conta autenticada, mas o perfil ainda não foi encontrado no banco.");
    return;
  }

  activeProfile = data;
}

async function loadRemoteArtists() {
  let response = await supabaseClient
    .from("artists")
    .select("id, owner_id, name, genre, song, bio, profiles(name)")
    .order("created_at", { ascending: false });

  if (response.error) {
    response = await supabaseClient
      .from("artists")
      .select("id, owner_id, name, genre, song, bio")
      .order("created_at", { ascending: false });
  }

  if (response.error) {
    artists = [];
    showMessage(elements.loginMessage, "Não foi possível carregar os artistas do banco remoto.");
    return;
  }

  artists = response.data.map((artist) => ({
    id: artist.id,
    ownerId: artist.owner_id,
    name: artist.name,
    genre: artist.genre,
    song: artist.song,
    bio: artist.bio,
    ownerName: artist.profiles?.name || "Music Link"
  }));
}

async function loadRemoteUserCount() {
  const { count, error } = await supabaseClient
    .from("profiles")
    .select("id", { count: "exact", head: true });

  stats.userCount = error ? "Remoto" : count;
}

async function syncRemoteState() {
  const { data } = await supabaseClient.auth.getSession();
  const user = data.session?.user || null;

  if (user) {
    await loadRemoteProfile(user.id);
  } else {
    activeProfile = null;
  }

  await loadRemoteArtists();
  await loadRemoteUserCount();
}

function getInitials(name) {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0].toUpperCase())
    .join("");
}

function canCreateArtist() {
  return Boolean(activeProfile && ["admin", "artista"].includes(activeProfile.role));
}

function canManageArtist(artist) {
  if (!activeProfile) {
    return false;
  }

  return activeProfile.role === "admin" || (
    activeProfile.role === "artista" &&
    artist.ownerId === activeProfile.id
  );
}

function getFilteredArtists() {
  const normalizedSearch = searchTerm.trim().toLowerCase();

  if (!normalizedSearch) {
    return artists;
  }

  return artists.filter((artist) => {
    const searchableText = `${artist.name} ${artist.genre} ${artist.song} ${artist.bio}`.toLowerCase();
    return searchableText.includes(normalizedSearch);
  });
}

function updateSummary() {
  const genres = new Set(artists.map((artist) => artist.genre));
  elements.artistCount.textContent = artists.length;
  elements.userCount.textContent = stats.userCount;
  elements.genreCount.textContent = genres.size;
}

function updateBackendStatus() {
  elements.backendBadge.textContent = isSupabaseConfigured ? "Supabase remoto" : "Banco local de teste";
  elements.demoAccess.classList.toggle("hidden", isSupabaseConfigured);
}

function updateSession() {
  if (!activeProfile) {
    elements.sessionBadge.textContent = "Visitante";
    elements.logoutButton.classList.add("hidden");
    elements.formPanel.classList.add("locked");
    elements.permissionNote.textContent = "Faça login como administrador ou artista para cadastrar e alterar perfis.";
    resetForm();
    return;
  }

  elements.sessionBadge.textContent = `${getRoleName(activeProfile.role)}: ${activeProfile.name}`;
  elements.logoutButton.classList.remove("hidden");

  if (canCreateArtist()) {
    elements.formPanel.classList.remove("locked");
    elements.permissionNote.textContent = activeProfile.role === "admin"
      ? "Você pode cadastrar artistas e alterar qualquer perfil."
      : "Você pode cadastrar artistas e alterar apenas os seus próprios perfis.";
  } else {
    elements.formPanel.classList.add("locked");
    elements.permissionNote.textContent = "Usuários comuns podem visualizar artistas, mas não podem alterar cadastros.";
    resetForm();
  }
}

function renderProfile() {
  const visibleArtists = getFilteredArtists();

  if (currentIndex >= visibleArtists.length) {
    currentIndex = 0;
  }

  if (visibleArtists.length === 0) {
    elements.profileCard.innerHTML = `
      <div class="empty-state">
        <div>
          <h3>Nenhum artista encontrado.</h3>
          <p>Cadastre um artista ou tente outra pesquisa.</p>
        </div>
      </div>
    `;
    elements.profilePosition.textContent = "0 de 0";
    elements.editArtistButton.disabled = true;
    return;
  }

  const artist = visibleArtists[currentIndex];
  const safeArtist = {
    name: escapeHtml(artist.name),
    genre: escapeHtml(artist.genre),
    song: escapeHtml(artist.song),
    bio: escapeHtml(artist.bio),
    owner: escapeHtml(artist.ownerName || "Music Link")
  };

  elements.profileCard.innerHTML = `
    <div class="profile-head">
      <div class="avatar" aria-hidden="true">${getInitials(artist.name)}</div>
      <div>
        <h3>${safeArtist.name}</h3>
        <span class="genre-pill">${safeArtist.genre}</span>
      </div>
    </div>
    <p class="song-label">Música principal</p>
    <p class="song-title">${safeArtist.song}</p>
    <p class="profile-bio">${safeArtist.bio}</p>
    <p class="profile-owner">Responsável pelo cadastro: ${safeArtist.owner}</p>
  `;

  elements.profilePosition.textContent = `${currentIndex + 1} de ${visibleArtists.length}`;
  elements.editArtistButton.disabled = !canManageArtist(artist);
}

function resetForm() {
  elements.form.reset();
  elements.artistId.value = "";
  elements.formTitle.textContent = "Cadastrar artista";
  elements.submitButton.textContent = "Salvar artista";
  elements.cancelEditButton.classList.add("hidden");
}

function getArtistFormData() {
  const name = cleanText(elements.artistName.value);
  const genre = cleanText(elements.artistGenre.value);
  const song = cleanText(elements.artistSong.value);
  const bio = cleanText(elements.artistBio.value);

  if (name.length < 2 || name.length > 80) {
    showMessage(elements.formMessage, "O nome deve ter entre 2 e 80 caracteres.");
    return null;
  }

  if (!genre) {
    showMessage(elements.formMessage, "Selecione um gênero musical.");
    return null;
  }

  if (song.length < 2 || song.length > 100) {
    showMessage(elements.formMessage, "O nome da música deve ter entre 2 e 100 caracteres.");
    return null;
  }

  if (bio.length < 10 || bio.length > 500) {
    showMessage(elements.formMessage, "A bio deve ter entre 10 e 500 caracteres.");
    return null;
  }

  return {
    id: elements.artistId.value,
    name,
    genre,
    song,
    bio
  };
}

function openGallery() {
  document.body.classList.add("modal-open");
  elements.modal.classList.remove("hidden");
  elements.artistSearch.focus();
  renderProfile();
}

function closeGallery() {
  document.body.classList.remove("modal-open");
  elements.modal.classList.add("hidden");
}

function moveProfile(direction) {
  const visibleArtists = getFilteredArtists();

  if (visibleArtists.length === 0) {
    return;
  }

  currentIndex = (currentIndex + direction + visibleArtists.length) % visibleArtists.length;
  renderProfile();
}

function editCurrentArtist() {
  const visibleArtists = getFilteredArtists();
  const artist = visibleArtists[currentIndex];

  if (!artist || !canManageArtist(artist)) {
    showMessage(elements.loginMessage, "Este login não tem permissão para alterar esse artista.");
    return;
  }

  elements.artistId.value = artist.id;
  elements.artistName.value = artist.name;
  elements.artistGenre.value = artist.genre;
  elements.artistSong.value = artist.song;
  elements.artistBio.value = artist.bio;
  elements.formTitle.textContent = "Alterar artista";
  elements.submitButton.textContent = "Salvar alterações";
  elements.cancelEditButton.classList.remove("hidden");
  closeGallery();
  elements.artistName.focus();
  showMessage(elements.formMessage, `Editando informações de ${artist.name}.`);
}

async function refreshInterface() {
  if (isSupabaseConfigured) {
    await syncRemoteState();
  } else {
    syncLocalState();
  }

  updateSummary();
  updateSession();
  renderProfile();
}

async function handleLogin(event) {
  event.preventDefault();

  const role = elements.loginRole.value;
  const email = cleanText(elements.loginEmail.value).toLowerCase();
  const password = elements.loginPassword.value;

  if (!isValidEmail(email)) {
    showMessage(elements.loginMessage, "Digite um e-mail válido.");
    return;
  }

  if (isSupabaseConfigured) {
    const { data, error } = await supabaseClient.auth.signInWithPassword({ email, password });

    if (error) {
      showMessage(elements.loginMessage, "Não foi possível entrar. Verifique o e-mail, a senha e a confirmação da conta.");
      return;
    }

    await loadRemoteProfile(data.user.id);

    if (!activeProfile || activeProfile.role !== role) {
      await supabaseClient.auth.signOut();
      activeProfile = null;
      showMessage(elements.loginMessage, "O tipo de login selecionado não corresponde a esta conta.");
      await refreshInterface();
      return;
    }

    await refreshInterface();
    showMessage(elements.loginMessage, `Login realizado como ${getRoleName(activeProfile.role)}.`);
    return;
  }

  const user = database.users.find((account) => (
    account.role === role &&
    account.email.toLowerCase() === email &&
    account.password === password
  ));

  if (!user) {
    showMessage(elements.loginMessage, "Login não encontrado. Verifique o tipo de acesso, o e-mail e a senha.");
    return;
  }

  database.activeUserId = user.id;
  saveLocalDatabase();
  await refreshInterface();
  showMessage(elements.loginMessage, `Login realizado como ${getRoleName(user.role)}.`);
}

async function handleSignup(event) {
  event.preventDefault();

  const name = cleanText(elements.signupName.value);
  const role = elements.signupRole.value;
  const email = cleanText(elements.signupEmail.value).toLowerCase();
  const password = elements.signupPassword.value;

  if (name.length < 2 || name.length > 80) {
    showMessage(elements.signupMessage, "O nome deve ter entre 2 e 80 caracteres.");
    return;
  }

  if (!["artista", "comum"].includes(role)) {
    showMessage(elements.signupMessage, "Escolha um tipo de conta válido.");
    return;
  }

  if (!isValidEmail(email)) {
    showMessage(elements.signupMessage, "Digite um e-mail válido.");
    return;
  }

  if (password.length < 8) {
    showMessage(elements.signupMessage, "A senha deve ter pelo menos 8 caracteres.");
    return;
  }

  if (isSupabaseConfigured) {
    const { error } = await supabaseClient.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}${window.location.pathname}`,
        data: { name, role }
      }
    });

    if (error) {
      showMessage(elements.signupMessage, "Não foi possível criar a conta. Tente outro e-mail ou verifique a senha.");
      return;
    }

    elements.signupForm.reset();
    await refreshInterface();
    showMessage(elements.signupMessage, "Conta criada. Verifique seu e-mail para confirmar o cadastro.");
    return;
  }

  const alreadyExists = database.users.some((user) => user.email.toLowerCase() === email);

  if (alreadyExists) {
    showMessage(elements.signupMessage, "Este e-mail já está cadastrado no banco local.");
    return;
  }

  database.users.push({
    id: createId("user"),
    name,
    email,
    password,
    role
  });
  saveLocalDatabase();
  elements.signupForm.reset();
  await refreshInterface();
  showMessage(elements.signupMessage, "Conta criada no modo local. Em produção, use o Supabase para enviar confirmação por e-mail.");
}

async function handleLogout() {
  if (isSupabaseConfigured) {
    await supabaseClient.auth.signOut();
  } else {
    database.activeUserId = null;
    saveLocalDatabase();
  }

  activeProfile = null;
  await refreshInterface();
  showMessage(elements.loginMessage, "Você saiu da conta.");
}

async function saveRemoteArtist(artistData) {
  const existingArtist = artists.find((artist) => artist.id === artistData.id);

  if (existingArtist) {
    if (!canManageArtist(existingArtist)) {
      showMessage(elements.formMessage, "Este login não tem permissão para alterar esse cadastro.");
      return;
    }

    const { error } = await supabaseClient
      .from("artists")
      .update({
        name: artistData.name,
        genre: artistData.genre,
        song: artistData.song,
        bio: artistData.bio
      })
      .eq("id", artistData.id);

    if (error) {
      showMessage(elements.formMessage, "O banco remoto bloqueou a alteração. Verifique as permissões.");
      return;
    }

    showMessage(elements.formMessage, `${artistData.name} foi atualizado no banco remoto.`);
  } else {
    const { error } = await supabaseClient
      .from("artists")
      .insert({
        owner_id: activeProfile.id,
        name: artistData.name,
        genre: artistData.genre,
        song: artistData.song,
        bio: artistData.bio
      });

    if (error) {
      showMessage(elements.formMessage, "O banco remoto bloqueou o cadastro. Verifique as permissões.");
      return;
    }

    showMessage(elements.formMessage, `${artistData.name} foi salvo no banco remoto.`);
  }

  resetForm();
  currentIndex = 0;
  await refreshInterface();
}

async function saveLocalArtist(artistData) {
  const existingIndex = database.artists.findIndex((artist) => artist.id === artistData.id);

  if (existingIndex >= 0) {
    const existingArtist = artists.find((artist) => artist.id === artistData.id);

    if (!canManageArtist(existingArtist)) {
      showMessage(elements.formMessage, "Este login não tem permissão para alterar esse cadastro.");
      return;
    }

    database.artists[existingIndex] = {
      ...database.artists[existingIndex],
      name: artistData.name,
      genre: artistData.genre,
      song: artistData.song,
      bio: artistData.bio
    };
    showMessage(elements.formMessage, `${artistData.name} foi atualizado no banco local.`);
  } else {
    database.artists.unshift({
      ...artistData,
      id: createId("artist"),
      ownerId: activeProfile.id
    });
    currentIndex = 0;
    showMessage(elements.formMessage, `${artistData.name} foi salvo no banco local.`);
  }

  saveLocalDatabase();
  resetForm();
  await refreshInterface();
}

async function handleArtistSubmit(event) {
  event.preventDefault();

  if (!canCreateArtist()) {
    showMessage(elements.formMessage, "Faça login como administrador ou artista para salvar cadastros.");
    return;
  }

  const artistData = getArtistFormData();

  if (!artistData) {
    return;
  }

  if (isSupabaseConfigured) {
    await saveRemoteArtist(artistData);
  } else {
    await saveLocalArtist(artistData);
  }
}

elements.loginForm.addEventListener("submit", handleLogin);
elements.signupForm.addEventListener("submit", handleSignup);
elements.logoutButton.addEventListener("click", handleLogout);
elements.form.addEventListener("submit", handleArtistSubmit);

elements.cancelEditButton.addEventListener("click", () => {
  resetForm();
  showMessage(elements.formMessage, "Edição cancelada.");
});

elements.openGalleryButton.addEventListener("click", openGallery);
elements.closeGalleryButton.addEventListener("click", closeGallery);
elements.previousArtistButton.addEventListener("click", () => moveProfile(-1));
elements.nextArtistButton.addEventListener("click", () => moveProfile(1));
elements.editArtistButton.addEventListener("click", editCurrentArtist);

elements.artistSearch.addEventListener("input", () => {
  searchTerm = elements.artistSearch.value;
  currentIndex = 0;
  renderProfile();
});

elements.demoButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const role = button.dataset.demo;
    const credentials = demoCredentials[role];

    elements.loginRole.value = role;
    elements.loginEmail.value = credentials.email;
    elements.loginPassword.value = credentials.password;
    showMessage(elements.loginMessage, "Conta de teste preenchida. Clique em Entrar.");
  });
});

document.addEventListener("keydown", (event) => {
  if (elements.modal.classList.contains("hidden")) {
    return;
  }

  if (event.key === "Escape") {
    closeGallery();
  }

  if (event.key === "ArrowLeft") {
    moveProfile(-1);
  }

  if (event.key === "ArrowRight") {
    moveProfile(1);
  }
});

if (isSupabaseConfigured) {
  supabaseClient.auth.onAuthStateChange(() => {
    refreshInterface();
  });
}

updateBackendStatus();
refreshInterface();
