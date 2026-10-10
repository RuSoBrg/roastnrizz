# AdMob SSV - Guia Rápido (Atalho)

## 🏃 Versão Rápida - 5 Passos

### 1️⃣ Abra AdMob
```
https://admob.google.com → Aplicações → roast-n-rizz
```

### 2️⃣ Vá para Definições
```
Menu (⋮) → Definições da aplicação
```

### 3️⃣ Procure "Monetização" → "Anúncios Recompensados"

### 4️⃣ Cole o URL de Callback SSV
```
URL: https://roast-rizz-api.rusobrg.workers.dev/ssv
```
Procure o campo **"URL de verificação no servidor"** ou **"Server-side verification callback"**

### 5️⃣ Clique em Guardar

---

## ✅ Verificação Rápida

Depois de guardar, verifique:

```
✓ URL de Callback: https://roast-rizz-api.rusobrg.workers.dev/ssv
✓ ADMOB_APP_ID_ANDROID em .env
✓ ADMOB_REWARDED_AD_UNIT_ANDROID em .env
✓ Dispositivos de teste adicionados (opcional)
✓ Anúncios de teste ativados (recomendado)
```

---

## 🧪 Testar

```bash
# Terminal 1: Inicie o worker
cd workers && wrangler dev

# Terminal 2: Execute a app
flutter run
```

Na app: Clique "Assistir a anúncio recompensado" → Deve ganhar 3 créditos

---

## 🔗 Referência Completa
Ver: [docs/admob-ssv-configuracao-pt.md](admob-ssv-configuracao-pt.md)
