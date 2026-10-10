# Configurar AdMob SSV - Passo a Passo (Interface em Português)

## 🎯 Objetivo
Configurar a verificação de recompensas no servidor (SSV - Server-Side Verification) para que o Google valide automaticamente as recompensas de anúncios no seu worker Cloudflare.

---

## 📍 Passo 1: Aceder à Consola do Google AdMob

1. Abra [Google AdMob](https://admob.google.com)
2. Inicie sessão com a sua conta Google
3. Certifique-se de que está no **projeto correto**

---

## 📍 Passo 2: Selecionar a Aplicação

Na página inicial do AdMob:

1. Procure o painel esquerdo (Menu)
2. Clique em **"Aplicações"**
3. Procure e clique em **"roast-n-rizz"** (ou o nome da sua app)

---

## 📍 Passo 3: Aceder às Definições da Aplicação

Na página da aplicação:

1. Procure o **menu de três pontos** (⋮) no canto superior direito
   - OU procure a aba **"Definições"** ou **"Configuração"**
2. Clique em **"Definições da aplicação"**

---

## 📍 Passo 4: Encontrar a Secção de Anúncios Recompensados

Na página de Definições da aplicação:

1. Procure a secção **"Monetização"** ou **"Monetizar"**
2. Dentro dessa secção, procure **"Anúncios recompensados"** ou **"Rewarded ads"**
3. Clique nessa secção (pode expandir-se)

---

## 📍 Passo 5: Configurar o URL de Callback do SSV

Dentro da secção de Anúncios Recompensados:

1. Procure o campo **"URL de verificação no servidor"** ou **"Server-side verification callback URL"**
   - Pode estar debaixo de um toggle/switch que diz **"Ativar verificação no servidor"**
   
2. **Se o toggle estiver desligado**: Clique nele para ativar

3. **No campo de texto**, copie e cole este URL:
   ```
   https://roast-rizz-api.rusobrg.workers.dev/ssv
   ```

4. Clique em **"Guardar"** ou **"Aplicar"**

---

## 📍 Passo 6: Copiar o ID da Unidade de Anúncios (Ad Unit ID)

Na mesma página, procure:

1. A secção **"Unidades de anúncios"** ou **"Ad Units"**
2. Procure o anúncio recompensado (algo como "Anúncio recompensado Android" ou "Rewarded Android")
3. Copie o **ID da unidade de anúncios** (começa com `ca-app-pub-...`)
   - Exemplo: `ca-app-pub-7026654571602193/7161531023`

4. Verifique se este ID corresponde ao valor em [.env](.env):
   ```
   ADMOB_REWARDED_AD_UNIT_ANDROID=ca-app-pub-7026654571602193/7161531023
   ```
   - Se não corresponder, atualize o ficheiro [.env](.env)

---

## 📍 Passo 7: Verificar o ID da Aplicação (App ID)

1. Na mesma página de Definições, procure **"Identificador da aplicação"** ou **"App ID"**
   - Exemplo: `ca-app-pub-7026654571602193~1170837743`

2. Verifique se este ID corresponde ao valor em [.env](.env):
   ```
   ADMOB_APP_ID_ANDROID=ca-app-pub-7026654571602193~1170837743
   ```
   - Se não corresponder, atualize o ficheiro [.env](.env)

---

## 📍 Passo 8: Configurar Dispositivos de Teste (Opcional, mas Recomendado)

Para testar sem afetar métricas reais:

1. Na página de Definições, procure **"Dispositivos de teste"** ou **"Test devices"**

2. Clique em **"Adicionar ID de publicidade"**

3. Quando executa a app no seu dispositivo:
   - Abra a app
   - Clique em **"Assistência"** (menu) se disponível
   - Procure pelo **ID de publicidade do seu dispositivo** (mostra-se normalmente nos logs)
   - Copie e cole aqui

4. Clique em **"Adicionar"**

**Alternativa**: Se tiver acessibilidade ao código, pode adicionar via programação no Flutter usando:
```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

RequestConfiguration(
  keywords: ['test'],
  testDeviceIds: ['33BE2250B43518CCDA7DE426D04EE232'],
);
```

---

## 📍 Passo 9: Ativar Anúncios de Teste do Google

**Importante**: Não teste com anúncios reais! Use anúncios de teste do Google.

1. Na página de Definições, procure **"Anúncios de teste"** ou **"Test ads"**

2. Ative a opção **"Mostrar anúncios de teste"** ou **"Show test ads"**

---

## 📍 Passo 10: Guardar Todas as Alterações

1. Verifique que clicou em **"Guardar"** em todas as secções onde fez alterações
2. Espere 5-10 minutos para que as alterações se propaguem

---

## ✅ Verificar se Está Tudo Correto

### Verificação 1: URL do Callback
```
https://roast-rizz-api.rusobrg.workers.dev/ssv
```
- Deve estar guardado em **Definições → Anúncios Recompensados → URL de verificação no servidor**

### Verificação 2: IDs em Sincronização
Certifique-se que o ficheiro [.env](.env) tem:
```
ADMOB_APP_ID_ANDROID=ca-app-pub-7026654571602193~1170837743
ADMOB_REWARDED_AD_UNIT_ANDROID=ca-app-pub-7026654571602193/7161531023
```

### Verificação 3: App Configurada
Na [lib/config/ad_config.dart](lib/config/ad_config.dart) e [lib/controllers/home_controller.dart](lib/controllers/home_controller.dart):
- ✅ IDs carregados de [.env](.env)
- ✅ `setServerSideOptions()` configurado com `customData: userId`

---

## 🧪 Testar o Fluxo Completo

### Teste Local (com Wrangler)

1. **Terminal 1**: Inicie o worker local
   ```bash
   cd workers
   wrangler dev
   ```

2. **Terminal 2**: Execute a app em modo dev
   ```bash
   flutter run
   ```

3. **Na app**:
   - Clique no botão "Assistir a anúncio recompensado"
   - Veja o anúncio de teste
   - Após terminar, deve ver **+3 créditos**

### Teste em Produção (depois de deploy)

1. Instale a app num dispositivo Android real
2. Se o dispositivo está configurado como **dispositivo de teste**:
   - Verá anúncios de teste do Google
   - Os rewards funcionarão sem impactar métricas reais
3. Após ganhar um reward:
   - Verifique os logs do Cloudflare Worker
   - Procure por um `GET /ssv?...` na aba de Real-Time Logs

---

## 🔍 Monitorizar os Callbacks SSV

Para ver em tempo real quando Google chama o seu callback:

1. Vá para [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Selecione **"Workers"** no menu esquerdo
3. Clique no seu projeto/worker
4. Procure **"Logs em Tempo Real"** ou **"Real-Time Logs"**
5. Cada SSV callback aparecerá como:
   ```
   GET /ssv?custom_data=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx&transaction_id=...&signature=...
   Status: 200
   ```

---

## ❌ Erros Comuns

### ❌ Erro: "URL de callback inválida"
- ✅ Verifique que copiou: `https://roast-rizz-api.rusobrg.workers.dev/ssv`
- ✅ Certifique-se que o worker foi deployed em produção
- ✅ Teste o URL num browser: deve devolver um erro 400 (parâmetros em falta)

### ❌ Erro: "Anúncios de teste não funcionam"
- ✅ Adicione o seu dispositivo à lista de **Dispositivos de teste**
- ✅ Verifique que tem o flag `REQUEST_CONFIGURATION` correto no código

### ❌ Erro: "Credits não aumentam após reward"
- ✅ Verifique nos logs do Cloudflare se o callback foi recebido
- ✅ Verifique se `custom_data` (userId) está no formato correto (UUID com hífens)
- ✅ Verifique se o KV namespace está vinculado no `wrangler.toml`

---

## 📞 Suporte

Se ainda tiver dúvidas:
1. Consulte [docs/admob-ssv-setup.md](docs/admob-ssv-setup.md) para detalhes técnicos
2. Verifique os logs: `flutter logs` (app) e Cloudflare Dashboard (worker)
3. Valide a app com: `flutter analyze` e `flutter test`
