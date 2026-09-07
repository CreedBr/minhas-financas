# Minhas Finanças v2

Versão compartilhada para duas pessoas, com login, carteira compartilhada, convite e sincronização online/offline.

## Configuração inicial
1. No Supabase, execute primeiro o SQL seguro da versão anterior.
2. Depois execute `supabase_v2.sql`.
3. No aplicativo, abra Ajustes > Conectar o aplicativo.
4. Informe apenas a URL do projeto e a chave pública (anon/publishable).
5. Crie sua conta.
6. Crie a carteira.
7. Gere o código de convite e envie para sua esposa.
8. Ela cria a própria conta e informa o código.

Nunca use `service_role` ou uma chave `secret` no navegador.

## Importante sobre offline
O aplicativo mantém os dados localmente e tenta sincronizar quando a internet volta. Para instalação como PWA e service worker, publique os arquivos em um endereço HTTPS (por exemplo, um serviço de hospedagem estática).
