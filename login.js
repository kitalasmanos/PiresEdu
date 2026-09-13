const config = window.SUPABASE_CONFIG;

const message = document.querySelector("#message");
const form = document.querySelector("#loginForm");
const password = document.querySelector("#password");

if (!config || !config.url || !config.anonKey || config.url.includes("TEU-PROJETO")) {
    message.textContent = "Configura primeiro a URL e a chave pública do Supabase.";
} else {
    window.supabaseClient = window.supabase.createClient(
        config.url,
        config.anonKey
    );
}

document.querySelector("#togglePassword").addEventListener("click", () => {
    password.type = password.type === "password" ? "text" : "password";
});

form.addEventListener("submit", async(event) => {
    event.preventDefault();

    if (!window.supabaseClient) return;

    const email = document.querySelector("#email").value.trim();
    const userPassword = password.value;

    message.textContent = "A iniciar sessão…";
    message.classList.remove("success");

    const { error } = await window.supabaseClient.auth.signInWithPassword({
        email,
        password: userPassword
    });

    if (error) {
        message.textContent = error.message;
        return;
    }

    window.location.href = "dashboard.html";
});

document.querySelector("#createAccount").addEventListener("click", async() => {
    if (!window.supabaseClient) return;

    const email = document.querySelector("#email").value.trim();
    const userPassword = password.value;

    if (!email || !userPassword) {
        message.textContent = "Indica email e uma palavra-passe com pelo menos 8 caracteres.";
        return;
    }

    const { error } = await window.supabaseClient.auth.signUp({
        email,
        password: userPassword
    });

    if (error) {
        message.textContent = error.message;
        return;
    }

    message.textContent = "Conta criada. Confirma o email antes de entrar.";
    message.classList.add("success");
});