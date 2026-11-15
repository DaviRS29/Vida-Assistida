# Modo demonstração — teste de usabilidade

Versão web do Vida Assistida que funciona **sem API, sem banco e sem e-mail**.
Os dados são fictícios e ficam na memória do navegador: **recarregar a página
(F5) volta tudo ao estado inicial**, o que serve para começar cada participante
do zero.

| Conta | Login | Senha |
|---|---|---|
| Responsável (Ana Souza) | `responsavel@vidaassistida.app` | `Demo@123` |
| Profissional (Carlos Lima) | `profissional@vidaassistida.app` | `Demo@123` |

Código da verificação em duas etapas: **`123456`** (aparece também na tela).

---

## 1. Testar no seu computador

```powershell
cd D:\TCC\vida_assistida\mobile
flutter run -d web-server --web-port 5050 --dart-define=DEMO=true
```

Abra `http://localhost:5050`. Não precisa de Docker nem da API.

## 2. Gerar a versão para publicar

```powershell
cd D:\TCC\vida_assistida\mobile
flutter build web --release --dart-define=DEMO=true
```

O resultado fica em `D:\TCC\vida_assistida\mobile\build\web` — são só arquivos
estáticos (HTML, JS e imagens).

## 3. Publicar

### Opção A — Netlify (mais rápido, grátis, já com HTTPS)
1. Acesse https://app.netlify.com/drop
2. Arraste a pasta `build\web` para a página.
3. Copie o link gerado (ex.: `https://vida-assistida-demo.netlify.app`).

### Opção B — Sua VPS (Ubuntu) com Caddy
```bash
# na VPS
sudo apt install -y caddy
sudo mkdir -p /var/www/vida-assistida
```
No Windows, envie os arquivos:
```powershell
scp -r D:\TCC\vida_assistida\mobile\build\web\* usuario@IP_DA_VPS:/tmp/va/
```
Na VPS:
```bash
sudo cp -r /tmp/va/* /var/www/vida-assistida/
sudo tee /etc/caddy/Caddyfile >/dev/null <<'CFG'
seu-dominio.com.br {          # ou :80 se for usar só o IP
    root * /var/www/vida-assistida
    try_files {path} /index.html
    file_server
}
CFG
sudo systemctl reload caddy
```
Com domínio, o Caddy emite o certificado HTTPS sozinho.

## 4. Durante o teste
- Antes de cada participante: **F5** na página (volta aos dados iniciais).
- Entre como **profissional** para as tarefas de rotina, medicamento,
  observação e acionamento; e como **responsável** para ver o histórico,
  as notificações e as permissões.
- O app normal (com API) continua igual: o modo demo só liga com
  `--dart-define=DEMO=true`.

---

## Opção C — VPS da Hostinger com Coolify

Arquivos prontos em `deploy-demo\`: `Dockerfile` (Nginx), `nginx.conf` e
`preparar.ps1` (gera o build demo e copia para `deploy-demo\web`).

1. **Gerar o app:** `powershell -ExecutionPolicy Bypass -File D:\TCC\vida_assistida\deploy-demo\preparar.ps1`
2. **Criar um repositório no GitHub** (pode ser privado), por exemplo
   `vida-assistida-demo`, e enviar a pasta `deploy-demo`:
   ```powershell
   cd D:\TCC\vida_assistida\deploy-demo
   git init
   git add .
   git commit -m "Vida Assistida - modo demonstração"
   git branch -M main
   git remote add origin https://github.com/SEU_USUARIO/vida-assistida-demo.git
   git push -u origin main
   ```
3. **No Coolify:** Projects → seu projeto → **+ New** → *Private Repository
   (with GitHub App)* ou *Public Repository* → escolha o repositório.
   - **Build Pack:** `Dockerfile`
   - **Port exposed:** `80`
   - **Domain:** o seu (ex.: `https://demo.seudominio.com.br`) ou o que o
     Coolify sugerir (`...sslip.io`). O HTTPS é emitido automaticamente.
4. Clique em **Deploy** e abra o link.

**Para atualizar:** rode o `preparar.ps1` de novo, faça `git add . ; git commit -m "atualiza" ; git push`
e clique em **Redeploy** no Coolify (ou ative o deploy automático).
