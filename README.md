# Music Link

Vitrine para divulgar artistas independentes. O site usa uma única página pública, um único fluxo de acesso e painéis diferentes para ouvintes, artistas e administração. Não hospeda playlists; o artista pode publicar uma prévia curta de áudio.

## Ativação

1. Confirme que `supabase-config.js` contém a URL e a chave pública do projeto Supabase do Music Link. A chave `publishable`/`anon` pode ficar no navegador; nunca use `service_role` ou `secret`.
2. No projeto correto, faça backup das tabelas existentes e execute `supabase-schema.sql` no SQL Editor. O esquema cria as tabelas `ml_*` isoladas e não apaga nem altera tabelas antigas.
3. Configure os domínios do site em Authentication → URL Configuration no Supabase.
4. Hospede esta pasta como site estático. Não há etapa de build; `vercel.json` e `_headers` incluem cabeçalhos para publicação.
5. Cadastre-se pelo site e confirme o e-mail. Promova o primeiro administrador manualmente no SQL Editor, seguindo `SUPABASE_SETUP.md`.

## Desempenho e segurança

- A busca e o filtro por gênero trabalham sobre a lista pública carregada uma vez, limitada a 200 artistas recentes.
- As consultas selecionam somente os campos necessários e os índices cobrem publicação, gênero, cargo e caixa de entrada.
- RLS protege todas as tabelas. Artistas editam apenas o próprio perfil; mensagens e moderação ficam restritas a administradores.
- Prévia de áudio limitada a 15 MB. Ao substituir o áudio, o site apaga o arquivo anterior depois de salvar a nova referência; se o salvamento falhar, tenta remover o novo upload.

## Arquivos de backend

- `supabase-schema.sql`: esquema ativo e isolado.
- `supabase-config.js`: configuração pública do cliente.
- `supabase-client.js`: inicialização do cliente Supabase.
- `SUPABASE_SETUP.md`: passos de ativação e promoção do primeiro administrador.
- `supabase-update.sql`: legado, não executar no fluxo atual. Ele altera tabelas antigas `profiles` e `artists`.

O pacote não contém chaves administrativas nem dados privados. Perfis legados de usuários ligados à Auth são copiados durante a ativação; os dados legados de artistas ficam preservados e precisam ser associados aos proprietários antes de uma migração.
